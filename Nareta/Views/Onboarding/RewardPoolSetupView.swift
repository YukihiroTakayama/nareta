import SwiftUI

struct RewardPoolSetupView: View {
    @Binding var amount: Int
    @Binding var includeSamples: Bool
    let onBack: () -> Void
    let onFinish: () -> Void

    static let presets = [10_000, 20_000, 30_000, 50_000]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: 2, onBack: onBack).padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("今月、自分に\nいくら使っていい？")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Theme.ink)

                    HeroCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reward Pool").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                            MoneyText(amount: amount, size: 50)
                                .animation(.snappy, value: amount)
                            Text("解放済み ¥0 ・ 未解放 \(amount.yen)")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.7))
                            HStack {
                                GoldProgressBar(progress: 0)
                                PercentLabel(progress: 0)
                            }
                            .padding(.trailing, 90)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            ForEach(Self.presets, id: \.self) { value in
                                Button {
                                    Haptics.tap()
                                    amount = value
                                } label: {
                                    Text(value.yen)
                                        .font(.system(size: 14, weight: .bold))
                                        .monospacedDigit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .foregroundStyle(amount == value ? .white : Theme.ink)
                                        .background(amount == value ? Theme.gold : .white, in: Capsule())
                                        .overlay(Capsule().stroke(amount == value ? .clear : Theme.line))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        YenAmountField(amount: $amount, placeholder: "金額を自由に入力")
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Theme.gold)
                            .frame(width: 32, height: 32)
                            .background(Theme.gold.opacity(0.12), in: Circle())
                        Text("この金額は最初から使えるわけではありません。\n目標を達成した分だけ解放されます。")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink.opacity(0.8))
                            .lineSpacing(3)
                    }
                    .cardStyle(background: Color(hex: 0xFFF9EA))

                    Toggle(isOn: $includeSamples) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("サンプルの目標とごほうびを追加").font(.system(size: 15, weight: .semibold))
                            Text("8,000歩・勉強30分・ジム・AirPods Pro など").font(.system(size: 12)).foregroundStyle(Theme.subtext)
                        }
                    }
                    .tint(Theme.blue)
                    .cardStyle()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                PrimaryButton(title: "設定する", icon: "chevron.right", kind: .navy, action: onFinish)
                    .disabled(amount < 1_000)
            }
        }
    }
}
