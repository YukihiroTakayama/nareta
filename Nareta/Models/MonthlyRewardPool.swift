import Foundation
import SwiftData

@Model
final class MonthlyRewardPool {
    var id: UUID = UUID()
    var year: Int = 0
    var month: Int = 0
    var totalAmount: Int = 0
    var unlockedAmount: Int = 0
    var spentAmount: Int = 0
    /// 前月から繰り越した未使用額
    var carriedOverAmount: Int = 0

    init(year: Int, month: Int, totalAmount: Int, carriedOverAmount: Int = 0) {
        self.id = UUID()
        self.year = year
        self.month = month
        self.totalAmount = totalAmount
        self.carriedOverAmount = carriedOverAmount
    }

    /// 今月使っていいお金
    var availableAmount: Int { carriedOverAmount + unlockedAmount - spentAmount }
    /// 未解放
    var lockedAmount: Int { max(0, totalAmount - unlockedAmount) }
    var remainingCapacity: Int { max(0, totalAmount - unlockedAmount) }

    var progress: Double {
        guard totalAmount > 0 else { return 0 }
        return min(1, Double(unlockedAmount) / Double(totalAmount))
    }
}
