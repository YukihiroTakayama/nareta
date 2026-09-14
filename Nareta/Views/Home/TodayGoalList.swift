import SwiftUI

struct TodayHeader: View {
    let goals: [Goal]
    let byGoal: [UUID: [GoalCompletion]]

    var body: some View {
        let remaining = goals.filter { GoalService.canComplete($0, byGoal[$0.id] ?? []) }
        let remainingAmount = remaining.reduce(0) { $0 + $1.rewardAmount }

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
    }
}

struct TodayEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "target").font(.system(size: 30)).foregroundStyle(Theme.subtext)
            Text("今日の目標はありません").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
            Text("目標を作ると、達成するたびにお金が解放されます。")
                .font(.system(size: 13)).foregroundStyle(Theme.subtext)
            Button("目標を作る", action: onCreate)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.blue)
                .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }
}
