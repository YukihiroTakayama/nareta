import Foundation
import SwiftData

@Model
final class Identity {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String?
    var colorHex: String?
    var createdAt: Date = Date()

    init(name: String, icon: String? = nil, colorHex: String? = nil, createdAt: Date = .now) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

struct IdentityPreset: Identifiable, Hashable {
    let name: String
    let icon: String
    let colorHex: String
    var id: String { name }

    static let all: [IdentityPreset] = [
        .init(name: "健康でいたい", icon: "heart.fill", colorHex: "22B35E"),
        .init(name: "体を鍛えたい", icon: "dumbbell.fill", colorHex: "F08A24"),
        .init(name: "学び続けたい", icon: "book.fill", colorHex: "0A7AFF"),
        .init(name: "仕事で成長したい", icon: "briefcase.fill", colorHex: "0EA5A4"),
        .init(name: "お金を大切にしたい", icon: "yensign.circle.fill", colorHex: "D4A537"),
        .init(name: "生活を整えたい", icon: "moon.stars.fill", colorHex: "5B6CFF"),
        .init(name: "新しいことに挑戦したい", icon: "mountain.2.fill", colorHex: "8B5CF6"),
    ]

    static let customIcon = "star.fill"
    static let customColors = ["0A7AFF", "22B35E", "F08A24", "8B5CF6", "D4A537", "EF4444", "0EA5A4"]

    static func find(_ name: String) -> IdentityPreset? { all.first { $0.name == name } }
}
