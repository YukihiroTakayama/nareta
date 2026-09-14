import Foundation
import SwiftData

@Model
final class GoalCompletion {
    var id: UUID = UUID()
    var goalId: UUID = UUID()
    var completedAt: Date = Date()
    /// 実際に解放された金額（Pool上限で減額されることがある）
    var rewardAmount: Int = 0

    init(goalId: UUID, completedAt: Date = .now, rewardAmount: Int) {
        self.id = UUID()
        self.goalId = goalId
        self.completedAt = completedAt
        self.rewardAmount = rewardAmount
    }
}
