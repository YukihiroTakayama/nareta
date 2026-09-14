import SwiftData
import SwiftUI

struct RewardPurchaseView: View {
    let reward: Reward
    let available: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var completed = false
    @State private var failed = false

    var body: some View {
        let after = available - reward.price

        VStack(spacing: 0) {
            Capsule().fill(Theme.line).frame(width: 40, height: 5).padding(.top, 10)

            if completed {
                success
            } else {
                ScrollView {
                    VStack(spacing: 22) {
                        RewardThumbnail(reward: reward, size: 120, radius: 24)
                            .padding(.top, 24)

                        Text("\(reward.name)を\nごほうびとして受け取りますか？")
                            .font(.system(size: 22, weight: .heavy))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.ink)

                        VStack(spacing: 0) {
                            row("価格", reward.price.yen, color: Theme.ink)
                            Divider()
                            row("現在の解放額", available.yen, color: Theme.ink)
                            Divider()
                            row("購入後", after.yen, color: after >= 0 ? Theme.goldDeep : Theme.red, bold: true)
                        }
                        .cardStyle(padding: 4)

                        if after < 0 {
                            Label("あと \((-after).yen) 足りません", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.red)
                        }

                        Text("実際の支払いは行われません。アプリ内の「使っていいお金」から差し引かれ、履歴に記録されます。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                }

                BottomBar {
                    VStack(spacing: 8) {
                        PrimaryButton(title: "受け取る", leadingIcon: "gift.fill", kind: .gold) {
                            if RewardService(context: context).purchase(reward) {
                                Haptics.success()
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { completed = true }
                            } else {
                                failed = true
                            }
                        }
                        .disabled(after < 0)
                        Button("キャンセル") { dismiss() }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.subtext)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .background(Theme.background)
        .alert("受け取れませんでした", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("解放額が足りないか、既に受け取り済みです。")
        }
    }

    private var success: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                CoinBurst()
                Image(systemName: "gift.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 120)
                    .background(Theme.goldGradient, in: Circle())
                    .shadow(color: Theme.gold.opacity(0.5), radius: 20)
            }
            Text("おめでとう！").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.ink)
            Text("\(reward.name)を受け取りました。\nがんばった自分を楽しもう。")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.subtext)
            Text("\(reward.price.yen) を使用しました")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.goldDeep)
            Spacer()
            PrimaryButton(title: "閉じる", kind: .navy) { dismiss() }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    private func row(_ label: String, _ value: String, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.subtext)
            Spacer()
            Text(value)
                .font(.system(size: bold ? 22 : 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}
