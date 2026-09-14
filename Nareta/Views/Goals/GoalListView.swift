import SwiftData
import SwiftUI

struct GoalListView: View {
    enum Section: String, CaseIterable, Identifiable {
        case today = "Today", weekly = "Weekly", anytime = "Anytime", paused = "Paused"
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query private var completions: [GoalCompletion]
    @Query(sort: \Identity.createdAt) private var identities: [Identity]

    @State private var section: Section = .today
    @State private var showSettings = false
    @State private var showNew = false
    @State private var showGraduated = false
    @State private var suggestion: GoalSuggestion?
    @State private var editingGoal: Goal?
    @State private var deletingGoal: Goal?
    @Namespace private var segment

    var body: some View {
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let identityMap = Dictionary(identities.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let items = filtered(byGoal)
        let graduatedCount = goals.filter { $0.archivedAt != nil }.count

        NavigationStack {
            List {
                header.cardRow(top: 8, bottom: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Goals").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text("小さな習慣が、なりたい自分をつくる").font(.system(size: 15)).foregroundStyle(Theme.subtext)
                }
                .cardRow(top: 4, bottom: 10)

                segmentControl.cardRow(top: 4, bottom: 10)

                if items.isEmpty {
                    emptyState.cardRow()
                }

                ForEach(items) { goal in
                    let goalCompletions = byGoal[goal.id] ?? []
                    ZStack {
                        NavigationLink(value: goal) { EmptyView() }.opacity(0)
                        GoalRow(
                            goal: goal,
                            completions: goalCompletions,
                            identity: goal.identityId.flatMap { identityMap[$0] },
                            showMeta: true,
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

                if graduatedCount > 0 {
                    Button { showGraduated = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "medal.fill")
                                .foregroundStyle(Theme.goldGradient)
                                .frame(width: 36, height: 36)
                                .background(Theme.gold.opacity(0.13), in: Circle())
                            Text("定着した習慣（\(graduatedCount)）")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.subtext)
                        }
                        .cardStyle(padding: 12)
                    }
                    .buttonStyle(.borderless)
                    .cardRow(top: 12, bottom: 5)
                }

                Color.clear.frame(height: 8).cardRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                BottomBar {
                    Button {
                        suggestion = nil
                        showNew = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                            Text("新しいゴールを作成する")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(kind: .navy))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Goal.self) { GoalDetailView(goal: $0) }
            .navigationDestination(item: $editingGoal) { GoalEditorView(goal: $0) }
            .navigationDestination(isPresented: $showNew) { GoalEditorView(goal: nil, suggestion: suggestion) }
            .navigationDestination(isPresented: $showGraduated) { GraduatedGoalsView() }
            .onChange(of: appState.pendingSuggestion, initial: true) { _, pending in
                guard let pending else { return }
                suggestion = pending
                appState.pendingSuggestion = nil
                showNew = true
            }
            .goalDeleteDialog($deletingGoal) { goal in
                RewardService(context: context).deleteGoal(goal)
                NotificationService.reschedule(context: context)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            #if DEBUG
            .onAppear {
                if UserDefaults.standard.bool(forKey: "debugNewGoal"), !showNew {
                    suggestion = GoalSuggestion(sourceTitle: "水を2L飲む", reward: 100, monthlyEstimate: 3_000, identityId: nil)
                    showNew = true
                }
            }
            #endif
        }
    }

    private var header: some View {
        HStack {
            Text("NARETA").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.ink)
            Spacer()
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

    private func filtered(_ byGoal: [UUID: [GoalCompletion]]) -> [Goal] {
        switch section {
        case .today:
            return goals.filter { GoalService.showsInToday($0, byGoal[$0.id] ?? []) }
        case .weekly:
            return goals.filter { $0.isLive && ($0.frequency == .weekly || $0.frequency == .weekdays) }
        case .anytime:
            return goals.filter { $0.isLive && ($0.frequency == .monthly || $0.frequency == .once || $0.frequency == .daily) }
        case .paused:
            return goals.filter { !$0.isActive && $0.archivedAt == nil }
        }
    }

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(Section.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { section = item }
                } label: {
                    Text(item.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(section == item ? .white : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if section == item {
                                Capsule().fill(Theme.navy).matchedGeometryEffect(id: "seg", in: segment)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(4)
        .background(Theme.chip, in: Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: section == .paused ? "pause.circle" : "target")
                .font(.system(size: 34))
                .foregroundStyle(Theme.subtext)
            Text(section == .paused ? "一時停止中の目標はありません" : "目標はまだありません")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(section == .paused ? "目標を左にスワイプすると一時停止できます。" : "下のボタンから、なりたい自分につながる目標を作りましょう。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.subtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 28)
    }
}
