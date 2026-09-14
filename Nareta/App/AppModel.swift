import SwiftData

/// アプリ本体とApp Intents（アラームの「達成した」）で同じストアを使う
enum AppModel {
    static let container: ModelContainer = {
        let schema = Schema([
            Identity.self,
            Goal.self,
            GoalCompletion.self,
            MonthlyRewardPool.self,
            Reward.self,
            RewardTransaction.self,
            AutomaticityCheck.self,
            StreakFreeze.self,
            RoutineAnchor.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("ModelContainer の作成に失敗しました: \(error)")
        }
    }()
}
