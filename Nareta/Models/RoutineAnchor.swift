import Foundation
import SwiftData

/// 「夕食 = 19:00」のような、生活のいつもの時刻（If-Thenのトリガーに使う）
@Model
final class RoutineAnchor {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "clock"
    /// 0時からの分
    var minutes: Int = 0
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    init(name: String, icon: String, minutes: Int, sortOrder: Int) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.minutes = minutes
        self.sortOrder = sortOrder
        self.createdAt = .now
    }

    static let presets: [(name: String, icon: String, minutes: Int)] = [
        ("起床", "sunrise.fill", 7 * 60),
        ("昼食", "fork.knife", 12 * 60),
        ("仕事終わり", "briefcase.fill", 18 * 60),
        ("夕食", "takeoutbag.and.cup.and.straw.fill", 19 * 60),
        ("入浴", "bathtub.fill", 21 * 60),
        ("就寝", "bed.double.fill", 23 * 60 + 30),
    ]
}
