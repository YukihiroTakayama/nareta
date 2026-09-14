import Foundation

/// If-Thenのトリガー時刻の計算
enum TriggerService {
    static let offsets = [-60, -30, -15, 0, 15, 30, 60]

    static func normalize(_ minutes: Int) -> Int {
        ((minutes % 1440) + 1440) % 1440
    }

    static func timeText(_ minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    static func offsetText(_ offset: Int) -> String {
        if offset == 0 { return "ちょうど" }
        let value = abs(offset)
        let unit = value % 60 == 0 ? "\(value / 60)時間" : "\(value)分"
        return offset > 0 ? "\(unit)後" : "\(unit)前"
    }

    static func routine(for goal: Goal, routines: [RoutineAnchor]) -> RoutineAnchor? {
        guard let routineId = goal.routineId else { return nil }
        return routines.first { $0.id == routineId }
    }

    /// 実際に知らせる時刻（0時からの分）
    static func minutes(for goal: Goal, routines: [RoutineAnchor]) -> Int? {
        if let routine = routine(for: goal, routines: routines) {
            return normalize(routine.minutes + goal.triggerOffset)
        }
        return goal.triggerMinutes >= 0 ? normalize(goal.triggerMinutes) : nil
    }

    /// 例: 「夕食の1時間後（20:00）」「21:00」
    static func label(for goal: Goal, routines: [RoutineAnchor]) -> String? {
        guard let minutes = minutes(for: goal, routines: routines) else { return nil }
        if let routine = routine(for: goal, routines: routines) {
            let suffix = goal.triggerOffset == 0 ? "" : "の" + offsetText(goal.triggerOffset)
            return "\(routine.name)\(suffix)（\(timeText(minutes))）"
        }
        return timeText(minutes)
    }

    static func date(_ minutes: Int, on day: Date) -> Date {
        Calendar.nareta.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day) ?? day
    }

    /// これから知らせる日時（達成済み・実施日でない・期間の回数を満たした日は除く）
    static func fireDates(for goal: Goal, minutes: Int, completions: [GoalCompletion], now: Date = .now, days: Int = 7) -> [Date] {
        guard goal.isLive else { return [] }
        if goal.frequency == .once && !completions.isEmpty { return [] }

        let isCountGoal = goal.frequency == .weekly || goal.frequency == .monthly
        let currentPeriod = GoalService.periodInterval(for: goal, now: now)
        let currentPeriodDone = GoalService.isPeriodDone(goal, completions, now: now)

        var result: [Date] = []
        for offset in 0..<days {
            let day = now.startOfDay.adding(days: offset)
            let fire = date(minutes, on: day)
            guard fire > now, GoalService.isScheduled(goal, on: day) else { continue }
            if offset == 0 && !GoalService.canComplete(goal, completions, now: now) { continue }
            if isCountGoal, currentPeriodDone, let currentPeriod, day >= currentPeriod.start, day < currentPeriod.end { continue }
            result.append(fire)
        }
        return result
    }
}
