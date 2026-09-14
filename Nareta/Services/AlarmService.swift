import AppIntents
import Foundation
import SwiftData
import SwiftUI
#if canImport(AlarmKit)
import AlarmKit
#endif

enum AlarmAuthorization {
    case unsupported, notDetermined, denied, authorized
}

/// If-Thenの時刻にAlarmKitで鳴らす（マナーモード・集中モードでも鳴る）。
/// iOS 26未満や未許可のときは NotificationService が通知で代替する。
@MainActor
enum AlarmService {
    static let maxAlarms = 60
    private static var pending: Task<Void, Never>?

    static var isSupported: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    static var authorization: AlarmAuthorization {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return .unsupported }
        switch AlarmManager.shared.authorizationState {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
        #else
        return .unsupported
        #endif
    }

    static func requestAuthorization() async {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *), authorization == .notDetermined else { return }
        _ = try? await AlarmManager.shared.requestAuthorization()
        #endif
    }

    /// 予約済みのアラームを消して、今後14日分を入れ直す（前回の処理が終わってから順番に実行）
    @discardableResult
    static func reschedule(context: ModelContext) -> Task<Void, Never> {
        let previous = pending
        let task = Task { @MainActor in
            await previous?.value
            await performReschedule(context: context)
        }
        pending = task
        return task
    }

    private static func performReschedule(context: ModelContext) async {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return }
        let manager = AlarmManager.shared
        for alarm in (try? manager.alarms) ?? [] where alarm.state == .scheduled {
            try? manager.cancel(id: alarm.id)
        }
        guard authorization == .authorized, NotificationService.enabled else { return }

        let goals = (try? context.fetch(FetchDescriptor<Goal>())) ?? []
        let completions = (try? context.fetch(FetchDescriptor<GoalCompletion>())) ?? []
        let routines = (try? context.fetch(FetchDescriptor<RoutineAnchor>())) ?? []
        let byGoal = Dictionary(grouping: completions, by: \.goalId)

        var planned: [(date: Date, goal: Goal)] = []
        for goal in goals where goal.alertStyleValue == .alarm {
            guard let minutes = TriggerService.minutes(for: goal, routines: routines) else { continue }
            planned += TriggerService.fireDates(
                for: goal, minutes: minutes, completions: byGoal[goal.id] ?? [], days: NotificationService.horizonDays
            ).map { ($0, goal) }
        }
        for item in planned.sorted(by: { $0.date < $1.date }).prefix(maxAlarms) {
            await schedule(goal: item.goal, at: item.date)
        }
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func schedule(goal: Goal, at date: Date) async {
        let title = LocalizedStringResource(stringLiteral: "\(goal.title)の時間です（達成で\(goal.rewardAmount.signedYen)）")
        let done = AlarmButton(text: "達成した", textColor: .white, systemImageName: "checkmark.circle.fill")
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: title, secondaryButton: done, secondaryButtonBehavior: .custom)
        } else {
            let stop = AlarmButton(text: "止める", textColor: .white, systemImageName: "stop.fill")
            alert = AlarmPresentation.Alert(title: title, stopButton: stop, secondaryButton: done, secondaryButtonBehavior: .custom)
        }
        let attributes = AlarmAttributes<GoalAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: GoalAlarmMetadata(goalId: goal.id),
            tintColor: Theme.gold
        )
        let configuration = AlarmManager.AlarmConfiguration<GoalAlarmMetadata>.alarm(
            schedule: .fixed(date),
            attributes: attributes,
            secondaryIntent: CompleteGoalIntent(goalId: goal.id)
        )
        _ = try? await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
    }
    #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct GoalAlarmMetadata: AlarmMetadata {
    var goalId: UUID
}
#endif

/// アラームの「達成した」ボタン: アプリを開かずにそのまま達成を記録する
struct CompleteGoalIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "目標を達成する"
    static var openAppWhenRun = false

    @Parameter(title: "目標ID")
    var goalId: String

    init() {}

    init(goalId: UUID) {
        self.goalId = goalId.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = AppModel.container.mainContext
        if let id = UUID(uuidString: goalId),
           let goal = try? context.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.id == id })).first,
           RewardService(context: context).completeGoal(goal) != nil {
            NotificationService.reschedule(context: context)
        }
        return .result()
    }
}
