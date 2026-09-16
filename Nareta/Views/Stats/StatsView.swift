import SwiftData
import SwiftUI

struct StatsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query private var completions: [GoalCompletion]
    @Query(sort: \Identity.createdAt) private var identities: [Identity]
    @Query private var transactions: [RewardTransaction]
    @Query private var pools: [MonthlyRewardPool]

    @Environment(AppState.self) private var appState
    @State private var showSettings = false
    @State private var showWeekly = false
    @State private var exportURL: URL?

    var body: some View {
        let now = Date()
        let monthStart = now.startOfMonth
        let tomorrow = now.startOfDay.adding(days: 1)
        let monthCompletions = completions.filter { $0.completedAt >= monthStart }
        let monthTx = transactions.filter { $0.createdAt >= monthStart }
        let earned = monthTx.filter { $0.typeValue == .earn }.reduce(0) { $0 + $1.amount }
        let spent = -monthTx.filter { $0.typeValue == .spend }.reduce(0) { $0 + $1.amount }
        let rate = GoalService.achievementRate(goals: goals, completions: completions, from: monthStart, to: tomorrow)
        let weekRate = GoalService.achievementRate(goals: goals, completions: completions, from: now.startOfWeek, to: tomorrow)
        let adjustments = DifficultyService.suggestions(goals: goals, completions: completions)
            .filter { !DifficultyService.isDismissed($0.goal) }.count

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("Me").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.ink)
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 42, height: 42)
                                .background(Theme.chip, in: Circle())
                        }
                    }
                    .padding(.top, 8)

                    HeroCard(showTagline: false) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white.opacity(0.85))
                                .frame(width: 76, height: 76)
                                .background(Circle().fill(.white.opacity(0.12)))
                                .overlay(Circle().stroke(.white.opacity(0.2)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("My Progress").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                                Text("より良い毎日を、つみあげる").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                        }
                    }

                    HStack(spacing: 0) {
                        stat(icon: "checkmark.circle", label: "達成数", value: "\(monthCompletions.count)")
                        divider
                        stat(icon: "chart.bar.fill", label: "達成率", value: "\(Int((rate * 100).rounded()))%")
                        divider
                        stat(icon: "cylinder.split.1x2", label: "獲得", value: earned.yen)
                        divider
                        stat(icon: "wallet.bifold", label: "使用", value: spent.yen)
                        divider
                        stat(icon: "flame.fill", label: "Longest", value: "\(GoalService.longestDayStreak(completions))日")
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 4)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))

                    ContinuityCard(goals: goals, completions: completions)

                    NavigationLink {
                        WeeklyReviewView()
                    } label: {
                        HStack(spacing: 14) {
                            IconBadge(systemName: "calendar.badge.checkmark", color: .white, background: Theme.blue, size: 46)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("今週のふりかえり").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                                Text(adjustments > 0
    ? "今週の達成率 \(Int((weekRate * 100).rounded()))% · 調整案 \(adjustments)件"
    : "今週の達成率 \(Int((weekRate * 100).rounded()))%").font(.system(size: 13)).foregroundStyle(Theme.subtext)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.subtext)
                        }
                        .cardStyle(padding: 14)
                    }
                    .buttonStyle(.plain)

                    identityProgress

                    graduatedSection

                    VStack(spacing: 0) {
                        NavigationLink { HistoryView() } label: {
                            menuRow(icon: "clock.arrow.circlepath", title: "History", subtitle: "獲得・使用の履歴")
                        }
                        Divider().padding(.leading, 70)
                        Button { showSettings = true } label: {
                            menuRow(icon: "cylinder.split.1x2", title: "Reward Pool", subtitle: "今月の金額・繰越の設定")
                        }
                        Divider().padding(.leading, 70)
                        Button { showSettings = true } label: {
                            menuRow(icon: "bell.fill", title: "Notifications", subtitle: "リマインダー・お知らせの設定")
                        }
                        Divider().padding(.leading, 70)
                        if let exportURL {
                            ShareLink(item: exportURL) {
                                menuRow(icon: "square.and.arrow.down", title: "Export Data", subtitle: "データの書き出し（JSON）")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Goal.self) { GoalDetailView(goal: $0) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(isPresented: $showWeekly) { WeeklyReviewView() }
            .onChange(of: appState.pendingRoute, initial: true) { _, route in
                guard route == .weeklyReview else { return }
                appState.pendingRoute = nil
                showWeekly = true
            }
            .onAppear { exportURL = DataService.exportJSON(context: context) }
        }
    }

    private var identityProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Identity Progress").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                Text("なりたい自分に、少しずつ近づく（過去30日）").font(.system(size: 13)).foregroundStyle(Theme.subtext)
            }
            if identities.isEmpty {
                Text("設定から「なりたい自分」を追加しましょう。").font(.system(size: 14)).foregroundStyle(Theme.subtext)
            }
            ForEach(identities) { identity in
                let score = GoalService.identityScore(identity: identity, goals: goals, completions: completions)
                let color = Color(hexString: identity.colorHex)
                HStack(spacing: 14) {
                    Image(systemName: identity.icon ?? IdentityPreset.customIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 44, height: 44)
                        .background(color.opacity(0.13), in: Circle())
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(identity.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                            let graduatedCount = goals.filter { $0.identityId == identity.id && $0.archivedAt != nil }.count
                            if graduatedCount > 0 {
                                Label("卒業 \(graduatedCount)", systemImage: "medal.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.goldDeep)
                            }
                        }
                        LinearBar(progress: score, color: color, height: 9)
                    }
                    Text("\(Int((score * 100).rounded()))%")
                        .font(.system(size: 17, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
                .padding(12)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .cardStyle()
    }

    private var graduatedSection: some View {
        let graduated = goals
            .filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("定着した習慣").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("考えなくてもできるようになった、なりたい自分の証拠").font(.system(size: 13)).foregroundStyle(Theme.subtext)
                }
                Spacer()
                if !graduated.isEmpty {
                    NavigationLink { GraduatedGoalsView() } label: {
                        HStack(spacing: 4) {
                            Text("すべて見る")
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.subtext)
                    }
                }
            }
            if graduated.isEmpty {
                Text("66日つづけて、考えなくてもできるようになった目標は、ここに卒業します。")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.subtext)
            } else {
                ForEach(graduated.prefix(3)) { goal in
                    NavigationLink(value: goal) {
                        GraduatedGoalRow(
                            goal: goal,
                            identity: identities.first { $0.id == goal.identityId },
                            completionCount: completions.filter { $0.goalId == goal.id }.count
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(width: 1, height: 56)
    }

    private func stat(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Theme.ink.opacity(0.7))
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.subtext).lineLimit(1)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
    }

    private func menuRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemName: icon, color: Theme.ink, background: Theme.chip, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.subtext)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.subtext)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
