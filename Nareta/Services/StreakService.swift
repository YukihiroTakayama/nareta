import Foundation

/// 連続達成（1つ以上達成した日の連続）の可視化とマイルストーン
enum StreakService {
    /// 連続日数ごとのボーナス
    static let milestones: [(days: Int, bonus: Int)] = [
        (3, 100), (7, 300), (14, 500), (30, 1_000), (66, 2_000), (100, 3_000), (200, 5_000), (365, 10_000),
    ]

    static func nextMilestone(after streak: Int) -> (days: Int, bonus: Int)? {
        milestones.first { $0.days > streak }
    }

    /// 今の連続期間の初日（今日未達成なら昨日までの連続で数える）
    static func runStart(_ completions: [GoalCompletion], streak: Int, now: Date = .now) -> Date? {
        guard streak > 0 else { return nil }
        let today = now.startOfDay
        let doneToday = completions.contains { $0.completedAt.isSameDay(as: today) }
        let end = doneToday ? today : today.adding(days: -1)
        return end.adding(days: -(streak - 1))
    }

    static func activeDayCount(_ completions: [GoalCompletion]) -> Int {
        Set(completions.map { $0.completedAt.startOfDay }).count
    }

    struct DayCell: Identifiable, Hashable {
        let date: Date
        let isFuture: Bool
        let done: Int
        /// 0 = 未達成 … 4 = その日の目標をすべて達成
        let level: Int
        var id: Date { date }
    }

    static func level(done: Int, due: Int) -> Int {
        guard done > 0 else { return 0 }
        guard due > 0 else { return 4 }
        let ratio = Double(done) / Double(due)
        switch ratio {
        case ..<0.34: return 1
        case ..<0.67: return 2
        case ..<1: return 3
        default: return 4
        }
    }

    /// 週ごとの列（古い → 新しい）。各列は月曜 → 日曜
    static func heatmap(goals: [Goal], completions: [GoalCompletion], weeks: Int, now: Date = .now) -> [[DayCell]] {
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let today = now.startOfDay
        let firstWeek = now.startOfWeek.adding(days: -7 * (weeks - 1))
        return (0..<weeks).map { week in
            (0..<7).map { offset in
                let date = firstWeek.adding(days: week * 7 + offset)
                guard date <= today else { return DayCell(date: date, isFuture: true, done: 0, level: 0) }
                let stat = GoalService.dayStat(goals: goals, byGoal: byGoal, date: date)
                return DayCell(date: date, isFuture: false, done: stat.done, level: level(done: stat.done, due: stat.due))
            }
        }
    }
}
