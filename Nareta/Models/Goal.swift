import Foundation
import SwiftData

enum FrequencyType: String, CaseIterable, Identifiable {
    case daily, weekdays, weekly, monthly, once
    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: "毎日"
        case .weekdays: "曜日指定"
        case .weekly: "週N回"
        case .monthly: "月N回"
        case .once: "1回のみ"
        }
    }
}

enum AlertStyle: String, CaseIterable, Identifiable {
    case alarm, notification, none
    var id: String { rawValue }

    var label: String {
        switch self {
        case .alarm: "アラーム"
        case .notification: "通知"
        case .none: "なし"
        }
    }

    var icon: String {
        switch self {
        case .alarm: "alarm.fill"
        case .notification: "bell.fill"
        case .none: "clock"
        }
    }
}

enum VerificationType: String, CaseIterable, Identifiable {
    case manual, healthKit, location, timer
    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: "手動"
        case .healthKit: "HealthKit"
        case .location: "Location"
        case .timer: "Timer"
        }
    }

    var caption: String {
        switch self {
        case .manual: "自分で記録"
        case .healthKit: "ヘルスケア連携"
        case .location: "位置情報で判定"
        case .timer: "時間で判定"
        }
    }

    var icon: String {
        switch self {
        case .manual: "checkmark.circle.fill"
        case .healthKit: "heart.fill"
        case .location: "mappin.circle.fill"
        case .timer: "timer"
        }
    }

    /// MVPでは手動のみ
    var isAvailable: Bool { self == .manual }
}

@Model
final class Goal {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var rewardAmount: Int = 100
    var frequencyType: String = FrequencyType.daily.rawValue
    var targetCount: Int = 1
    /// Calendar.weekday (1 = 日 ... 7 = 土)
    var weekdays: [Int] = []
    var durationMinutes: Int = 0
    var identityId: UUID?
    var isActive: Bool = true
    var verificationType: String = VerificationType.manual.rawValue
    var createdAt: Date = Date()
    /// If-Then計画の「If」: 時刻（0時からの分、-1 = なし）
    var triggerMinutes: Int = -1
    /// If-Then計画の「If」: ルーティン（設定時は triggerMinutes より優先）
    var routineId: UUID?
    /// ルーティンからのずれ（分）
    var triggerOffset: Int = 0
    var alertStyle: String = AlertStyle.alarm.rawValue
    /// WOOP: Outcome / Obstacle / Plan
    var wishOutcome: String = ""
    var obstacle: String = ""
    var obstaclePlan: String = ""
    /// 定着して卒業した日時（nil = 現役）
    var archivedAt: Date?

    init(
        title: String,
        note: String = "",
        rewardAmount: Int,
        frequency: FrequencyType = .daily,
        targetCount: Int = 1,
        weekdays: [Int] = [],
        durationMinutes: Int = 0,
        identityId: UUID? = nil,
        verification: VerificationType = .manual,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.rewardAmount = rewardAmount
        self.frequencyType = frequency.rawValue
        self.targetCount = targetCount
        self.weekdays = weekdays
        self.durationMinutes = durationMinutes
        self.identityId = identityId
        self.verificationType = verification.rawValue
        self.createdAt = createdAt
    }

    /// 一時停止でも卒業済みでもない
    var isLive: Bool { isActive && archivedAt == nil }
    var hasTrigger: Bool { routineId != nil || triggerMinutes >= 0 }
    var hasPlan: Bool { hasTrigger || !wishOutcome.isEmpty || !obstacle.isEmpty || !obstaclePlan.isEmpty }
    var alertStyleValue: AlertStyle { AlertStyle(rawValue: alertStyle) ?? .alarm }

    var frequency: FrequencyType { FrequencyType(rawValue: frequencyType) ?? .daily }
    var verification: VerificationType { VerificationType(rawValue: verificationType) ?? .manual }

    var frequencyLabel: String {
        switch frequency {
        case .daily: return "毎日"
        case .weekdays:
            let days = Weekday.mondayFirst.filter { weekdays.contains($0) }.map(Weekday.label)
            return days.isEmpty ? "曜日指定" : days.joined(separator: "・")
        case .weekly: return "週\(targetCount)回"
        case .monthly: return "月\(targetCount)回"
        case .once: return "1回のみ"
        }
    }
}
