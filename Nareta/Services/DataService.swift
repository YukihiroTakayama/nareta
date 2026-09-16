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

        let routines = ensureRoutines(context: context)
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
        let routineByName = Dictionary(routines.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        goals[0].routineId = routineByName["昼食"]?.id
        goals[0].alertStyle = AlertStyle.notification.rawValue
        goals[1].routineId = routineByName["夕食"]?.id
        goals[1].triggerOffset = 60
        goals[2].triggerMinutes = 19 * 60
        goals[2].obstacle = "残業で疲れて帰りたくなる"
        goals[2].obstaclePlan = "ウェアを持って出社し、10分だけでも行く"
        goals[3].routineId = routineByName["就寝"]?.id
        goals[3].triggerOffset = -30
        goals.forEach(context.insert)

        let rewards: [Reward] = [
            Reward(name: "AirPods Pro", note: "より良い毎日を、もっと快適に", price: 39_800, category: .gadget, priority: .high, createdAt: base),
            Reward(name: "高級寿司", note: "がんばった自分にご褒美を", price: 15_000, category: .food, priority: .normal, createdAt: base.addingTimeInterval(1)),
            Reward(name: "旅行", note: "新しい景色で、もっと広い世界へ", price: 100_000, category: .travel, priority: .low, createdAt: base.addingTimeInterval(2)),
        ]
        rewards.forEach(context.insert)
        try? context.save()
    }

    /// ルーティン時刻がまだなければ初期値を入れる
    @discardableResult
    static func ensureRoutines(context: ModelContext) -> [RoutineAnchor] {
        let existing = (try? context.fetch(FetchDescriptor<RoutineAnchor>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        guard existing.isEmpty else { return existing }
        let created = RoutineAnchor.presets.enumerated().map { index, preset in
            RoutineAnchor(name: preset.name, icon: preset.icon, minutes: preset.minutes, sortOrder: index)
        }
        created.forEach(context.insert)
        try? context.save()
        return created
    }

    // MARK: - Reset

    static func resetAll(context: ModelContext) {
        try? context.delete(model: GoalCompletion.self)
        try? context.delete(model: RewardTransaction.self)
        try? context.delete(model: Goal.self)
        try? context.delete(model: Reward.self)
        try? context.delete(model: Identity.self)
        try? context.delete(model: MonthlyRewardPool.self)
        try? context.delete(model: AutomaticityCheck.self)
        try? context.delete(model: StreakFreeze.self)
        try? context.delete(model: RoutineAnchor.self)
        try? context.delete(model: StreakMilestone.self)
        try? context.save()
    }

    // MARK: - Export

    private struct ExportData: Encodable {
        struct IdentityDTO: Encodable { let id: UUID; let name: String; let icon: String?; let colorHex: String?; let createdAt: Date }
        struct GoalDTO: Encodable {
            let id: UUID; let title: String; let note: String; let rewardAmount: Int; let frequencyType: String
            let targetCount: Int; let weekdays: [Int]; let durationMinutes: Int; let identityId: UUID?
            let isActive: Bool; let verificationType: String; let createdAt: Date
            let triggerMinutes: Int; let routineId: UUID?; let triggerOffset: Int; let alertStyle: String; let wishOutcome: String; let obstacle: String; let obstaclePlan: String; let archivedAt: Date?
        }
        struct CompletionDTO: Encodable { let id: UUID; let goalId: UUID; let completedAt: Date; let rewardAmount: Int; let bonusAmount: Int }
        struct CheckDTO: Encodable { let id: UUID; let goalId: UUID; let checkedAt: Date; let scores: [Int] }
        struct FreezeDTO: Encodable { let id: UUID; let goalId: UUID; let date: Date; let createdAt: Date }
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
        let automaticityChecks: [CheckDTO]
        let streakFreezes: [FreezeDTO]
    }

    static func exportJSON(context: ModelContext) -> URL? {
        func all<T: PersistentModel>(_ type: T.Type) -> [T] { (try? context.fetch(FetchDescriptor<T>())) ?? [] }

        let data = ExportData(
            exportedAt: .now,
            identities: all(Identity.self).map { .init(id: $0.id, name: $0.name, icon: $0.icon, colorHex: $0.colorHex, createdAt: $0.createdAt) },
            goals: all(Goal.self).map {
                .init(id: $0.id, title: $0.title, note: $0.note, rewardAmount: $0.rewardAmount, frequencyType: $0.frequencyType,
                      targetCount: $0.targetCount, weekdays: $0.weekdays, durationMinutes: $0.durationMinutes, identityId: $0.identityId,
                      isActive: $0.isActive, verificationType: $0.verificationType, createdAt: $0.createdAt,
                      triggerMinutes: $0.triggerMinutes, routineId: $0.routineId, triggerOffset: $0.triggerOffset, alertStyle: $0.alertStyle, wishOutcome: $0.wishOutcome, obstacle: $0.obstacle, obstaclePlan: $0.obstaclePlan, archivedAt: $0.archivedAt)
            },
            goalCompletions: all(GoalCompletion.self).map { .init(id: $0.id, goalId: $0.goalId, completedAt: $0.completedAt, rewardAmount: $0.rewardAmount, bonusAmount: $0.bonusAmount) },
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
            },
            automaticityChecks: all(AutomaticityCheck.self).map { .init(id: $0.id, goalId: $0.goalId, checkedAt: $0.checkedAt, scores: $0.scores) },
            streakFreezes: all(StreakFreeze.self).map { .init(id: $0.id, goalId: $0.goalId, date: $0.date, createdAt: $0.createdAt) }
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
