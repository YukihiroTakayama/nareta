import Foundation

struct DifficultySuggestion: Identifiable {
    enum Kind {
        case levelUp, easeDown
    }

    enum Change {
        case targetCount(Int)
        case duration(Int)
        case weekdaysOnly
        case reward(Int)
    }

    let goal: Goal
    let kind: Kind
    let rate: Double
    let change: Change?
    let message: String

    var id: UUID { goal.id }
}

/// 目標設定理論（Locke & Latham）: 「少しがんばれば届く」難しさが最も成果につながる。
/// 直近2週間の達成率が高すぎる目標は難しく、低すぎる目標はやさしくする提案を出す
enum DifficultyService {
    static let windowDays = 14
    static let highRate = 0.9
    static let lowRate = 0.5
    private static let dismissedKey = "difficulty.dismissed"

    static func suggestions(goals: [Goal], completions: [GoalCompletion], now: Date = .now) -> [DifficultySuggestion] {
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        return goals.compactMap { goal in
            guard goal.isLive, goal.frequency != .once, HabitService.days(since: goal, until: now) > windowDays else { return nil }
            let rate = rate(goal, byGoal[goal.id] ?? [], now: now)
            if rate >= highRate { return levelUp(goal, rate: rate) }
            if rate <= lowRate { return easeDown(goal, rate: rate) }
            return nil
        }
    }

    /// 今日を除く直近14日の達成率
    static func rate(_ goal: Goal, _ completions: [GoalCompletion], now: Date = .now) -> Double {
        let end = now.startOfDay
        let start = end.adding(days: -windowDays)
        let expected = GoalService.expected(goal, from: start, to: end)
        guard expected > 0 else { return 0 }
        let actual = completions.filter { $0.completedAt >= start && $0.completedAt < end }.count
        return min(1, Double(actual) / expected)
    }

    private static func levelUp(_ goal: Goal, rate: Double) -> DifficultySuggestion {
        switch goal.frequency {
        case .weekly where goal.targetCount < 7:
            return DifficultySuggestion(goal: goal, kind: .levelUp, rate: rate, change: .targetCount(goal.targetCount + 1),
                                        message: "週\(goal.targetCount)回 → 週\(goal.targetCount + 1)回")
        case .monthly where goal.targetCount < 31:
            return DifficultySuggestion(goal: goal, kind: .levelUp, rate: rate, change: .targetCount(goal.targetCount + 1),
                                        message: "月\(goal.targetCount)回 → 月\(goal.targetCount + 1)回")
        default:
            if goal.durationMinutes > 0 {
                return DifficultySuggestion(goal: goal, kind: .levelUp, rate: rate, change: .duration(goal.durationMinutes + 10),
                                            message: "\(goal.durationMinutes)分 → \(goal.durationMinutes + 10)分")
            }
            return DifficultySuggestion(goal: goal, kind: .levelUp, rate: rate, change: nil,
                                        message: "余裕を持って続けられています。習慣化メーターで卒業の条件を確認しましょう。")
        }
    }

    private static func easeDown(_ goal: Goal, rate: Double) -> DifficultySuggestion {
        switch goal.frequency {
        case .weekly where goal.targetCount > 1:
            return DifficultySuggestion(goal: goal, kind: .easeDown, rate: rate, change: .targetCount(goal.targetCount - 1),
                                        message: "週\(goal.targetCount)回 → 週\(goal.targetCount - 1)回")
        case .monthly where goal.targetCount > 1:
            return DifficultySuggestion(goal: goal, kind: .easeDown, rate: rate, change: .targetCount(goal.targetCount - 1),
                                        message: "月\(goal.targetCount)回 → 月\(goal.targetCount - 1)回")
        case .daily:
            return DifficultySuggestion(goal: goal, kind: .easeDown, rate: rate, change: .weekdaysOnly,
                                        message: "毎日 → 平日のみ（月〜金）")
        default:
            if goal.durationMinutes > 10 {
                return DifficultySuggestion(goal: goal, kind: .easeDown, rate: rate, change: .duration(goal.durationMinutes - 10),
                                            message: "\(goal.durationMinutes)分 → \(goal.durationMinutes - 10)分")
            }
            return DifficultySuggestion(goal: goal, kind: .easeDown, rate: rate, change: .reward(goal.rewardAmount + 50),
                                        message: "報酬 \(goal.rewardAmount.yen) → \((goal.rewardAmount + 50).yen) で後押し")
        }
    }

    static func apply(_ suggestion: DifficultySuggestion) {
        guard let change = suggestion.change else { return }
        let goal = suggestion.goal
        switch change {
        case .targetCount(let count):
            goal.targetCount = count
        case .duration(let minutes):
            goal.durationMinutes = minutes
        case .weekdaysOnly:
            goal.frequencyType = FrequencyType.weekdays.rawValue
            goal.weekdays = [2, 3, 4, 5, 6]
        case .reward(let amount):
            goal.rewardAmount = amount
        }
        dismiss(goal)
    }

    // MARK: - 今週は見送った提案

    private static func dismissKey(_ goal: Goal, now: Date) -> String {
        "\(Int(now.startOfWeek.timeIntervalSince1970))-\(goal.id.uuidString)"
    }

    static func isDismissed(_ goal: Goal, now: Date = .now) -> Bool {
        (UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []).contains(dismissKey(goal, now: now))
    }

    static func dismiss(_ goal: Goal, now: Date = .now) {
        var keys = UserDefaults.standard.stringArray(forKey: dismissedKey) ?? []
        keys.append(dismissKey(goal, now: now))
        UserDefaults.standard.set(Array(keys.suffix(200)), forKey: dismissedKey)
    }
}
