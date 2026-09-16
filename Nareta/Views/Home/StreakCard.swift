import SwiftUI

private let flameGradient = LinearGradient(
    colors: [Color(hex: 0xFFC857), Color(hex: 0xF08A24)],
    startPoint: .top, endPoint: .bottom
)

/// 今週の連続達成と、次の連続ボーナスまでの距離
struct StreakCard: View {
    let goals: [Goal]
    let completions: [GoalCompletion]

    var body: some View {
        let now = Date()
        let today = now.startOfDay
        let streak = GoalService.dayStreak(completions, now: now)
        let doneToday = completions.contains { $0.completedAt.isSameDay(as: now) }
        let week = StreakService.heatmap(goals: goals, completions: completions, weeks: 1, now: now).first ?? []
        let next = StreakService.nextMilestone(after: streak)

        let status: String = if doneToday {
            "今日も達成！ 連続記録を更新中"
        } else if streak > 0 {
            "今日1つ達成で\(streak + 1)日連続。やらないと途切れます"
        } else {
            "今日1つ達成すると、連続記録がスタート"
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(flameGradient, in: Circle())
                    .opacity(streak > 0 ? 1 : 0.45)

                VStack(alignment: .leading, spacing: 2) {
                    Text(streak > 0 ? "\(streak)日連続" : "連続記録をはじめよう")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(value: Double(streak)))
                    Text(status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(doneToday ? Theme.green : (streak > 0 ? Color.orange : Theme.subtext))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                if let next {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(next.days)日連続ボーナス")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.subtext)
                        Text(next.bonus.signedYen)
                            .font(.system(size: 16, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.goldDeep)
                        Text("あと\(next.days - streak)日")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.subtext)
                    }
                }
            }

            HStack(spacing: 0) {
                ForEach(week) { cell in
                    VStack(spacing: 5) {
                        ZStack {
                            if cell.done > 0 {
                                Circle().fill(flameGradient)
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)
                            } else if cell.date == today {
                                Circle().strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                            } else {
                                Circle().fill(cell.isFuture ? Theme.chip.opacity(0.5) : Theme.chip)
                            }
                        }
                        .frame(width: 32, height: 32)

                        Text(Weekday.label(cell.date.weekday))
                            .font(.system(size: 11, weight: cell.date == today ? .bold : .medium))
                            .foregroundStyle(cell.date == today ? Theme.ink : Theme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if let next {
                LinearBar(progress: Double(streak) / Double(next.days), color: .orange, height: 6)
            }
        }
        .cardStyle()
    }
}
