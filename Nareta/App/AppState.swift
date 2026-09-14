import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case home, goals, rewards, me
}

/// 卒業した目標の報酬を次の目標に回す提案
struct GoalSuggestion: Identifiable, Equatable {
    let id = UUID()
    let sourceTitle: String
    let reward: Int
    let monthlyEstimate: Int
    let identityId: UUID?
}

@Observable
@MainActor
final class AppState {
    var selectedTab: AppTab = .home
    var celebration: CompletionResult?
    var undoItem: CompletionResult?
    var pendingSuggestion: GoalSuggestion?
    private var undoTask: Task<Void, Never>?

    func suggestNextGoal(after goal: Goal) {
        let suggestion = GoalSuggestion(
            sourceTitle: goal.title,
            reward: goal.rewardAmount,
            monthlyEstimate: HabitService.monthlyRewardEstimate(goal),
            identityId: goal.identityId
        )
        selectedTab = .goals
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            pendingSuggestion = suggestion
        }
    }

    func complete(_ goal: Goal, context: ModelContext) {
        guard let result = RewardService(context: context).completeGoal(goal) else { return }
        Haptics.success()
        withAnimation(.easeOut(duration: 0.2)) { celebration = result }
        NotificationService.reschedule(context: context)
    }

    func finishCelebration() {
        guard let result = celebration else { return }
        withAnimation(.easeOut(duration: 0.25)) { celebration = nil }
        showUndo(result)
    }

    private func showUndo(_ result: CompletionResult) {
        undoTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { undoItem = result }
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut) { self?.undoItem = nil }
        }
    }

    func undo(context: ModelContext) {
        guard let item = undoItem else { return }
        undoTask?.cancel()
        RewardService(context: context).undoCompletion(id: item.completionId)
        Haptics.tap()
        withAnimation(.easeOut) { undoItem = nil }
        NotificationService.reschedule(context: context)
    }
}
