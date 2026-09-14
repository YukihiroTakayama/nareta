import Foundation

/// 習慣化・卒業・復帰ボーナス・Streak Freezeのロジック
///
/// - 習慣化の目安 66日: Lally et al., 2010（中央値66日、18〜254日）
/// - 自動化度: SRBAI（Gardner et al., 2012）
/// - 休んだ後に戻ることへの報酬: Milkman et al., 2021（Nature megastudy）
/// - 1回の失敗で崩れない仕組み: What-the-hell effect（Polivy & Herman）への対策
enum HabitService {
    static let formationDays = 66
    static let rateThreshold = 0.8
    static let automaticityThreshold = 5.5
    static let checkInterval = 7
    static let checkMinimumDays = 14
    static let freezesPerMonth = 2

    private static var cal: Calendar { .nareta }

    // MARK: - 習慣化・卒業

    /// 取り組み始めてからの日数（初日 = 1）
    static func days(since goal: Goal, until date: Date = .now) -> Int {
        (cal.dateComponents([.day], from: goal.createdAt.startOfDay, to: date.startOfDay).day ?? 0) + 1
    }

    /// 直近4週の達成率
    static func recentRate(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> Double {
        let end = now.startOfDay.adding(days: 1)
        let start = end.adding(days: -28)
        let expected = GoalService.expected(goal, from: start, to: end)
        guard expected > 0 else { return 0 }
        let actual = completions.filter { $0.completedAt >= start && $0.completedAt < end }.count
        return min(1, Double(actual) / expected)
    }

    struct GraduationStatus {
        let days: Int
        let rate: Double
        let latestAutomaticity: Double?
        let automaticityPassed: Bool

        var daysPassed: Bool { days >= HabitService.formationDays }
        var ratePassed: Bool { rate >= HabitService.rateThreshold }
        var isReady: Bool { daysPassed && ratePassed && automaticityPassed }
    }

    static func graduationStatus(_ goal: Goal, _ completions: [GoalCompletion], _ checks: [AutomaticityCheck], now: Date = .now) -> GraduationStatus {
        let sorted = checks.sorted { $0.checkedAt > $1.checkedAt }
        let lastTwo = sorted.prefix(2)
        return GraduationStatus(
            days: days(since: goal, until: now),
            rate: recentRate(goal, completions, now: now),
            latestAutomaticity: sorted.first?.average,
            automaticityPassed: lastTwo.count == 2 && lastTwo.allSatisfy { $0.average >= automaticityThreshold }
        )
    }

    static func isGraduatable(_ goal: Goal) -> Bool {
        goal.frequency != .once && goal.archivedAt == nil
    }

    static func needsAutomaticityCheck(_ goal: Goal, _ checks: [AutomaticityCheck], now: Date = .now) -> Bool {
        guard goal.isLive, isGraduatable(goal), days(since: goal, until: now) >= checkMinimumDays else { return false }
        guard let last = checks.map(\.checkedAt).max() else { return true }
        return (cal.dateComponents([.day], from: last.startOfDay, to: now.startOfDay).day ?? 0) >= checkInterval
    }

    /// 卒業した目標に使っていた月の報酬額の目安
    static func monthlyRewardEstimate(_ goal: Goal) -> Int {
        let perMonth: Double = switch goal.frequency {
        case .daily: 30
        case .weekdays: Double(goal.weekdays.count) * 4.3
        case .weekly: Double(goal.targetCount) * 4.3
        case .monthly: Double(goal.targetCount)
        case .once: 1
        }
        return Int((perMonth * Double(goal.rewardAmount) / 100).rounded()) * 100
    }

    // MARK: - 復帰ボーナス

    static func previousScheduledDay(_ goal: Goal, before date: Date) -> Date? {
        var day = date.startOfDay.adding(days: -1)
        for _ in 0..<7 {
            if day < goal.createdAt.startOfDay { return nil }
            if GoalService.isScheduled(goal, on: day) { return day }
            day = day.adding(days: -1)
        }
        return nil
    }

    /// 実施日を2回続けて逃した後に戻ってきたら、報酬の50%を上乗せ。
    /// 1回休みで付けると「1日おきにやる」方が毎日より得になるため、2回連続を条件にする
    static func comebackBonus(_ goal: Goal, _ completions: [GoalCompletion], frozenDays: Set<Date>, now: Date = .now) -> Int {
        let prior = completions.filter { $0.completedAt < now.startOfDay }
        guard !prior.isEmpty else { return 0 }

        let missed: Bool
        switch goal.frequency {
        case .daily, .weekdays:
            guard let previous = previousScheduledDay(goal, before: now),
                  let beforePrevious = previousScheduledDay(goal, before: previous) else { return 0 }
            let kept: (Date) -> Bool = { day in
                prior.contains { $0.completedAt.isSameDay(as: day) } || frozenDays.contains(day)
            }
            missed = !kept(previous) && !kept(beforePrevious)
        case .weekly:
            guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now),
                  let lastWeek = cal.dateInterval(of: .weekOfYear, for: thisWeek.start.addingTimeInterval(-1)),
                  lastWeek.end > goal.createdAt else { return 0 }
            missed = GoalService.count(completions, in: thisWeek) == 0
                && GoalService.count(completions, in: lastWeek) < GoalService.periodTarget(goal)
        case .monthly, .once:
            return 0
        }
        guard missed else { return 0 }
        return max(10, Int((Double(goal.rewardAmount) * 0.5 / 10).rounded()) * 10)
    }

    // MARK: - Streak Freeze

    static func freezesUsed(_ freezes: [StreakFreeze], now: Date = .now) -> Int {
        freezes.filter { $0.createdAt >= now.startOfMonth }.count
    }

    /// Freezeで守れる日（直近の実施日を逃していて、その前まではStreakが続いていた）
    static func freezableDay(_ goal: Goal, _ completions: [GoalCompletion], goalFreezes: [StreakFreeze], allFreezes: [StreakFreeze], now: Date = .now) -> Date? {
        guard goal.isLive,
              goal.frequency == .daily || goal.frequency == .weekdays,
              freezesUsed(allFreezes, now: now) < freezesPerMonth,
              let previous = previousScheduledDay(goal, before: now) else { return nil }

        let frozen = Set(goalFreezes.map(\.date))
        guard !frozen.contains(previous),
              !completions.contains(where: { $0.completedAt.isSameDay(as: previous) }),
              let before = previousScheduledDay(goal, before: previous),
              completions.contains(where: { $0.completedAt.isSameDay(as: before) }) || frozen.contains(before)
        else { return nil }
        return previous
    }
}
