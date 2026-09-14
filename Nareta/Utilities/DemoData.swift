#if DEBUG
import Foundation
import SwiftData

/// 起動引数 `-demo YES` で過去2週間分の達成データを生成（スクリーンショット・動作確認用）
/// `-initialTab goals|rewards|me` で初期タブを指定
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
        let goals = (try? context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        goals.forEach { $0.createdAt = now.startOfDay.adding(days: -20) }

        let english = Goal(title: "英語20分", note: "未来の自分に投資しよう", rewardAmount: 200, frequency: .weekly, targetCount: 5,
                           durationMinutes: 20, identityId: nil, createdAt: now.startOfDay.adding(days: -20))
        context.insert(english)

        let game = Reward(name: "ゲーム", note: "好きなことでリフレッシュ", price: 6_000, category: .other, priority: .high)
        context.insert(game)
        try? context.save()

        let service = RewardService(context: context)
        let monthStart = now.startOfMonth
        for back in stride(from: 12, through: 1, by: -1) {
            let day = now.startOfDay.adding(days: -back).addingTimeInterval(20 * 3600)
            guard day >= monthStart else { continue }
            for (index, goal) in (goals + [english]).enumerated() {
                let skip: Bool = switch goal.frequency {
                case .weekly: (back + index) % 2 == 1
                default: (back * 7 + index * 3) % 5 == 0 || (day.weekday == 7 && index % 2 == 0)
                }
                if !skip { _ = service.completeGoal(goal, now: day) }
            }
        }

        if let pool = service.currentPool(now: now) {
            let spentAt = now.startOfDay.adding(days: -4).addingTimeInterval(19 * 3600)
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
