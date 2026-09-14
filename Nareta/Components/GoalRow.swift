import SwiftUI

struct GoalRow: View {
    let goal: Goal
    let completions: [GoalCompletion]
    var identity: Identity?
    var showMeta = false
    var triggerLabel: String?
    let onComplete: () -> Void

    private var completedToday: Bool { GoalService.isCompletedToday(completions) }
    private var periodDone: Bool { GoalService.isPeriodDone(goal, completions) }
    private var done: Bool { completedToday || (goal.frequency != .daily && goal.frequency != .weekdays && periodDone) }
    private var canComplete: Bool { GoalService.canComplete(goal, completions) }
    private var isCountGoal: Bool { goal.frequency == .weekly || goal.frequency == .monthly }

    var body: some View {
        HStack(spacing: 14) {
            Button {
                onComplete()
            } label: {
                CheckCircle(done: done, size: 34)
                    .opacity(goal.isActive ? 1 : 0.4)
                    .padding(4)
            }
            .buttonStyle(.borderless)
            .allowsHitTesting(canComplete)
            .accessibilityLabel(done ? "達成済み" : "達成する")

            VStack(alignment: .leading, spacing: 5) {
                Text(goal.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)

                if showMeta {
                    HStack(spacing: 8) {
                        if let identity { TagChip(identity: identity) }
                        Text(goal.frequencyLabel).font(.system(size: 13)).foregroundStyle(Theme.subtext)
                    }
                }

                if isCountGoal {
                    let count = GoalService.periodCount(goal, completions)
                    let target = GoalService.periodTarget(goal)
                    Text("\(min(count, target)) / \(target) 回達成")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.ink.opacity(0.8))
                    LinearBar(progress: Double(count) / Double(target), color: periodDone ? Theme.green : Theme.blue, height: 6)
                        .padding(.top, 2)
                } else if let triggerLabel {
                    HStack(spacing: 5) {
                        Image(systemName: goal.alertStyleValue.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(goal.alertStyleValue == .alarm ? Theme.goldDeep : Theme.blue)
                        Text(triggerLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.subtext)
                            .lineLimit(1)
                    }
                } else if !goal.note.isEmpty {
                    Text(goal.note)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subtext)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Text(goal.rewardAmount.signedYen)
                .font(.system(size: 19, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.goldDeep)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.subtext)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .background(done ? Theme.doneBackground : .white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(done ? Theme.green.opacity(0.18) : Theme.line, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
