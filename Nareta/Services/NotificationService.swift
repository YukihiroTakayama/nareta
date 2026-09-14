import Foundation
import SwiftData
import UserNotifications

enum NotificationService {
    static var enabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.notifications) as? Bool ?? true
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @MainActor
    static func reschedule(context: ModelContext, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        AlarmService.reschedule(context: context)
        guard enabled else { return }

        let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<GoalCompletion>())) ?? []
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let service = RewardService(context: context)

        // 朝 8:00
        let dailyCount = goals.filter { $0.isLive && $0.frequency == .daily }.count
        if dailyCount > 0 {
            add(center, id: "morning", title: "NARETA", body: "今日の目標は\(dailyCount)つ。達成した分だけお小遣いが解放されます。",
                components: DateComponents(hour: 8, minute: 0), repeats: true)
        }

        // 未達 21:00（今日分）
        let todayRemaining = goals.filter {
            GoalService.showsInToday($0, byGoal[$0.id] ?? [], now: now) && GoalService.canComplete($0, byGoal[$0.id] ?? [], now: now)
        }
        if !todayRemaining.isEmpty, let fire = Calendar.nareta.date(bySettingHour: 21, minute: 0, second: 0, of: now), fire > now {
            let sum = todayRemaining.reduce(0) { $0 + $1.rewardAmount }
            add(center, id: "evening", title: "あと\(todayRemaining.count)つで今日\(sum.signedYen)",
                body: todayRemaining.map(\.title).prefix(3).joined(separator: "・"),
                components: Calendar.nareta.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
        }

        // Reward 12:30
        if let pool = service.currentPool(now: now), let reward = service.nextReward() {
            let remaining = reward.price - pool.availableAmount
            if remaining > 0, remaining <= 3_000,
               let fire = Calendar.nareta.date(bySettingHour: 12, minute: 30, second: 0, of: now), fire > now {
                add(center, id: "reward", title: "あと\(remaining.yen)で\(reward.name)を解放", body: "今日の目標を達成して近づこう。",
                    components: Calendar.nareta.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            }
        }

        // If-Thenの時刻（通知指定の目標。アラーム指定でもAlarmKitが使えなければ通知で代替）
        let routines = (try? context.fetch(FetchDescriptor<RoutineAnchor>())) ?? []
        let alarmsAvailable = AlarmService.authorization == .authorized
        var planned: [(date: Date, goal: Goal)] = []
        for goal in goals {
            let style = goal.alertStyleValue
            guard style == .notification || (style == .alarm && !alarmsAvailable),
                  let minutes = TriggerService.minutes(for: goal, routines: routines) else { continue }
            planned += TriggerService.fireDates(for: goal, minutes: minutes, completions: byGoal[goal.id] ?? [], now: now).map { ($0, goal) }
        }
        for (index, item) in planned.sorted(by: { $0.date < $1.date }).prefix(50).enumerated() {
            let label = TriggerService.label(for: item.goal, routines: routines) ?? ""
            add(center, id: "trigger-\(index)", title: "\(item.goal.title)の時間です",
                body: "\(label)になりました。達成すると \(item.goal.rewardAmount.signedYen) 解放",
                components: Calendar.nareta.dateComponents([.year, .month, .day, .hour, .minute], from: item.date), repeats: false)
        }

        // Weekly 日曜 21:00
        add(center, id: "weekly", title: "今週の結果が出ました", body: "今週のふりかえりを見てみましょう。",
            components: DateComponents(hour: 21, minute: 0, weekday: 1), repeats: true)
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, title: String, body: String, components: DateComponents, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
