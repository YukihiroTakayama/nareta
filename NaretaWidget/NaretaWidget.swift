import SwiftUI
import WidgetKit

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let naretaGold = Color(hex: 0xE2B24E)
    static let naretaGoldLight = Color(hex: 0xF3D27A)
    static let naretaGreen = Color(hex: 0x4ADE80)
}

private let goldGradient = LinearGradient(
    colors: [Color(hex: 0xFBE3A0), Color(hex: 0xE2B24E), Color(hex: 0xC8922F)],
    startPoint: .top, endPoint: .bottom
)

private let heroBackground = LinearGradient(
    colors: [Color(hex: 0x0A1020), Color(hex: 0x17223B)],
    startPoint: .topLeading, endPoint: .bottomTrailing
)

// MARK: - Timeline

struct NaretaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct NaretaProvider: TimelineProvider {
    func placeholder(in context: Context) -> NaretaEntry {
        NaretaEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NaretaEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (WidgetSnapshot.load() ?? .placeholder)
        completion(NaretaEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NaretaEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? .placeholder
        let now = Date()
        let calendar = Calendar.current
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        let entries = [
            NaretaEntry(date: now, snapshot: snapshot),
            NaretaEntry(date: nextDay.addingTimeInterval(60), snapshot: snapshot),
        ]
        completion(Timeline(entries: entries, policy: .after(nextDay.addingTimeInterval(3_600))))
    }
}

// MARK: - Home Screen

struct TodaySmallView: View {
    let entry: NaretaEntry

    var body: some View {
        let snapshot = entry.snapshot
        let done = snapshot.doneCount(at: entry.date)
        let remaining = snapshot.remaining(at: entry.date)

        VStack(alignment: .leading, spacing: 2) {
            Text("TODAY")
                .font(.system(size: 11, weight: .heavy))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(done)")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(.white)
                Text("/ \(snapshot.goals.count)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Text(WidgetSnapshot.yen(snapshot.available))
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(goldGradient)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(remaining > 0 ? "あと\(WidgetSnapshot.yen(remaining))解放" : "今日はすべて達成")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(remaining > 0 ? .white.opacity(0.75) : Color.naretaGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct TodayMediumView: View {
    let entry: NaretaEntry

    var body: some View {
        let snapshot = entry.snapshot
        let done = snapshot.doneCount(at: entry.date)
        let remaining = snapshot.remaining(at: entry.date)

        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("今月使っていいお金")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text(WidgetSnapshot.yen(snapshot.available))
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(goldGradient)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                ProgressView(value: snapshot.progress)
                    .tint(Color.naretaGold)
                Spacer(minLength: 0)
                Text("今日 +\(WidgetSnapshot.yen(snapshot.earned(at: entry.date)))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.naretaGreen)
                Text(remaining > 0 ? "あと\(WidgetSnapshot.yen(remaining))解放できる" : "今日はすべて達成")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                Text("TODAY \(done)/\(snapshot.goals.count)")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.7))
                if snapshot.goals.isEmpty {
                    Text("今日の目標はありません")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                ForEach(snapshot.goals.prefix(4)) { goal in
                    let isDone = snapshot.isDone(goal, at: entry.date)
                    HStack(spacing: 6) {
                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundStyle(isDone ? Color.naretaGreen : .white.opacity(0.5))
                        Text(goal.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(isDone ? 0.55 : 1))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("+\(WidgetSnapshot.yen(goal.reward))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.naretaGoldLight)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NaretaEntry

    var body: some View {
        switch family {
        case .systemMedium: TodayMediumView(entry: entry)
        default: TodaySmallView(entry: entry)
        }
    }
}

struct NaretaTodayWidget: Widget {
    let kind = "NaretaToday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NaretaProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { heroBackground }
                .widgetURL(URL(string: "nareta://home"))
        }
        .configurationDisplayName("TODAY")
        .description("今日の目標と、今月使っていいお金を表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen

struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NaretaEntry

    var body: some View {
        let snapshot = entry.snapshot
        let done = snapshot.doneCount(at: entry.date)
        let total = snapshot.goals.count

        switch family {
        case .accessoryCircular:
            Gauge(value: Double(done), in: 0...Double(max(total, 1))) {
                Text("TODAY")
            } currentValueLabel: {
                Text("\(done)/\(total)")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryInline:
            Text("\(WidgetSnapshot.yen(snapshot.available)) · \(done)/\(total) Done")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(WidgetSnapshot.yen(snapshot.available))
                    .font(.system(size: 20, weight: .heavy))
                    .widgetAccentable()
                Text("今日 \(done)/\(total) · あと\(WidgetSnapshot.yen(snapshot.remaining(at: entry.date)))")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct NaretaLockWidget: Widget {
    let kind = "NaretaLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NaretaProvider()) { entry in
            LockWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "nareta://home"))
        }
        .configurationDisplayName("NARETA")
        .description("ロック画面に、今日の進み具合と使っていいお金を表示します。")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct NaretaWidgetBundle: WidgetBundle {
    var body: some Widget {
        NaretaTodayWidget()
        NaretaLockWidget()
    }
}
