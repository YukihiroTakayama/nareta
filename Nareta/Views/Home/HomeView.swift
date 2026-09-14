import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query private var completions: [GoalCompletion]
    @Query private var pools: [MonthlyRewardPool]
    @Query(sort: \Identity.createdAt) private var identities: [Identity]
    @Query(HomeView.pendingRewards) private var rewards: [Reward]

    private static var pendingRewards: FetchDescriptor<Reward> {
        let predicate = #Predicate<Reward> { reward in reward.isPurchased == false }
        let sort: [SortDescriptor<Reward>] = [SortDescriptor(\Reward.priority), SortDescriptor(\Reward.price)]
        return FetchDescriptor<Reward>(predicate: predicate, sortBy: sort)
    }

    @State private var showSettings = false
    @State private var showHistory = false

    private var now: Date { .now }
    private var pool: MonthlyRewardPool? { pools.first { $0.year == now.year && $0.month == now.month } }
    private var byGoal: [UUID: [GoalCompletion]] { Dictionary(grouping: completions, by: \.goalId) }
    private var identityMap: [UUID: Identity] { Dictionary(identities.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a }) }

    var body: some View {
        let byGoal = byGoal
        let todayGoals = goals.filter { GoalService.showsInToday($0, byGoal[$0.id] ?? []) }
        let todayCompletions = completions.filter { $0.completedAt.isSameDay(as: now) }

        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    RewardBalanceCard(pool: pool, streak: GoalService.dayStreak(completions))

                    TodayGoalList(
                        goals: todayGoals,
                        byGoal: byGoal,
                        identities: identityMap,
                        onComplete: { appState.complete($0, context: context) },
                        onCreate: { appState.selectedTab = .goals }
                    )

                    if let next = rewards.first {
                        NextRewardCard(reward: next, available: pool?.availableAmount ?? 0) {
                            appState.selectedTab = .rewards
                        }
                    }

                    todayUnlockedRow(todayCompletions)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 80)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Goal.self) { GoalDetailView(goal: $0) }
            .navigationDestination(for: Reward.self) { RewardDetailView(reward: $0) }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showHistory) { NavigationStack { HistoryView(showsCloseButton: true) } }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("NARETA")
                .font(.system(size: 30, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(Theme.ink)
            Spacer()
            Button { showHistory = true } label: {
                HStack(spacing: 6) {
                    Text("\(now.month)月").font(.system(size: 16, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(Theme.line))
            }
            Button { showSettings = true } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.chip, in: Circle())
            }
        }
        .padding(.top, 8)
    }

    private func todayUnlockedRow(_ todays: [GoalCompletion]) -> some View {
        let sum = todays.reduce(0) { $0 + $1.rewardAmount }
        return NavigationLink {
            HistoryView()
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemName: "chart.bar.fill", color: Theme.ink, background: Theme.chip, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("本日の解放額").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                    Text("\(todays.count)つのタスクを達成").font(.system(size: 13)).foregroundStyle(Theme.subtext)
                }
                Spacer()
                Text(sum.signedYen)
                    .font(.system(size: 24, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.green)
                    .contentTransition(.numericText(value: Double(sum)))
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.subtext)
            }
            .cardStyle(padding: 14)
        }
        .buttonStyle(.plain)
    }
}
