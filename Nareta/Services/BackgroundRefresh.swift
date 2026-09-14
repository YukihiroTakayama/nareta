import BackgroundTasks
import Foundation

/// 1日1回、裏で通知・アラーム・ウィジェットを更新する（実行タイミングはiOS任せ）
enum BackgroundRefresh {
    static let identifier = "app.nareta.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Calendar.nareta.date(bySettingHour: 4, minute: 0, second: 0, of: Date().adding(days: 1))
        try? BGTaskScheduler.shared.submit(request)
    }
}
