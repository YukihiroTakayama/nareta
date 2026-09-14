import SwiftUI

struct RewardThumbnail: View {
    let reward: Reward
    var size: CGFloat = 88
    var height: CGFloat?
    var radius: CGFloat = 14

    var body: some View {
        let colors = reward.categoryValue.gradient
        ZStack {
            if let data = reward.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(colors: [Color(hex: colors.0), Color(hex: colors.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: reward.categoryValue.icon)
                    .font(.system(size: min(size, height ?? size) * 0.38, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(width: size == .infinity ? nil : size, height: height ?? size)
        .frame(maxWidth: size == .infinity ? .infinity : nil)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

enum RewardStatus {
    case saving, claimable, purchased

    init(reward: Reward, available: Int) {
        if reward.isPurchased { self = .purchased }
        else if available >= reward.price { self = .claimable }
        else { self = .saving }
    }
}

struct RewardStatusBadge: View {
    let status: RewardStatus

    var body: some View {
        switch status {
        case .saving:
            badge("貯金中", icon: nil, color: Theme.blue)
        case .claimable:
            badge("受け取り可能", icon: "gift", color: Theme.green)
        case .purchased:
            badge("受け取り済み", icon: "checkmark", color: Theme.subtext)
        }
    }

    private func badge(_ text: String, icon: String?, color: Color) -> some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1), in: Capsule())
    }
}

struct RewardRow: View {
    let reward: Reward
    let available: Int

    private var status: RewardStatus { RewardStatus(reward: reward, available: available) }
    private var progress: Double { reward.price > 0 ? min(1, Double(max(0, available)) / Double(reward.price)) : 1 }
    private var remaining: Int { max(0, reward.price - available) }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RewardThumbnail(reward: reward, size: 84)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reward.name).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                        if !reward.note.isEmpty {
                            Text(reward.note).font(.system(size: 12)).foregroundStyle(Theme.subtext).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    RewardStatusBadge(status: status)
                }
                Text(reward.price.yen).font(.system(size: 16, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)

                if status == .purchased {
                    if let date = reward.purchasedAt {
                        Text("\(date.monthDayText) に受け取り").font(.system(size: 12)).foregroundStyle(Theme.subtext)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(min(max(0, available), reward.price).yen).font(.system(size: 14, weight: .bold)).monospacedDigit()
                            + Text(" / \(reward.price.yen)").font(.system(size: 12)).foregroundStyle(Theme.subtext)
                        Spacer()
                        Text(remaining == 0 ? "達成！" : "あと \(remaining.yen)")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(remaining == 0 ? Theme.green : Theme.ink)
                    }
                    LinearBar(progress: progress, color: status == .claimable ? Theme.green : Theme.blue, height: 7)
                }
            }
        }
        .cardStyle(padding: 14)
        .opacity(status == .purchased ? 0.75 : 1)
    }
}
