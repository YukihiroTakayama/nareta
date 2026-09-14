import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query private var completions: [GoalCompletion]
    @Query private var pools: [MonthlyRewardPool]
    @Query(sort: \Identity.createdAt) private var identities: [Identity]
    @Query private var routines: [RoutineAnchor]
    @Query(HomeView.pendingRewards) private var rewards: [Reward]

    private static var pendingRewards: FetchDescriptor<Reward> {
        let predicate = #Predicate<Reward> { reward in reward.isPurchased == false }
        let sort: [SortDescriptor<Reward>] = [SortDescriptor(\Reward.priority), SortDescriptor(\Reward.price)]
        return FetchDescriptor<Reward>(predicate: predicate, sortBy: sort)
    }

    @State private var path = NavigationPath()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showHistoryPush = false
    @State private var editingGoal: Goal?
    @State private var deletingGoal: Goal?
    @State private var didOpenDebugGoal = false

    var body: some View {
        let now = Date()
        let pool = pools.first { $0.year == now.year && $0.month == now.month }
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let identityMap = Dictionary(identities.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let todayGoals = goals.filter { GoalService.showsInToday($0, byGoal[$0.id] ?? []) }
        let todayCompletions = completions.filter { $0.completedAt.isSameDay(as: now) }

        NavigationStack(path: $path) {
            List {
                header(month: now.month).cardRow(top: 8, bottom: 6)

                RewardBalanceCard(pool: pool, streak: GoalService.dayStreak(completions))
                    .cardRow(top: 10, bottom: 14)

                TodayHeader(goals: todayGoals, byGoal: byGoal)
                    .cardRow(top: 10, bottom: 4)

                if todayGoals.isEmpty {
                    TodayEmptyState { appState.selectedTab = .goals }
                        .cardRow()
                }

                ForEach(todayGoals) { goal in
                    let goalCompletions = byGoal[goal.id] ?? []
                    ZStack {
                        NavigationLink(value: goal) { EmptyView() }.opacity(0)
                        GoalRow(
                            goal: goal,
                            completions: goalCompletions,
                            identity: goal.identityId.flatMap { identityMap[$0] },
                            triggerLabel: TriggerService.label(for: goal, routines: routines),
                            onComplete: { appState.complete(goal, context: context) }
                        )
                    }
                    .cardRow()
                    .modifier(GoalRowActions(
                        goal: goal,
                        canComplete: GoalService.canComplete(goal, goalCompletions),
                        onComplete: { appState.complete(goal, context: context) },
                        onEdit: { editingGoal = goal },
                        onTogglePause: {
                            RewardService(context: context).togglePause(goal)
                            NotificationService.reschedule(context: context)
                        },
                        onDelete: { deletingGoal = goal }
                    ))
                }

                if let next = rewards.first {
                    NextRewardCard(
                        reward: next,
                        available: pool?.availableAmount ?? 0,
                        onSeeAll: { appState.selectedTab = .rewards },
                        onOpen: { path.append(next) }
                    )
                    .cardRow(top: 14, bottom: 6)
                }

                todayUnlockedRow(todayCompletions)
                    .cardRow(top: 6, bottom: 24)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Goal.self) { GoalDetailView(goal: $0) }
            .navigationDestination(for: Reward.self) { RewardDetailView(reward: $0) }
            .navigationDestination(item: $editingGoal) { GoalEditorView(goal: $0) }
            .navigationDestination(isPresented: $showHistoryPush) { HistoryView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showHistory) { NavigationStack { HistoryView(showsCloseButton: true) } }
            .goalDeleteDialog($deletingGoal) { goal in
                RewardService(context: context).deleteGoal(goal)
                NotificationService.reschedule(context: context)
            }
            #if DEBUG
            .onChange(of: goals.count, initial: true) { _, _ in
                guard !didOpenDebugGoal, let title = UserDefaults.standard.string(forKey: "debugGoal"),
                      let goal = goals.first(where: { $0.title == title }) else { return }
                didOpenDebugGoal = true
                path.append(goal)
            }
            #endif
        }
    }

    private func header(month: Int) -> some View {
        HStack(spacing: 10) {
            Text("NARETA")
                .font(.system(size: 30, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(Theme.ink)
            Spacer()
            Button { showHistory = true } label: {
                HStack(spacing: 6) {
                    Text("\(month)月").font(.system(size: 16, weight: .semibold))
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(Theme.line))
            }
            .buttonStyle(.borderless)
            Button { showSettings = true } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 42, height: 42)
                    .background(Theme.chip, in: Circle())
            }
            .buttonStyle(.borderless)
        }
    }

    private func todayUnlockedRow(_ todays: [GoalCompletion]) -> some View {
        let sum = todays.reduce(0) { $0 + $1.rewardAmount }
        return Button { showHistoryPush = true } label: {
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
        .buttonStyle(.borderless)
    }
}
