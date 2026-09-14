import Foundation

/// 目標の期間判定・達成可否・Streak・達成率などの純粋ロジック
enum GoalService {
    private static var cal: Calendar { .nareta }

    // MARK: - 期間

    static func periodInterval(for goal: Goal, now: Date = .now) -> DateInterval? {
        switch goal.frequency {
        case .daily, .weekdays: return cal.dateInterval(of: .day, for: now)
        case .weekly: return cal.dateInterval(of: .weekOfYear, for: now)
        case .monthly: return cal.dateInterval(of: .month, for: now)
        case .once: return nil
        }
    }

    static func periodTarget(_ goal: Goal) -> Int {
        switch goal.frequency {
        case .weekly, .monthly: return max(1, goal.targetCount)
        default: return 1
        }
    }

    static func count(_ completions: [GoalCompletion], in interval: DateInterval) -> Int {
        completions.filter { $0.completedAt >= interval.start && $0.completedAt < interval.end }.count
    }

    static func periodCount(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> Int {
        guard let interval = periodInterval(for: goal, now: now) else { return completions.count }
        return count(completions, in: interval)
    }

    static func isPeriodDone(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> Bool {
        periodCount(goal, completions, now: now) >= periodTarget(goal)
    }

    static func isCompletedToday(_ completions: [GoalCompletion], now: Date = .now) -> Bool {
        completions.contains { cal.isDate($0.completedAt, inSameDayAs: now) }
    }

    static func isScheduled(_ goal: Goal, on date: Date) -> Bool {
        goal.frequency != .weekdays || goal.weekdays.contains(cal.component(.weekday, from: date))
    }

    // MARK: - 達成可否

    static func canComplete(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> Bool {
        goal.isActive
            && isScheduled(goal, on: now)
            && !isCompletedToday(completions, now: now)
            && periodCount(goal, completions, now: now) < periodTarget(goal)
    }

    /// 達成できない理由（UI表示用）
    static func blockedReason(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> String? {
        if !goal.isActive { return "一時停止中です" }
        if !isScheduled(goal, on: now) { return "今日は実施日ではありません" }
        if isCompletedToday(completions, now: now) { return "今日は達成済みです" }
        if isPeriodDone(goal, completions, now: now) {
            switch goal.frequency {
            case .weekly: return "今週の目標回数を達成しました"
            case .monthly: return "今月の目標回数を達成しました"
            case .once: return "達成済みです"
            default: return "達成済みです"
            }
        }
        return nil
    }

    static func showsInToday(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> Bool {
        guard goal.isActive, isScheduled(goal, on: now) else { return false }
        switch goal.frequency {
        case .daily, .weekdays:
            return true
        case .weekly, .monthly, .once:
            return isCompletedToday(completions, now: now) || !isPeriodDone(goal, completions, now: now)
        }
    }

    // MARK: - Streak

    static func streak(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> Int {
        switch goal.frequency {
        case .daily, .weekdays:
            let days = Set(completions.map { $0.completedAt.startOfDay })
            var day = now.startOfDay
            if !days.contains(day) { day = day.adding(days: -1) }
            let created = goal.createdAt.startOfDay
            var result = 0
            for _ in 0..<3650 {
                guard day >= created else { break }
                if goal.frequency == .weekdays && !goal.weekdays.contains(day.weekday) {
                    day = day.adding(days: -1)
                    continue
                }
                guard days.contains(day) else { break }
                result += 1
                day = day.adding(days: -1)
            }
            return result

        case .weekly, .monthly:
            let component: Calendar.Component = goal.frequency == .weekly ? .weekOfYear : .month
            let target = periodTarget(goal)
            guard var interval = cal.dateInterval(of: component, for: now) else { return 0 }
            if count(completions, in: interval) < target {
                guard let prev = cal.dateInterval(of: component, for: interval.start.addingTimeInterval(-1)) else { return 0 }
                interval = prev
            }
            var result = 0
            for _ in 0..<520 {
                guard interval.end > goal.createdAt, count(completions, in: interval) >= target else { break }
                result += 1
                guard let prev = cal.dateInterval(of: component, for: interval.start.addingTimeInterval(-1)) else { break }
                interval = prev
            }
            return result

        case .once:
            return 0
        }
    }

    static func streakText(_ goal: Goal, _ value: Int) -> String {
        switch goal.frequency {
        case .daily, .weekdays: "\(value)日"
        case .weekly: "\(value) weeks"
        case .monthly: "\(value) months"
        case .once: "—"
        }
    }

    /// 1つ以上達成した日の連続日数（今日未達成なら昨日まで）
    static func dayStreak(_ completions: [GoalCompletion], now: Date = .now) -> Int {
        let days = Set(completions.map { $0.completedAt.startOfDay })
        var day = now.startOfDay
        if !days.contains(day) { day = day.adding(days: -1) }
        var result = 0
        while days.contains(day) {
            result += 1
            day = day.adding(days: -1)
        }
        return result
    }

    static func longestDayStreak(_ completions: [GoalCompletion]) -> Int {
        let days = Set(completions.map { $0.completedAt.startOfDay }).sorted()
        var longest = 0
        var current = 0
        var previous: Date?
        for day in days {
            if let previous, previous.adding(days: 1).isSameDay(as: day) {
                current += 1
            } else {
                current = 1
            }
            longest = max(longest, current)
            previous = day
        }
        return longest
    }

    // MARK: - 達成率

    static func expected(_ goal: Goal, from start: Date, to end: Date) -> Double {
        let s = max(start, goal.createdAt.startOfDay)
        guard s < end else { return 0 }
        let days = max(0, cal.dateComponents([.day], from: s, to: end).day ?? 0)
        switch goal.frequency {
        case .daily:
            return Double(days)
        case .weekdays:
            return Double((0..<days).filter { goal.weekdays.contains(s.adding(days: $0).weekday) }.count)
        case .weekly:
            return Double(goal.targetCount) * Double(days) / 7
        case .monthly:
            return Double(goal.targetCount) * Double(days) / 30
        case .once:
            return 0
        }
    }

    static func achievementRate(goals: [Goal], completions: [GoalCompletion], from start: Date, to end: Date) -> Double {
        let targets = goals.filter { $0.isActive && $0.frequency != .once }
        let ids = Set(targets.map(\.id))
        let expectedTotal = targets.reduce(0.0) { $0 + expected($1, from: start, to: end) }
        guard expectedTotal > 0 else { return 0 }
        let actual = completions.filter { ids.contains($0.goalId) && $0.completedAt >= start && $0.completedAt < end }.count
        return min(1, Double(actual) / expectedTotal)
    }

    struct DayStat {
        let date: Date
        let done: Int
        let due: Int
        var rate: Double? { due == 0 ? nil : min(1, Double(done) / Double(due)) }
    }

    /// 毎日・曜日指定の目標を分母に、その他の目標の達成はボーナスとして分母分子に加える
    static func dayStat(goals: [Goal], byGoal: [UUID: [GoalCompletion]], date: Date) -> DayStat {
        guard let day = cal.dateInterval(of: .day, for: date) else { return DayStat(date: date, done: 0, due: 0) }
        var done = 0
        var due = 0
        for goal in goals {
            let c = count(byGoal[goal.id] ?? [], in: day)
            let isDue = goal.isActive
                && (goal.frequency == .daily || goal.frequency == .weekdays)
                && isScheduled(goal, on: date)
                && goal.createdAt.startOfDay <= day.start
            if isDue {
                due += 1
                done += min(c, 1)
            } else if c > 0 {
                due += c
                done += c
            }
        }
        return DayStat(date: date, done: done, due: due)
    }

    /// 過去30日の「なりたい自分」スコア（ゲーム的スコア）
    static func identityScore(identity: Identity, goals: [Goal], completions: [GoalCompletion], now: Date = .now) -> Double {
        let linked = goals.filter { $0.identityId == identity.id }
        guard !linked.isEmpty else { return 0 }
        let end = now.startOfDay.adding(days: 1)
        let start = end.adding(days: -30)
        return achievementRate(goals: linked, completions: completions, from: start, to: end)
    }
}
