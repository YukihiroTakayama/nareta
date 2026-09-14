import SwiftData
import SwiftUI

@main
struct NaretaApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [
            Identity.self,
            Goal.self,
            GoalCompletion.self,
            MonthlyRewardPool.self,
            Reward.self,
            RewardTransaction.self,
        ])
    }
}
