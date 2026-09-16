import Foundation
import SwiftData
import UserNotifications

enum NotificationService {
    /// 通知・アラームを何日先まで予約するか
    static let horizonDays = 14

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.notifications) as? Bool ?? true
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 通知・アラーム・ウィジェットをまとめて最新にする。
    /// 返り値はアラーム予約の完了を待つためのTask（バックグラウンド更新で使う）
    @MainActor
    @discardableResult
    static func reschedule(context: ModelContext, now: Date = .now) -> Task<Void, Never> {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        WidgetSync.update(context: context, now: now)
        let alarmTask = AlarmService.reschedule(context: context)
        BackgroundRefresh.schedule()
        guard enabled else { return alarmTask }

        let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<GoalCompletion>())) ?? []
        let routines = (try? context.fetch(FetchDescriptor<RoutineAnchor>())) ?? []
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let service = RewardService(context: context)
        let calendar = Calendar.nareta

        // 朝 8:00
        let dailyCount = goals.filter { $0.isLive && $0.frequency == .daily }.count
        if dailyCount > 0 {
            add(center, id: "morning", title: "NARETA", body: "今日の目標は\(dailyCount)つ。達成した分だけお小遣いが解放されます。",
                components: DateComponents(hour: 8, minute: 0), repeats: true, route: .home)
        }

        // 未達 21:00（今日分）
        let todayRemaining = goals.filter {
            GoalService.showsInToday($0, byGoal[$0.id] ?? [], now: now) && GoalService.canComplete($0, byGoal[$0.id] ?? [], now: now)
        }
        if !todayRemaining.isEmpty, let fire = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now), fire > now {
            let sum = todayRemaining.reduce(0) { $0 + $1.rewardAmount }
            let streak = GoalService.dayStreak(completions, now: now)
            let atRisk = streak > 0 && !completions.contains { $0.completedAt.isSameDay(as: now) }
            let titles = todayRemaining.map(\.title)
            add(center, id: "evening",
                title: atRisk ? "\(streak)日連続が途切れそうです" : "あと\(todayRemaining.count)つで今日\(sum.signedYen)",
                body: atRisk
                    ? "1つ達成で\(streak + 1)日連続。\(titles.prefix(2).joined(separator: "・"))"
                    : titles.prefix(3).joined(separator: "・"),
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false, route: .home)
        }

        // Reward 12:30
        if let pool = service.currentPool(now: now), let reward = service.nextReward() {
            let remaining = reward.price - pool.availableAmount
            if remaining > 0, remaining <= 3_000,
               let fire = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now), fire > now {
                add(center, id: "reward", title: "あと\(remaining.yen)で\(reward.name)を解放", body: "今日の目標を達成して近づこう。",
                    components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false, route: .home)
            }
        }

        // If-Thenの時刻（通知指定の目標。アラーム指定でもAlarmKitが使えなければ通知で代替）
        let alarmsAvailable = AlarmService.authorization == .authorized
        var planned: [(date: Date, goal: Goal)] = []
        for goal in goals {
            let style = goal.alertStyleValue
            guard style == .notification || (style == .alarm && !alarmsAvailable),
                  let minutes = TriggerService.minutes(for: goal, routines: routines) else { continue }
            planned += TriggerService.fireDates(
                for: goal, minutes: minutes, completions: byGoal[goal.id] ?? [], now: now, days: horizonDays
            ).map { ($0, goal) }
        }
        for (index, item) in planned.sorted(by: { $0.date < $1.date }).prefix(50).enumerated() {
            let label = TriggerService.label(for: item.goal, routines: routines) ?? ""
            add(center, id: "trigger-\(index)", title: "\(item.goal.title)の時間です",
                body: "\(label)になりました。達成すると \(item.goal.rewardAmount.signedYen) 解放",
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.date), repeats: false,
                route: .goal(item.goal.id))
        }

        // しばらくアプリを開いていないときのリマインド（開くたびに先送りされる）
        let hasReminders = goals.contains { $0.isLive && $0.hasTrigger && $0.alertStyleValue != .none }
        if hasReminders {
            let fire = now.startOfDay.adding(days: 6).addingTimeInterval(20 * 3600)
            add(center, id: "stale", title: "アラームの予約を更新しましょう",
                body: "NARETAを開くと、この先2週間分のアラームと通知が予約し直されます。",
                components: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false, route: .home)
        }

        // Weekly 日曜 21:00
        add(center, id: "weekly", title: "今週の結果が出ました", body: "ふりかえりと、来週の目標の調整案をチェックしましょう。",
            components: DateComponents(hour: 21, minute: 0, weekday: 1), repeats: true, route: .weeklyReview)

        return alarmTask
    }

    private static func add(
        _ center: UNUserNotificationCenter, id: String, title: String, body: String,
        components: DateComponents, repeats: Bool, route: AppRoute
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = route.userInfo
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
