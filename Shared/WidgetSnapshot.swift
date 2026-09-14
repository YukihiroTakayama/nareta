import Foundation

/// アプリがApp Groupに書き出し、ウィジェットが読むデータ
struct WidgetSnapshot: Codable {
    struct GoalItem: Codable, Identifiable, Hashable {
        let id: UUID
        let title: String
        let reward: Int
        let done: Bool
        let trigger: String?
    }

    var generatedAt: Date
    var available: Int
    var poolTotal: Int
    var unlocked: Int
    var todayEarned: Int
    var goals: [GoalItem]
    var nextRewardName: String?
    var nextRewardPrice: Int?

    static let appGroup = "group.app.nareta"
    private static let key = "widgetSnapshot.v1"

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }

    /// 日付が変わった後は、書き出した日の達成状況を未達成として扱う
    func isCurrent(at date: Date) -> Bool {
        Calendar.current.isDate(generatedAt, inSameDayAs: date)
    }

    func isDone(_ goal: GoalItem, at date: Date) -> Bool {
        isCurrent(at: date) && goal.done
    }

    func doneCount(at date: Date) -> Int {
        goals.filter { isDone($0, at: date) }.count
    }

    func earned(at date: Date) -> Int {
        isCurrent(at: date) ? todayEarned : 0
    }

    func remaining(at date: Date) -> Int {
        goals.filter { !isDone($0, at: date) }.reduce(0) { $0 + $1.reward }
    }

    var progress: Double {
        poolTotal > 0 ? min(1, Double(unlocked) / Double(poolTotal)) : 0
    }

    static func yen(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US")
        return (value < 0 ? "-" : "") + "¥" + (formatter.string(from: NSNumber(value: abs(value))) ?? "\(abs(value))")
    }

    static let placeholder = WidgetSnapshot(
        generatedAt: .now,
        available: 12_400,
        poolTotal: 30_000,
        unlocked: 12_400,
        todayEarned: 300,
        goals: [
            GoalItem(id: UUID(), title: "8,000歩", reward: 100, done: true, trigger: "昼食（12:00）"),
            GoalItem(id: UUID(), title: "勉強30分", reward: 200, done: true, trigger: "20:00"),
            GoalItem(id: UUID(), title: "ジム", reward: 500, done: false, trigger: "19:00"),
            GoalItem(id: UUID(), title: "23:30までに寝る", reward: 100, done: false, trigger: "23:00"),
        ],
        nextRewardName: "AirPods Pro",
        nextRewardPrice: 39_800
    )
}
