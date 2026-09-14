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
        .modelContainer(AppModel.container)
    }
}
