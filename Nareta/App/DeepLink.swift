import SwiftUI
import UIKit
import UserNotifications

/// 通知・ウィジェットから開く画面
enum AppRoute: Equatable {
    case home
    case weeklyReview
    case goal(UUID)

    var userInfo: [String: String] {
        switch self {
        case .home: ["route": "home"]
        case .weeklyReview: ["route": "weekly"]
        case .goal(let id): ["route": "goal", "goalId": id.uuidString]
        }
    }

    init?(userInfo: [AnyHashable: Any]) {
        switch userInfo["route"] as? String {
        case "home":
            self = .home
        case "weekly":
            self = .weeklyReview
        case "goal":
            guard let value = userInfo["goalId"] as? String, let id = UUID(uuidString: value) else { return nil }
            self = .goal(id)
        default:
            return nil
        }
    }

    /// nareta://home ・ nareta://weekly ・ nareta://goal/<id>
    init?(url: URL) {
        guard url.scheme == "nareta" else { return nil }
        switch url.host {
        case "home":
            self = .home
        case "weekly":
            self = .weeklyReview
        case "goal":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .goal(id)
        default:
            return nil
        }
    }
}

/// 通知のタップを受け取り、画面が用意できていれば即座に、まだなら表示後に遷移させる
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    @MainActor var handler: ((AppRoute) -> Void)?
    @MainActor var pending: AppRoute?

    @MainActor
    func deliver(_ route: AppRoute) {
        if let handler {
            handler(route)
        } else {
            pending = route
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let route = AppRoute(userInfo: response.notification.request.content.userInfo)
        Task { @MainActor in
            if let route { self.deliver(route) }
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        return true
    }
}
