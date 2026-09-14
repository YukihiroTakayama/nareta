import Foundation
import SwiftData

enum TransactionType: String, CaseIterable {
    case earn, spend, adjustment
}

@Model
final class RewardTransaction {
    var id: UUID = UUID()
    var type: String = TransactionType.earn.rawValue
    /// earn は正、spend は負
    var amount: Int = 0
    var title: String = ""
    /// earn: GoalCompletion.id / spend: Reward.id
    var sourceId: UUID?
    var createdAt: Date = Date()

    init(type: TransactionType, amount: Int, title: String, sourceId: UUID? = nil, createdAt: Date = .now) {
        self.id = UUID()
        self.type = type.rawValue
        self.amount = amount
        self.title = title
        self.sourceId = sourceId
        self.createdAt = createdAt
    }

    var typeValue: TransactionType { TransactionType(rawValue: type) ?? .adjustment }
}
