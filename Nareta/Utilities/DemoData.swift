#if DEBUG
import Foundation
import SwiftData

/// 起動引数 `-demo YES` で過去の達成データを生成（スクリーンショット・動作確認用）
/// `-initialTab goals|rewards|me` / `-debugGoal <タイトル>` / `-debugNewGoal YES`
@MainActor
enum DemoData {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static func seed(context: ModelContext) {
        DataService.seed(
            context: context,
            identityNames: ["健康でいたい", "体を鍛えたい", "学び続けたい", "生活を整えたい", "新しいことに挑戦したい"],
            poolAmount: 30_000,
            includeSamples: true
        )

        let now = Date()
        let today = now.startOfDay
        let identities = (try? context.fetch(FetchDescriptor<Identity>())) ?? []
        let healthId = identities.first { $0.name == "健康でいたい" }?.id
        let goals = (try? context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        for (index, goal) in goals.enumerated() {
            goal.createdAt = today.adding(days: index == 0 ? -75 : -20)
        }

        let english = Goal(title: "英語20分", note: "未来の自分に投資しよう", rewardAmount: 200, frequency: .weekly, targetCount: 5,
                           durationMinutes: 20, createdAt: today.adding(days: -20))
        english.triggerMinutes = 8 * 60
        english.alertStyle = AlertStyle.notification.rawValue
        context.insert(english)

        let water = Goal(title: "水を2L飲む", rewardAmount: 100, frequency: .daily, identityId: healthId, createdAt: today.adding(days: -90))
        water.triggerMinutes = 9 * 60
        water.archivedAt = today.adding(days: -6).addingTimeInterval(20 * 3600)
        context.insert(water)

        context.insert(Reward(name: "ゲーム", note: "好きなことでリフレッシュ", price: 6_000, category: .other, priority: .high))
        try? context.save()

        let monthStart = now.startOfMonth
        // 月初より前の履歴（Poolには反映しない）
        for back in 1...89 {
            let day = today.adding(days: -back).addingTimeInterval(20 * 3600)
            if back <= 74, day < monthStart, back % 9 != 0 {
                context.insert(GoalCompletion(goalId: goals[0].id, completedAt: day, rewardAmount: 100))
            }
            if back >= 7, back % 7 != 0 {
                context.insert(GoalCompletion(goalId: water.id, completedAt: day, rewardAmount: 100))
            }
        }

        let service = RewardService(context: context)
        for back in stride(from: 30, through: 1, by: -1) {
            let day = today.adding(days: -back).addingTimeInterval(20 * 3600)
            guard day >= monthStart else { continue }
            for (index, goal) in (goals + [english]).enumerated() {
                let skip: Bool = switch goal.frequency {
                case .weekly:
                    (back + index) % 2 == 1
                default:
                    index == 3
                        ? (back == 1 || back % 4 == 3)
                        : ((back * 7 + index * 3) % 5 == 0 || (day.weekday == 7 && index == 1))
                }
                if !skip { _ = service.completeGoal(goal, now: day) }
            }
        }

        context.insert(AutomaticityCheck(goalId: goals[0].id, scores: [6, 6, 5, 6], checkedAt: today.adding(days: -10).addingTimeInterval(12 * 3600)))
        context.insert(AutomaticityCheck(goalId: goals[0].id, scores: [6, 7, 6, 6], checkedAt: today.adding(days: -3).addingTimeInterval(12 * 3600)))

        if let pool = service.currentPool(now: now) {
            let spentAt = today.adding(days: -4).addingTimeInterval(19 * 3600)
            let dinner = Reward(name: "映画とディナー", note: "週末のごほうび", price: 4_800, category: .experience)
            dinner.isPurchased = true
            dinner.purchasedAt = spentAt
            context.insert(dinner)
            pool.spentAmount += dinner.price
            context.insert(RewardTransaction(type: .spend, amount: -dinner.price, title: dinner.name, sourceId: dinner.id, createdAt: spentAt))
        }

        for goal in goals.prefix(2) {
            _ = service.completeGoal(goal, now: now)
        }
        try? context.save()
    }
}
#endif
