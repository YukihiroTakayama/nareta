import Foundation
import SwiftData

@MainActor
enum DataService {
    // MARK: - Seed

    static func seed(context: ModelContext, identityNames: [String], poolAmount: Int, includeSamples: Bool) {
        var identities: [String: Identity] = [:]
        for (index, name) in identityNames.enumerated() {
            let preset = IdentityPreset.find(name)
            let identity = Identity(
                name: name,
                icon: preset?.icon ?? IdentityPreset.customIcon,
                colorHex: preset?.colorHex ?? IdentityPreset.customColors[index % IdentityPreset.customColors.count],
                createdAt: Date().addingTimeInterval(Double(index))
            )
            context.insert(identity)
            identities[name] = identity
        }

        RewardService(context: context).startPool(amount: poolAmount)

        guard includeSamples else {
            try? context.save()
            return
        }

        let base = Date()
        let goals: [Goal] = [
            Goal(title: "8,000歩", note: "今日もよく歩きました", rewardAmount: 100, frequency: .daily,
                 identityId: identities["健康でいたい"]?.id, createdAt: base),
            Goal(title: "勉強30分", note: "継続は力なり", rewardAmount: 200, frequency: .daily, durationMinutes: 30,
                 identityId: identities["学び続けたい"]?.id, createdAt: base.addingTimeInterval(1)),
            Goal(title: "ジム", note: "理想の自分に近づく", rewardAmount: 500, frequency: .weekly, targetCount: 3, durationMinutes: 60,
                 identityId: identities["体を鍛えたい"]?.id ?? identities["健康でいたい"]?.id, createdAt: base.addingTimeInterval(2)),
            Goal(title: "23:30までに寝る", note: "明日のパフォーマンスのために", rewardAmount: 100, frequency: .daily,
                 identityId: identities["生活を整えたい"]?.id, createdAt: base.addingTimeInterval(3)),
        ]
        goals.forEach(context.insert)

        let rewards: [Reward] = [
            Reward(name: "AirPods Pro", note: "より良い毎日を、もっと快適に", price: 39_800, category: .gadget, priority: .high, createdAt: base),
            Reward(name: "高級寿司", note: "がんばった自分にご褒美を", price: 15_000, category: .food, priority: .normal, createdAt: base.addingTimeInterval(1)),
            Reward(name: "旅行", note: "新しい景色で、もっと広い世界へ", price: 100_000, category: .travel, priority: .low, createdAt: base.addingTimeInterval(2)),
        ]
        rewards.forEach(context.insert)
        try? context.save()
    }

    // MARK: - Reset

    static func resetAll(context: ModelContext) {
        try? context.delete(model: GoalCompletion.self)
        try? context.delete(model: RewardTransaction.self)
        try? context.delete(model: Goal.self)
        try? context.delete(model: Reward.self)
        try? context.delete(model: Identity.self)
        try? context.delete(model: MonthlyRewardPool.self)
        try? context.save()
    }

    // MARK: - Export

    private struct ExportData: Encodable {
        struct IdentityDTO: Encodable { let id: UUID; let name: String; let icon: String?; let colorHex: String?; let createdAt: Date }
        struct GoalDTO: Encodable {
            let id: UUID; let title: String; let note: String; let rewardAmount: Int; let frequencyType: String
            let targetCount: Int; let weekdays: [Int]; let durationMinutes: Int; let identityId: UUID?
            let isActive: Bool; let verificationType: String; let createdAt: Date
        }
        struct CompletionDTO: Encodable { let id: UUID; let goalId: UUID; let completedAt: Date; let rewardAmount: Int }
        struct PoolDTO: Encodable {
            let id: UUID; let year: Int; let month: Int; let totalAmount: Int
            let unlockedAmount: Int; let spentAmount: Int; let carriedOverAmount: Int
        }
        struct RewardDTO: Encodable {
            let id: UUID; let name: String; let note: String; let price: Int; let category: String
            let priority: Int; let isPurchased: Bool; let purchasedAt: Date?; let createdAt: Date
        }
        struct TransactionDTO: Encodable { let id: UUID; let type: String; let amount: Int; let title: String; let sourceId: UUID?; let createdAt: Date }

        let exportedAt: Date
        let identities: [IdentityDTO]
        let goals: [GoalDTO]
        let goalCompletions: [CompletionDTO]
        let monthlyRewardPools: [PoolDTO]
        let rewards: [RewardDTO]
        let rewardTransactions: [TransactionDTO]
    }

    static func exportJSON(context: ModelContext) -> URL? {
        func all<T: PersistentModel>(_ type: T.Type) -> [T] { (try? context.fetch(FetchDescriptor<T>())) ?? [] }

        let data = ExportData(
            exportedAt: .now,
            identities: all(Identity.self).map { .init(id: $0.id, name: $0.name, icon: $0.icon, colorHex: $0.colorHex, createdAt: $0.createdAt) },
            goals: all(Goal.self).map {
                .init(id: $0.id, title: $0.title, note: $0.note, rewardAmount: $0.rewardAmount, frequencyType: $0.frequencyType,
                      targetCount: $0.targetCount, weekdays: $0.weekdays, durationMinutes: $0.durationMinutes, identityId: $0.identityId,
                      isActive: $0.isActive, verificationType: $0.verificationType, createdAt: $0.createdAt)
            },
            goalCompletions: all(GoalCompletion.self).map { .init(id: $0.id, goalId: $0.goalId, completedAt: $0.completedAt, rewardAmount: $0.rewardAmount) },
            monthlyRewardPools: all(MonthlyRewardPool.self).map {
                .init(id: $0.id, year: $0.year, month: $0.month, totalAmount: $0.totalAmount,
                      unlockedAmount: $0.unlockedAmount, spentAmount: $0.spentAmount, carriedOverAmount: $0.carriedOverAmount)
            },
            rewards: all(Reward.self).map {
                .init(id: $0.id, name: $0.name, note: $0.note, price: $0.price, category: $0.category,
                      priority: $0.priority, isPurchased: $0.isPurchased, purchasedAt: $0.purchasedAt, createdAt: $0.createdAt)
            },
            rewardTransactions: all(RewardTransaction.self).map {
                .init(id: $0.id, type: $0.type, amount: $0.amount, title: $0.title, sourceId: $0.sourceId, createdAt: $0.createdAt)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let json = try? encoder.encode(data) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nareta-export-\(formatter.string(from: .now)).json")
        do {
            try json.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
