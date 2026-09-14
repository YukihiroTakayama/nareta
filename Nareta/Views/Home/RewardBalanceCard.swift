import SwiftUI

struct RewardBalanceCard: View {
    let pool: MonthlyRewardPool?
    var streak: Int = 0

    var body: some View {
        let available = pool?.availableAmount ?? 0
        let progress = pool?.progress ?? 0

        HeroCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("今月使っていいお金")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    if streak > 0 {
                        StreakBadge(text: "\(streak) DAY STREAK")
                    }
                }

                MoneyText(amount: available, size: 54)
                    .animation(.snappy, value: available)

                HStack(spacing: 14) {
                    labeled("Reward Pool", pool?.totalAmount ?? 0)
                    labeled("未解放", pool?.lockedAmount ?? 0)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.trailing, 80)

                if let carried = pool?.carriedOverAmount, carried > 0 {
                    Text("先月からの繰越 \(carried.yen) を含む")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.goldLight.opacity(0.8))
                }

                HStack(spacing: 12) {
                    GoldProgressBar(progress: progress)
                        .animation(.easeInOut(duration: 0.6), value: progress)
                    PercentLabel(progress: progress)
                }
                .padding(.trailing, 96)
                .padding(.top, 4)
            }
        }
    }

    private func labeled(_ label: String, _ amount: Int) -> some View {
        Text("\(label) \(amount.yen)")
            .font(.system(size: 14))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.72))
            .contentTransition(.numericText(value: Double(amount)))
    }
}
