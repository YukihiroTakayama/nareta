import Foundation
import SwiftData

/// 自動化度チェック（Self-Report Behavioural Automaticity Index, Gardner et al., 2012 をもとにした4問・7段階）
@Model
final class AutomaticityCheck {
    var id: UUID = UUID()
    var goalId: UUID = UUID()
    var checkedAt: Date = Date()
    var scores: [Int] = []

    init(goalId: UUID, scores: [Int], checkedAt: Date = .now) {
        self.id = UUID()
        self.goalId = goalId
        self.scores = scores
        self.checkedAt = checkedAt
    }

    var average: Double {
        scores.isEmpty ? 0 : Double(scores.reduce(0, +)) / Double(scores.count)
    }

    static let questions = [
        "意識しなくても、自然にやっている",
        "「やらなきゃ」と思い出さなくてもやっている",
        "特に考えずにやっている",
        "気づいたら、もうやり始めている",
    ]
}

/// 実施日を逃した日の連続記録を守る（月2回まで）
@Model
final class StreakFreeze {
    var id: UUID = UUID()
    var goalId: UUID = UUID()
    /// 守った日（startOfDay）
    var date: Date = Date()
    var createdAt: Date = Date()

    init(goalId: UUID, date: Date, createdAt: Date = .now) {
        self.id = UUID()
        self.goalId = goalId
        self.date = date.startOfDay
        self.createdAt = createdAt
    }
}
