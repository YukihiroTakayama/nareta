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
    @Namespace private var segment

    var body: some View {
        let byGoal = Dictionary(grouping: completions, by: \.goalId)
        let identityMap = Dictionary(identities.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let items = filtered(byGoal)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goals").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.ink)
                        Text("小さな習慣が、なりたい自分をつくる").font(.system(size: 15)).foregroundStyle(Theme.subtext)
                    }

                    segmentControl

                    if items.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(items) { goal in
                                NavigationLink(value: goal) {
                                    GoalRow(
                                        goal: goal,
                                        completions: byGoal[goal.id] ?? [],
                                        identity: goal.identityId.flatMap { identityMap[$0] },
                                        showMeta: true,
                                        onComplete: { appState.complete(goal, context: context) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                BottomBar {
                    NavigationLink {
                        GoalEditorView(goal: nil)
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
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    private func filtered(_ byGoal: [UUID: [GoalCompletion]]) -> [Goal] {
        switch section {
        case .today:
            return goals.filter { GoalService.showsInToday($0, byGoal[$0.id] ?? []) }
        case .weekly:
            return goals.filter { $0.isActive && ($0.frequency == .weekly || $0.frequency == .weekdays) }
        case .anytime:
            return goals.filter { $0.isActive && ($0.frequency == .monthly || $0.frequency == .once || $0.frequency == .daily) }
        case .paused:
            return goals.filter { !$0.isActive }
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
                .buttonStyle(.plain)
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
            if section != .paused {
                Text("下のボタンから、なりたい自分につながる目標を作りましょう。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.subtext)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 28)
    }
}
