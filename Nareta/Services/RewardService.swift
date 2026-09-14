import Foundation
import SwiftData

struct CompletionResult: Identifiable, Equatable {
    let id = UUID()
    let completionId: UUID
    let goalTitle: String
    let requestedAmount: Int
    let amount: Int
    let balanceBefore: Int
    let balanceAfter: Int
    let rewardName: String?
    let rewardPrice: Int

    var remainingBefore: Int { max(0, rewardPrice - balanceBefore) }
    var remainingAfter: Int { max(0, rewardPrice - balanceAfter) }
    var wasCapped: Bool { amount < requestedAmount }
}

/// Goal達成 / Reward解放 / Pool上限 / Reward使用 / Transaction生成
@MainActor
struct RewardService {
    let context: ModelContext

    static let defaultPoolAmount = 30_000

    var carryOverEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.carryOver) as? Bool ?? true
    }

    // MARK: - Pool

    func currentPool(now: Date = .now) -> MonthlyRewardPool? {
        let y = now.year
        let m = now.month
        let descriptor = FetchDescriptor<MonthlyRewardPool>(predicate: #Predicate { $0.year == y && $0.month == m })
        return try? context.fetch(descriptor).first
    }

    func latestPool() -> MonthlyRewardPool? {
        var descriptor = FetchDescriptor<MonthlyRewardPool>(
            sortBy: [SortDescriptor(\.year, order: .reverse), SortDescriptor(\.month, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// 今月のPoolを作成（既にあれば金額を更新）
    @discardableResult
    func startPool(amount: Int, now: Date = .now) -> MonthlyRewardPool {
        if let pool = currentPool(now: now) {
            setTotal(amount, for: pool)
            return pool
        }
        var carried = 0
        if carryOverEnabled, let previous = latestPool() {
            carried = max(0, previous.availableAmount)
        }
        let pool = MonthlyRewardPool(year: now.year, month: now.month, totalAmount: amount, carriedOverAmount: carried)
        context.insert(pool)
        save()
        return pool
    }

    /// 月が変わっていたら前月と同じ金額で新しいPoolを作る。作成した場合 true
    func ensureCurrentPool(now: Date = .now) -> Bool {
        guard currentPool(now: now) == nil, let previous = latestPool() else { return false }
        startPool(amount: previous.totalAmount, now: now)
        return true
    }

    func setTotal(_ amount: Int, for pool: MonthlyRewardPool) {
        let newTotal = max(0, amount)
        pool.totalAmount = newTotal
        if pool.unlockedAmount > newTotal {
            let diff = newTotal - pool.unlockedAmount
            pool.unlockedAmount = newTotal
            context.insert(RewardTransaction(type: .adjustment, amount: diff, title: "Reward Pool変更による調整"))
        }
        save()
    }

    // MARK: - Goal達成

    func completions(for goal: Goal) -> [GoalCompletion] {
        let goalId = goal.id
        let descriptor = FetchDescriptor<GoalCompletion>(predicate: #Predicate { $0.goalId == goalId })
        return (try? context.fetch(descriptor)) ?? []
    }

    func alreadyCompleted(_ goal: Goal, now: Date = .now) -> Bool {
        !GoalService.canComplete(goal, completions(for: goal), now: now)
    }

    func completeGoal(_ goal: Goal, now: Date = .now) -> CompletionResult? {
        guard !alreadyCompleted(goal, now: now) else { return nil }

        let pool = currentPool(now: now) ?? startPool(amount: latestPool()?.totalAmount ?? Self.defaultPoolAmount, now: now)
        let before = pool.availableAmount
        let next = nextReward()

        let remaining = pool.totalAmount - pool.unlockedAmount
        let reward = max(0, min(goal.rewardAmount, remaining))

        let completion = GoalCompletion(goalId: goal.id, completedAt: now, rewardAmount: reward)
        context.insert(completion)
        pool.unlockedAmount += reward
        context.insert(RewardTransaction(type: .earn, amount: reward, title: goal.title, sourceId: completion.id, createdAt: now))
        save()

        return CompletionResult(
            completionId: completion.id,
            goalTitle: goal.title,
            requestedAmount: goal.rewardAmount,
            amount: reward,
            balanceBefore: before,
            balanceAfter: pool.availableAmount,
            rewardName: next?.name,
            rewardPrice: next?.price ?? 0
        )
    }

    func undoCompletion(id completionId: UUID) {
        let cid = completionId
        guard let completion = try? context.fetch(FetchDescriptor<GoalCompletion>(predicate: #Predicate { $0.id == cid })).first else { return }

        let date = completion.completedAt
        if let pool = currentPool(now: date) {
            pool.unlockedAmount = max(0, pool.unlockedAmount - completion.rewardAmount)
        }
        let optionalId: UUID? = cid
        if let transactions = try? context.fetch(FetchDescriptor<RewardTransaction>(predicate: #Predicate { $0.sourceId == optionalId })) {
            transactions.forEach(context.delete)
        }
        context.delete(completion)
        save()
    }

    // MARK: - Reward

    func nextReward() -> Reward? {
        var descriptor = FetchDescriptor<Reward>(
            predicate: #Predicate { $0.isPurchased == false },
            sortBy: [SortDescriptor(\.priority), SortDescriptor(\.price)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func purchase(_ reward: Reward, now: Date = .now) -> Bool {
        guard !reward.isPurchased, let pool = currentPool(now: now), pool.availableAmount >= reward.price else { return false }
        pool.spentAmount += reward.price
        reward.isPurchased = true
        reward.purchasedAt = now
        context.insert(RewardTransaction(type: .spend, amount: -reward.price, title: reward.name, sourceId: reward.id, createdAt: now))
        save()
        return true
    }

    func save() {
        try? context.save()
    }
}
