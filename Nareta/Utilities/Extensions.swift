import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(hexString: String?, fallback: UInt32 = 0x0A7AFF) {
        let s = (hexString ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        self.init(hex: UInt32(s, radix: 16) ?? fallback)
    }
}

extension Int {
    private static let groupingFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    var grouped: String { Self.groupingFormatter.string(from: NSNumber(value: self)) ?? "\(self)" }

    /// ¥12,400 / -¥500
    var yen: String { (self < 0 ? "-" : "") + "¥" + abs(self).grouped }

    /// +¥500 / -¥39,800
    var signedYen: String { self >= 0 ? "+" + yen : yen }
}

extension Calendar {
    /// 月曜始まりのカレンダー
    static var nareta: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ja_JP")
        c.timeZone = .current
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 1
        return c
    }
}

extension Date {
    private var cal: Calendar { .nareta }

    var startOfDay: Date { cal.startOfDay(for: self) }
    var startOfWeek: Date { cal.dateInterval(of: .weekOfYear, for: self)?.start ?? startOfDay }
    var startOfMonth: Date { cal.dateInterval(of: .month, for: self)?.start ?? startOfDay }
    var year: Int { cal.component(.year, from: self) }
    var month: Int { cal.component(.month, from: self) }
    var day: Int { cal.component(.day, from: self) }
    var weekday: Int { cal.component(.weekday, from: self) }

    func adding(days: Int) -> Date { cal.date(byAdding: .day, value: days, to: self) ?? self }
    func adding(months: Int) -> Date { cal.date(byAdding: .month, value: months, to: self) ?? self }
    func isSameDay(as other: Date) -> Bool { cal.isDate(self, inSameDayAs: other) }

    /// 9/13
    var monthDayText: String { "\(month)/\(day)" }

    /// 9月13日(土)
    var japaneseDayText: String { "\(month)月\(day)日(\(Weekday.label(weekday)))" }

    var timeText: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }
}

enum Weekday {
    /// Calendar.weekday (1 = 日) を月曜始まりで並べたもの
    static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]

    static func label(_ weekday: Int) -> String {
        ["日", "月", "火", "水", "木", "金", "土"][((weekday - 1) % 7 + 7) % 7]
    }
}

enum Haptics {
    static var enabled: Bool { UserDefaults.standard.object(forKey: SettingsKey.haptics) as? Bool ?? true }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

enum SettingsKey {
    static let hasOnboarded = "hasOnboarded"
    static let carryOver = "carryOverEnabled"
    static let notifications = "notificationsEnabled"
    static let haptics = "hapticsEnabled"
    static let healthKit = "healthKitEnabled"
    static let location = "locationEnabled"
}

enum ImageDownscaler {
    static func jpegData(from data: Data, maxDimension: CGFloat = 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.82)
    }
}
