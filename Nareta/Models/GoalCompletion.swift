import Foundation
import SwiftData

@Model
final class GoalCompletion {
    var id: UUID = UUID()
    var goalId: UUID = UUID()
    var completedAt: Date = Date()
    /// 実際に解放された金額（Pool上限で減額されることがある）
    var rewardAmount: Int = 0
    /// rewardAmount のうち復帰ボーナス分
    var bonusAmount: Int = 0
    /// 報酬を入れた月（記録し忘れを後日入れた場合は記録した月）。0 = completedAt の月
    var creditedYear: Int = 0
    var creditedMonth: Int = 0
    /// 後日まとめて入れた記録
    var isBackfilled: Bool = false

    init(goalId: UUID, completedAt: Date = .now, rewardAmount: Int) {
        self.id = UUID()
        self.goalId = goalId
        self.completedAt = completedAt
        self.rewardAmount = rewardAmount
    }
}
