import SwiftUI

/// Goal Complete → Money Unlock → Rewardに近づく を見せるオーバーレイ
struct GoalCompletionView: View {
    let result: CompletionResult
    let onDismiss: () -> Void

    @State private var checkTrim: CGFloat = 0
    @State private var circleScale: CGFloat = 0.3
    @State private var showAmount = false
    @State private var showBurst = false
    @State private var showDetails = false
    @State private var balance: Int
    @State private var remaining: Int
    @State private var progress: Double
    @State private var dismissed = false

    init(result: CompletionResult, onDismiss: @escaping () -> Void) {
        self.result = result
        self.onDismiss = onDismiss
        _balance = State(initialValue: result.balanceBefore)
        _remaining = State(initialValue: result.remainingBefore)
        _progress = State(initialValue: Self.progress(balance: result.balanceBefore, price: result.rewardPrice))
    }

    private static func progress(balance: Int, price: Int) -> Double {
        guard price > 0 else { return 1 }
        return min(1, Double(max(0, balance)) / Double(price))
    }

    var body: some View {
        ZStack {
            Color(hex: 0x050A14).opacity(0.78)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: close)

            VStack(spacing: 18) {
                ZStack {
                    if showBurst { CoinBurst() }
                    Circle()
                        .fill(Theme.green)
                        .frame(width: 104, height: 104)
                        .shadow(color: Theme.green.opacity(0.6), radius: 24)
                        .scaleEffect(circleScale)
                    CheckmarkShape()
                        .trim(from: 0, to: checkTrim)
                        .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                        .frame(width: 46, height: 36)
                }
                .frame(height: 130)

                Text(result.goalTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 6) {
                    MoneyText(amount: result.amount, size: 64, signed: true)
                    Text(result.amount > 0 ? "解放しました" : "今月のReward Poolはすべて解放済みです")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    if let day = result.recordedDay {
                        Text("\(day.japaneseDayText)の分として記録しました")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    if result.bonusAmount > 0 {
                        Label("復帰ボーナス \(result.bonusAmount.signedYen) 込み", systemImage: "arrow.uturn.up")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.goldLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Theme.gold.opacity(0.18), in: Capsule())
                    }
                    if result.wasCapped && result.amount > 0 {
                        Text("Pool上限のため \(result.requestedAmount.yen) → \(result.amount.yen)")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .opacity(showAmount ? 1 : 0)
                .scaleEffect(showAmount ? 1 : 0.6)

                if let days = result.milestoneDays {
                    VStack(spacing: 4) {
                        Label("\(days)日連続達成！", systemImage: "flame.fill")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFC857), Color(hex: 0xF08A24)], startPoint: .top, endPoint: .bottom))
                        if result.milestoneBonus > 0 {
                            Text("連続ボーナス \(result.milestoneBonus.signedYen)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.goldLight)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.gold.opacity(0.16), in: Capsule())
                    .opacity(showDetails ? 1 : 0)
                    .scaleEffect(showDetails ? 1 : 0.7)
                } else if result.streak > 0 {
                    Label("\(result.streak)日連続", systemImage: "flame.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.orange)
                        .opacity(showDetails ? 1 : 0)
                }

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今月使っていいお金").font(.system(size: 13)).foregroundStyle(.white.opacity(0.65))
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(result.balanceBefore.yen)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Image(systemName: "arrow.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                            MoneyText(amount: balance, size: 30)
                        }
                        .monospacedDigit()
                    }

                    if let name = result.rewardName {
                        Divider().overlay(.white.opacity(0.15))
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(name)まで").font(.system(size: 13)).foregroundStyle(.white.opacity(0.65))
                                Spacer()
                                Text(remaining == 0 ? "受け取り可能！" : "あと \(remaining.yen)")
                                    .font(.system(size: 17, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(remaining == 0 ? Theme.green : .white)
                                    .contentTransition(.numericText(value: Double(remaining)))
                            }
                            GoldProgressBar(progress: progress, height: 9)
                        }
                    }
                }
                .padding(18)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12)))
                .opacity(showDetails ? 1 : 0)
                .offset(y: showDetails ? 0 : 16)

                Text("タップして閉じる")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.45))
                    .opacity(showDetails ? 1 : 0)
            }
            .padding(.horizontal, 28)
            .allowsHitTesting(false)
        }
        .task { await runSequence() }
    }

    private func runSequence() async {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { circleScale = 1 }
        withAnimation(.easeOut(duration: 0.35).delay(0.15)) { checkTrim = 1 }

        guard await pause(0.4) else { return }
        showBurst = true
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { showAmount = true }

        guard await pause(0.45) else { return }
        withAnimation(.easeOut(duration: 0.3)) { showDetails = true }

        guard await pause(0.35) else { return }
        withAnimation(.easeInOut(duration: 1.0)) {
            balance = result.balanceAfter
            remaining = result.remainingAfter
            progress = Self.progress(balance: result.balanceAfter, price: result.rewardPrice)
        }
        Haptics.tap()

        guard await pause(2.4) else { return }
        close()
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled && !dismissed
    }

    private func close() {
        guard !dismissed else { return }
        dismissed = true
        onDismiss()
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

struct CoinBurst: View {
    @State private var go = false

    private let coins: [(angle: Double, distance: CGFloat, size: CGFloat, delay: Double)] = (0..<12).map { i in
        let angle = Double(i) / 12 * 2 * .pi + Double(i % 3) * 0.2
        return (angle, CGFloat(110 + (i * 37) % 70), CGFloat(20 + (i * 7) % 16), Double(i % 4) * 0.03)
    }

    var body: some View {
        ZStack {
            ForEach(coins.indices, id: \.self) { i in
                let coin = coins[i]
                CoinView(size: coin.size)
                    .offset(
                        x: go ? cos(coin.angle) * coin.distance : 0,
                        y: go ? sin(coin.angle) * coin.distance - 30 : 0
                    )
                    .scaleEffect(go ? 1 : 0.2)
                    .opacity(go ? 0 : 1)
                    .animation(.easeOut(duration: 1.1).delay(coin.delay), value: go)
            }
        }
        .onAppear { go = true }
    }
}
