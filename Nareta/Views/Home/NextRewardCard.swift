import SwiftUI

struct NextRewardCard: View {
    let reward: Reward
    let available: Int
    let onSeeAll: () -> Void
    let onOpen: () -> Void

    var body: some View {
        let progress = reward.price > 0 ? min(1, Double(max(0, available)) / Double(reward.price)) : 1
        let remaining = max(0, reward.price - available)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("次のごほうび").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                Button(action: onSeeAll) {
                    HStack(spacing: 4) {
                        Text("ごほうびを見る")
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.subtext)
                }
                .buttonStyle(.borderless)
            }

            Button(action: onOpen) {
                HStack(spacing: 16) {
                    RewardThumbnail(reward: reward, size: 96, radius: 16)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reward.name).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.ink).lineLimit(1)
                        if !reward.note.isEmpty {
                            Text(reward.note).font(.system(size: 13)).foregroundStyle(Theme.subtext).lineLimit(1)
                        }
                        Spacer(minLength: 2)
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Text(min(max(0, available), reward.price).yen).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)) / \(reward.price.yen)")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.subtext)
                                .monospacedDigit()
                            Spacer()
                            Text(remaining == 0 ? "受け取り可能！" : "あと \(remaining.yen)")
                                .font(.system(size: 14, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(remaining == 0 ? Theme.green : Theme.ink)
                                .contentTransition(.numericText(value: Double(remaining)))
                        }
                        LinearBar(progress: progress, color: remaining == 0 ? Theme.green : Theme.blue, height: 9)
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 96)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .cardStyle(padding: 16)
    }
}
