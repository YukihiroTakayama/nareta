import SwiftUI

private let flameGradient = LinearGradient(
    colors: [Color(hex: 0xFFC857), Color(hex: 0xF08A24)],
    startPoint: .top, endPoint: .bottom
)

/// 継続カレンダー（ヒートマップ）・連続記録・バッジ
struct ContinuityCard: View {
    let goals: [Goal]
    let completions: [GoalCompletion]
    private let weeks = 15

    var body: some View {
        let current = GoalService.dayStreak(completions)
        let longest = GoalService.longestDayStreak(completions)
        let activeDays = StreakService.activeDayCount(completions)
        let grid = StreakService.heatmap(goals: goals, completions: completions, weeks: weeks)

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("継続の記録").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                Text("1マスが1日。色が濃いほど、その日の目標を達成しています")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.subtext)
            }

            HStack(spacing: 0) {
                stat(icon: "flame.fill", color: .orange, label: "現在の連続", value: "\(current)日")
                separator
                stat(icon: "trophy.fill", color: Theme.gold, label: "最長", value: "\(longest)日")
                separator
                stat(icon: "calendar", color: Theme.green, label: "達成した日", value: "\(activeDays)日")
            }

            heatmap(grid)

            HStack(spacing: 4) {
                Spacer()
                Text("少ない").font(.system(size: 10)).foregroundStyle(Theme.subtext)
                ForEach(0...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2).fill(color(level: level)).frame(width: 10, height: 10)
                }
                Text("多い").font(.system(size: 10)).foregroundStyle(Theme.subtext)
            }

            badges(longest: longest)
        }
        .cardStyle()
    }

    private func heatmap(_ grid: [[StreakService.DayCell]]) -> some View {
        let today = Date().startOfDay
        return HStack(alignment: .top, spacing: 4) {
            ForEach(grid.indices, id: \.self) { week in
                VStack(spacing: 4) {
                    Text(monthLabel(grid, week: week))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.subtext)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, minHeight: 11, alignment: .leading)
                    ForEach(grid[week]) { cell in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(cell.isFuture ? Color.clear : color(level: cell.level))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if cell.date == today {
                                    RoundedRectangle(cornerRadius: 3).stroke(Theme.ink.opacity(0.6), lineWidth: 1.2)
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthLabel(_ grid: [[StreakService.DayCell]], week: Int) -> String {
        guard let first = grid[week].first?.date else { return "" }
        if week == 0 { return "\(first.month)月" }
        guard let previous = grid[week - 1].first?.date else { return "" }
        return previous.month != first.month ? "\(first.month)月" : ""
    }

    private func color(level: Int) -> Color {
        switch level {
        case 1: Theme.green.opacity(0.3)
        case 2: Theme.green.opacity(0.55)
        case 3: Theme.green.opacity(0.8)
        case 4: Theme.green
        default: Theme.chip
        }
    }

    private var separator: some View {
        Rectangle().fill(Theme.line).frame(width: 1, height: 40)
    }

    private func stat(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.subtext)
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private func badges(longest: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("連続記録バッジ").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StreakService.milestones, id: \.days) { milestone in
                        let earned = longest >= milestone.days
                        VStack(spacing: 4) {
                            ZStack {
                                if earned {
                                    Circle().fill(flameGradient)
                                } else {
                                    Circle().fill(Theme.chip)
                                }
                                Image(systemName: earned ? "flame.fill" : "lock.fill")
                                    .font(.system(size: earned ? 18 : 14))
                                    .foregroundStyle(earned ? .white : Theme.subtext)
                            }
                            .frame(width: 44, height: 44)
                            Text("\(milestone.days)日")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(earned ? Theme.ink : Theme.subtext)
                            Text(milestone.bonus.signedYen)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(earned ? Theme.goldDeep : Theme.subtext)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
