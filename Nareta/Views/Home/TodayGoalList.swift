import SwiftUI

struct TodayGoalList: View {
    let goals: [Goal]
    let byGoal: [UUID: [GoalCompletion]]
    let identities: [UUID: Identity]
    let onComplete: (Goal) -> Void
    let onCreate: () -> Void

    private var remaining: [Goal] { goals.filter { GoalService.canComplete($0, byGoal[$0.id] ?? []) } }

    var body: some View {
        let remaining = remaining
        let remainingAmount = remaining.reduce(0) { $0 + $1.rewardAmount }

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("TODAY")
                    .font(.system(size: 16, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if goals.isEmpty {
                    EmptyView()
                } else if remainingAmount > 0 {
                    Text("あと\(remaining.count)つで \(Text(remainingAmount.signedYen).foregroundStyle(Theme.goldDeep).fontWeight(.bold)) 解放")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.subtext)
                        .monospacedDigit()
                } else {
                    Label("今日はすべて達成", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.green)
                }
            }
            .padding(.horizontal, 4)

            if goals.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "target").font(.system(size: 30)).foregroundStyle(Theme.subtext)
                    Text("今日の目標はありません").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("目標を作ると、達成するたびにお金が解放されます。")
                        .font(.system(size: 13)).foregroundStyle(Theme.subtext)
                    Button("目標を作る", action: onCreate)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.blue)
                }
                .frame(maxWidth: .infinity)
                .cardStyle(padding: 24)
            } else {
                VStack(spacing: 10) {
                    ForEach(goals) { goal in
                        NavigationLink(value: goal) {
                            GoalRow(
                                goal: goal,
                                completions: byGoal[goal.id] ?? [],
                                identity: goal.identityId.flatMap { identities[$0] },
                                onComplete: { onComplete(goal) }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
