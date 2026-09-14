import SwiftData
import SwiftUI

struct GraduatedGoalRow: View {
    let goal: Goal
    let identity: Identity?
    let completionCount: Int
    var filled = false

    var body: some View {
        let days = goal.archivedAt.map { HabitService.days(since: goal, until: $0) } ?? 0

        HStack(spacing: 12) {
            Image(systemName: "medal.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.goldGradient)
                .frame(width: 42, height: 42)
                .background(Theme.gold.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let identity { TagChip(identity: identity) }
                    Text("\(days)日で卒業 · \(completionCount)回")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtext)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.subtext)
        }
        .padding(12)
        .background(filled ? Color.white : Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if filled {
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line)
            }
        }
    }
}

struct GraduatedGoalsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @Query private var completions: [GoalCompletion]
    @Query private var identities: [Identity]
    @State private var deletingGoal: Goal?

    var body: some View {
        let graduated = goals
            .filter { $0.archivedAt != nil }
            .sorted { ($0.archivedAt ?? .distantPast) > ($1.archivedAt ?? .distantPast) }

        List {
            Text("66日以上つづき、考えなくてもできるようになった習慣です。なりたい自分に近づいた証拠として残ります。左にスワイプすると習慣に戻せます。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.subtext)
                .cardRow(top: 8, bottom: 10)

            if graduated.isEmpty {
                Text("まだ卒業した習慣はありません")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .cardStyle(padding: 28)
                    .cardRow()
            }

            ForEach(graduated) { goal in
                ZStack {
                    NavigationLink(value: goal) { EmptyView() }.opacity(0)
                    GraduatedGoalRow(
                        goal: goal,
                        identity: identities.first { $0.id == goal.identityId },
                        completionCount: completions.filter { $0.goalId == goal.id }.count,
                        filled: true
                    )
                }
                .cardRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { deletingGoal = goal } label: { Label("削除", systemImage: "trash") }
                        .tint(Theme.red)
                    Button { restore(goal) } label: { Label("戻す", systemImage: "arrow.uturn.backward") }
                        .tint(Theme.gold)
                }
                .contextMenu {
                    Button("習慣に戻す", systemImage: "arrow.uturn.backward") { restore(goal) }
                    Divider()
                    Button("削除", systemImage: "trash", role: .destructive) { deletingGoal = goal }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("定着した習慣")
        .goalDeleteDialog($deletingGoal) { RewardService(context: context).deleteGoal($0) }
    }

    private func restore(_ goal: Goal) {
        RewardService(context: context).restore(goal)
        NotificationService.reschedule(context: context)
        Haptics.tap()
    }
}
