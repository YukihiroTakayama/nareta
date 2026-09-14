import SwiftData
import SwiftUI

@main
struct NaretaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
        .modelContainer(AppModel.container)
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            let alarmTask = await MainActor.run {
                NotificationService.reschedule(context: AppModel.container.mainContext)
            }
            await alarmTask.value
        }
    }
}
