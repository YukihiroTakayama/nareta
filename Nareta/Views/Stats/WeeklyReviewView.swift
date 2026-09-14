import Charts
import SwiftData
import SwiftUI

struct WeeklyReviewView: View {
    @Environment(AppState.self) private var appState

    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query private var completions: [GoalCompletion]

    @State private var weekOffset = 0

    private struct WeekSummary {
        let start: Date
        let days: [GoalService.DayStat]
        let rate: Double
        let actions: Int
        let earned: Int
        let longestRun: Int
        let completions: [GoalCompletion]
    }

    private func summary(offset: Int) -> WeekSummary {
        let start = Date().startOfWeek.adding(days: 7 * offset)
        let end = start.adding(days: 7)
        let today = Date().startOfDay
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let days = (0..<7).map { GoalService.dayStat(goals: goals, byGoal: byGoal, date: start.adding(days: $0)) }
        let elapsed = days.filter { $0.date <= today }
        let done = elapsed.reduce(0) { $0 + $1.done }
        let due = elapsed.reduce(0) { $0 + $1.due }
        let weekCompletions = completions.filter { $0.completedAt >= start && $0.completedAt < end }

        var run = 0
        var longest = 0
        for day in elapsed {
            if weekCompletions.contains(where: { $0.completedAt.isSameDay(as: day.date) }) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }

        return WeekSummary(
            start: start,
            days: days,
            rate: due == 0 ? 0 : min(1, Double(done) / Double(due)),
            actions: weekCompletions.count,
            earned: weekCompletions.reduce(0) { $0 + $1.rewardAmount },
            longestRun: longest,
            completions: weekCompletions
        )
    }

    var body: some View {
        let current = summary(offset: weekOffset)
        let previous = summary(offset: weekOffset - 1)
        let weekStreak = weekStreakCount()

        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Text(weekOffset == 0 ? "今週のふりかえり" : "ふりかえり")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Menu {
                        ForEach(0..<8, id: \.self) { i in
                            Button(weekLabel(Date().startOfWeek.adding(days: -7 * i))) { weekOffset = -i }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(weekLabel(current.start)).font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(.white, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line))
                    }
                }

                HeroCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("達成率").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            if weekStreak > 0 { StreakBadge(text: "\(weekStreak) WEEK STREAK") }
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int((current.rate * 100).rounded()))")
                                .font(.system(size: 60, weight: .heavy))
                                .foregroundStyle(Theme.goldGradient)
                            Text("%").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.goldGradient)
                        }
                        deltaText(Int(((current.rate - previous.rate) * 100).rounded()), unit: "%")
                        HStack(spacing: 12) {
                            GoldProgressBar(progress: current.rate)
                            PercentLabel(progress: current.rate)
                        }
                        .padding(.trailing, 96)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("日別の達成率").font(.system(size: 18, weight: .bold))
                        Spacer()
                        Text(cheer(current.rate)).font(.system(size: 13)).foregroundStyle(Theme.subtext)
                    }
                    Chart {
                        ForEach(current.days, id: \.date) { day in
                            let pct = (day.rate ?? 0) * 100
                            BarMark(
                                x: .value("曜日", Weekday.label(day.date.weekday)),
                                y: .value("達成率", pct),
                                width: .ratio(0.6)
                            )
                            .cornerRadius(6)
                            .foregroundStyle(Theme.blue.opacity(0.35 + 0.65 * (day.rate ?? 0)))
                            .annotation(position: .top, spacing: 4) {
                                if day.date <= Date(), day.rate != nil {
                                    Text("\(Int(pct.rounded()))%").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.ink)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...115)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                            AxisGridLine().foregroundStyle(Theme.line)
                            AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").font(.system(size: 11)) }
                        }
                    }
                    .frame(height: 210)
                }
                .cardStyle()

                HStack(spacing: 10) {
                    tile(icon: "checkmark.circle.fill", color: Theme.green, label: "達成した行動", value: "\(current.actions)回",
                         delta: current.actions - previous.actions, unit: "回")
                    tile(icon: "gift", color: Theme.gold, label: "解放したごほうび", value: current.earned.yen,
                         delta: current.earned - previous.earned, unit: "¥")
                    tile(icon: "flame.fill", color: .orange, label: "最長連続達成", value: "\(current.longestRun)日",
                         delta: current.longestRun - previous.longestRun, unit: "日")
                }

                highlights(current)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        IconBadge(systemName: "chart.bar.fill", color: Theme.ink, background: Theme.chip, size: 38)
                        Text("インサイト").font(.system(size: 18, weight: .bold))
                    }
                    Text(insight(current))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.ink.opacity(0.85))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .cardStyle()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                PrimaryButton(title: "来週の目標を調整", icon: "chevron.right", kind: .blue) {
                    appState.selectedTab = .goals
                }
            }
        }
    }

    private func weekLabel(_ start: Date) -> String {
        let week = Calendar.nareta.component(.weekOfMonth, from: start)
        return "\(start.month)月 第\(week)週"
    }

    private func weekStreakCount() -> Int {
        var count = 0
        let thisWeek = summary(offset: 0)
        var offset = thisWeek.rate >= 0.6 ? 0 : -1
        while offset > -52 {
            let s = summary(offset: offset)
            guard s.rate >= 0.6 else { break }
            count += 1
            offset -= 1
        }
        return count
    }

    private func cheer(_ rate: Double) -> String {
        switch rate {
        case 0.8...: "最高の1週間です"
        case 0.6..<0.8: "今週もよくがんばりました"
        case 0.3..<0.6: "あと少しで波に乗れます"
        default: "小さな1つから始めよう"
        }
    }

    @ViewBuilder
    private func deltaText(_ delta: Int, unit: String) -> some View {
        HStack(spacing: 6) {
            Text("先週より").foregroundStyle(.white.opacity(0.75))
            Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: 11))
            Text("\(delta >= 0 ? "+" : "")\(delta)\(unit)")
                .fontWeight(.bold)
        }
        .font(.system(size: 17))
        .foregroundStyle(delta >= 0 ? Color(hex: 0x4ADE80) : Color(hex: 0xF87171))
    }

    private func tile(icon: String, color: Color, label: String, value: String, delta: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(color)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.ink.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.7)
            Text(value).font(.system(size: 22, weight: .heavy)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            let deltaString = unit == "¥" ? delta.signedYen : "\(delta >= 0 ? "+" : "")\(delta)\(unit)"
            Text("先週より \(Text(deltaString).foregroundStyle(delta >= 0 ? Theme.green : Theme.red).fontWeight(.bold))")
                .font(.system(size: 11))
                .foregroundStyle(Theme.subtext)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 12)
    }

    @ViewBuilder
    private func highlights(_ week: WeekSummary) -> some View {
        let counts = Dictionary(grouping: week.completions, by: \.goalId).mapValues(\.count)
        let best = goals.filter { counts[$0.id] != nil }.max { (counts[$0.id] ?? 0) < (counts[$1.id] ?? 0) }
        let improvable = goals
            .filter { $0.isLive && $0.frequency != .once }
            .map { goal -> (Goal, Double) in
                let expected = GoalService.expected(goal, from: week.start, to: min(week.start.adding(days: 7), Date().startOfDay.adding(days: 1)))
                return (goal, expected > 0 ? Double(counts[goal.id] ?? 0) / expected : 1)
            }
            .filter { $0.1 < 1 }
            .min { $0.1 < $1.1 }?.0

        if best != nil || improvable != nil {
            HStack(spacing: 10) {
                if let best {
                    highlight(title: "最も達成", goal: best.title, detail: "\(counts[best.id] ?? 0)回", color: Theme.green, icon: "trophy.fill")
                }
                if let improvable {
                    highlight(title: "改善", goal: improvable.title, detail: "来週はここを意識", color: .orange, icon: "arrow.up.forward.circle.fill")
                }
            }
        }
    }

    private func highlight(title: String, goal: String, detail: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            Text(goal).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
            Text(detail).font(.system(size: 12)).foregroundStyle(Theme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 14)
    }

    private func insight(_ week: WeekSummary) -> String {
        let elapsed = week.days.filter { $0.date <= Date() && $0.rate != nil }
        guard elapsed.count >= 2 else {
            return "データが集まると、曜日ごとの傾向がここに表示されます。まずは今日の目標を1つ達成しましょう。"
        }
        let weekday = elapsed.filter { ![1, 7].contains($0.date.weekday) }.compactMap(\.rate)
        let weekend = elapsed.filter { [1, 7].contains($0.date.weekday) }.compactMap(\.rate)
        let worst = elapsed.min { ($0.rate ?? 0) < ($1.rate ?? 0) }

        if !weekday.isEmpty, !weekend.isEmpty {
            let wd = weekday.reduce(0, +) / Double(weekday.count)
            let we = weekend.reduce(0, +) / Double(weekend.count)
            if wd - we >= 0.15 {
                return "平日の達成率が高く、土日に少し崩れています。週末は目標を1つだけに絞ると安定しそうです。"
            }
            if we - wd >= 0.15 {
                return "週末の達成率が高く、平日に崩れがちです。平日は朝のうちに1つ終わらせる流れを作ってみましょう。"
            }
        }
        if let worst, let rate = worst.rate, rate < 0.5 {
            return "\(Weekday.label(worst.date.weekday))曜日の達成率が\(Int(rate * 100))%と低めでした。その曜日だけ目標を軽くするのも手です。"
        }
        return "曜日による大きなブレはなく、安定して続けられています。この調子で報酬額の高い目標にも挑戦してみましょう。"
    }
}
