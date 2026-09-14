import Foundation
import SwiftData

enum RewardCategory: String, CaseIterable, Identifiable {
    case gadget, food, travel, fashion, experience, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .gadget: "Gadget"
        case .food: "Food"
        case .travel: "Travel"
        case .fashion: "Fashion"
        case .experience: "Experience"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .gadget: "headphones"
        case .food: "fork.knife"
        case .travel: "airplane"
        case .fashion: "tshirt.fill"
        case .experience: "sparkles"
        case .other: "gift.fill"
        }
    }

    var gradient: (UInt32, UInt32) {
        switch self {
        case .gadget: (0x3A4A6B, 0x121A2E)
        case .food: (0xF0A23B, 0xB5462C)
        case .travel: (0x38BDF8, 0x0A7AFF)
        case .fashion: (0xA78BFA, 0x6D28D9)
        case .experience: (0xF3D27A, 0xC68A1E)
        case .other: (0x34D399, 0x0E9F6E)
        }
    }
}

enum RewardPriority: Int, CaseIterable, Identifiable {
    case high = 0, normal = 1, low = 2
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .high: "High"
        case .normal: "Normal"
        case .low: "Low"
        }
    }
}

@Model
final class Reward {
    var id: UUID = UUID()
    var name: String = ""
    var note: String = ""
    var price: Int = 0
    var category: String = RewardCategory.other.rawValue
    @Attribute(.externalStorage) var imageData: Data?
    var priority: Int = RewardPriority.normal.rawValue
    var isPurchased: Bool = false
    var purchasedAt: Date?
    var createdAt: Date = Date()

    init(
        name: String,
        note: String = "",
        price: Int,
        category: RewardCategory = .other,
        imageData: Data? = nil,
        priority: RewardPriority = .normal,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.note = note
        self.price = price
        self.category = category.rawValue
        self.imageData = imageData
        self.priority = priority.rawValue
        self.createdAt = createdAt
    }

    var categoryValue: RewardCategory { RewardCategory(rawValue: category) ?? .other }
    var priorityValue: RewardPriority { RewardPriority(rawValue: priority) ?? .normal }
}
