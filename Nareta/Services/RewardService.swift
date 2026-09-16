import Foundation
import SwiftData

struct CompletionResult: Identifiable, Equatable {
    let id = UUID()
    let completionId: UUID
    let goalTitle: String
    let requestedAmount: Int
    let amount: Int
    let bonusAmount: Int
    let balanceBefore: Int
    let balanceAfter: Int
    let rewardName: String?
    let rewardPrice: Int
    /// 記録し忘れた日の分として入れたときの日付
    var recordedDay: Date?
    var streak: Int = 0
    var milestoneDays: Int?
    var milestoneBonus: Int = 0

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

    func pool(year: Int, month: Int) -> MonthlyRewardPool? {
        let descriptor = FetchDescriptor<MonthlyRewardPool>(predicate: #Predicate { $0.year == year && $0.month == month })
        return try? context.fetch(descriptor).first
    }

    func currentPool(now: Date = .now) -> MonthlyRewardPool? {
        pool(year: now.year, month: now.month)
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

    func allCompletions() -> [GoalCompletion] {
        (try? context.fetch(FetchDescriptor<GoalCompletion>())) ?? []
    }

    func alreadyCompleted(_ goal: Goal, now: Date = .now) -> Bool {
        !GoalService.canComplete(goal, completions(for: goal), now: now)
    }

    /// 目標を達成にする。backfill = true なら `now` の日の分（記録し忘れ）として記録し、報酬は今月のPoolに入れる
    func completeGoal(_ goal: Goal, now: Date = .now, backfill: Bool = false) -> CompletionResult? {
        let completions = completions(for: goal)
        guard GoalService.canComplete(goal, completions, now: now) else { return nil }

        let creditDate = backfill ? Date() : now
        let pool = currentPool(now: creditDate)
            ?? startPool(amount: latestPool()?.totalAmount ?? Self.defaultPoolAmount, now: creditDate)
        let before = pool.availableAmount
        let next = nextReward()

        let frozen = Set(freezes(for: goal).map(\.date))
        let bonus = backfill ? 0 : HabitService.comebackBonus(goal, completions, frozenDays: frozen, now: now)
        let requested = goal.rewardAmount + bonus
        let remaining = pool.totalAmount - pool.unlockedAmount
        let reward = max(0, min(requested, remaining))
        let appliedBonus = max(0, reward - goal.rewardAmount)

        let completion = GoalCompletion(goalId: goal.id, completedAt: now, rewardAmount: reward)
        completion.bonusAmount = appliedBonus
        completion.creditedYear = pool.year
        completion.creditedMonth = pool.month
        completion.isBackfilled = backfill
        context.insert(completion)
        pool.unlockedAmount += reward

        var title = appliedBonus > 0 ? "\(goal.title)（復帰ボーナス \(appliedBonus.signedYen)）" : goal.title
        if backfill { title += "（\(now.monthDayText)の分）" }
        context.insert(RewardTransaction(type: .earn, amount: reward, title: title, sourceId: completion.id, createdAt: now))
        save()

        let milestone = awardStreakMilestones(pool: pool, completionId: completion.id)
        let streak = GoalService.dayStreak(allCompletions())

        return CompletionResult(
            completionId: completion.id,
            goalTitle: goal.title,
            requestedAmount: requested,
            amount: reward,
            bonusAmount: appliedBonus,
            balanceBefore: before,
            balanceAfter: pool.availableAmount,
            rewardName: next?.name,
            rewardPrice: next?.price ?? 0,
            recordedDay: backfill ? now.startOfDay : nil,
            streak: streak,
            milestoneDays: milestone?.days,
            milestoneBonus: milestone?.amount ?? 0
        )
    }

    /// 連続日数がマイルストーンに届いていたらボーナスを解放（同じ連続期間では1回だけ）
    private func awardStreakMilestones(pool: MonthlyRewardPool, completionId: UUID, today: Date = .now) -> (days: Int, amount: Int)? {
        let all = allCompletions()
        let streak = GoalService.dayStreak(all, now: today)
        guard streak > 0, let runStart = StreakService.runStart(all, streak: streak, now: today) else { return nil }

        let existing = (try? context.fetch(FetchDescriptor<StreakMilestone>())) ?? []
        var latest: (days: Int, amount: Int)?
        for milestone in StreakService.milestones where milestone.days <= streak {
            let days = milestone.days
            guard !existing.contains(where: { $0.days == days && $0.achievedAt >= runStart }) else { continue }
            let amount = max(0, min(milestone.bonus, pool.totalAmount - pool.unlockedAmount))
            let record = StreakMilestone(days: days, amount: amount, achievedAt: today, completionId: completionId)
            context.insert(record)
            pool.unlockedAmount += amount
            context.insert(RewardTransaction(type: .earn, amount: amount, title: "\(days)日連続ボーナス", sourceId: record.id, createdAt: today))
            latest = (days, amount)
        }
        if latest != nil { save() }
        return latest
    }

    func undoCompletion(id completionId: UUID) {
        let cid = completionId
        guard let completion = try? context.fetch(FetchDescriptor<GoalCompletion>(predicate: #Predicate { $0.id == cid })).first else { return }

        let creditedPool = completion.creditedYear > 0
            ? pool(year: completion.creditedYear, month: completion.creditedMonth)
            : currentPool(now: completion.completedAt)
        if let creditedPool {
            creditedPool.unlockedAmount = max(0, creditedPool.unlockedAmount - completion.rewardAmount)
        }
        deleteTransactions(sourceId: cid)

        // この達成で解放した連続ボーナスも取り消す
        let optionalId: UUID? = cid
        let milestones = (try? context.fetch(FetchDescriptor<StreakMilestone>(predicate: #Predicate { $0.completionId == optionalId }))) ?? []
        for milestone in milestones {
            if let creditedPool {
                creditedPool.unlockedAmount = max(0, creditedPool.unlockedAmount - milestone.amount)
            }
            deleteTransactions(sourceId: milestone.id)
            context.delete(milestone)
        }

        context.delete(completion)
        save()
    }

    private func deleteTransactions(sourceId: UUID) {
        let optionalId: UUID? = sourceId
        let transactions = (try? context.fetch(FetchDescriptor<RewardTransaction>(predicate: #Predicate { $0.sourceId == optionalId }))) ?? []
        transactions.forEach(context.delete)
    }

    // MARK: - 習慣化

    func freezes(for goal: Goal) -> [StreakFreeze] {
        let goalId = goal.id
        return (try? context.fetch(FetchDescriptor<StreakFreeze>(predicate: #Predicate { $0.goalId == goalId }))) ?? []
    }

    func applyFreeze(_ goal: Goal, day: Date) {
        context.insert(StreakFreeze(goalId: goal.id, date: day))
        save()
    }

    func recordAutomaticity(_ goal: Goal, scores: [Int]) {
        context.insert(AutomaticityCheck(goalId: goal.id, scores: scores))
        save()
    }

    func graduate(_ goal: Goal, now: Date = .now) {
        goal.archivedAt = now
        save()
    }

    func restore(_ goal: Goal) {
        goal.archivedAt = nil
        goal.isActive = true
        save()
    }

    func togglePause(_ goal: Goal) {
        goal.isActive.toggle()
        save()
    }

    /// 解放済みのお金と履歴は残す
    func deleteGoal(_ goal: Goal) {
        context.delete(goal)
        save()
    }

    func deleteReward(_ reward: Reward) {
        context.delete(reward)
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
