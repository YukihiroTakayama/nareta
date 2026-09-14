import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void
    let onLater: () -> Void

    @State private var floating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("NARETA")
                    .font(.system(size: 26, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("目標を達成したら、")
                    Text("自分に\(Text("お小遣いを。").foregroundStyle(Theme.goldGradient))")
                }
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text("がんばった分だけ、\n今月使っていいお金が増えていきます。")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.subtext)
                    .lineSpacing(4)

                heroVisual
                    .frame(height: 250)
                    .padding(.vertical, 6)

                VStack(spacing: 10) {
                    feature(icon: "checkmark", iconColor: .white, iconBg: Theme.green, title: "行動すると解放",
                            text: "タスクを達成するたびに、今月使っていいお金が増えます。")
                    feature(icon: "cart", iconColor: Theme.ink, iconBg: Theme.chip, title: "欲しいものに近づく",
                            text: "貯まったお金で、欲しいものを買う楽しみがもっと身近に。")
                    feature(icon: "line.3.horizontal", iconColor: Theme.ink, iconBg: Theme.chip, title: "自分用だからシンプル",
                            text: "むずかしい設定はいりません。やることに集中できます。")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                PageDots(count: 3, current: 0)
                PrimaryButton(title: "はじめる", icon: "chevron.right", kind: .blue, action: onStart)
                Button("あとで（おすすめ設定ではじめる）", action: onLater)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.subtext)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .background(Theme.background.opacity(0.96))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { floating = true }
        }
    }

    private var heroVisual: some View {
        ZStack {
            // 台座
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: 0x1F2A44), Theme.navy], startPoint: .top, endPoint: .bottom))
                .frame(width: 250, height: 46)
                .overlay(Ellipse().stroke(Theme.blue.opacity(0.7), lineWidth: 2).blur(radius: 1.5))
                .shadow(color: Theme.blue.opacity(0.45), radius: 18)
                .offset(y: 100)

            // 上昇矢印
            Image(systemName: "arrow.up.right")
                .font(.system(size: 90, weight: .black))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0x7CC4FF), Theme.blue], startPoint: .bottomLeading, endPoint: .topTrailing))
                .shadow(color: Theme.blue.opacity(0.6), radius: 14)
                .fixedSize()
                .offset(x: 120, y: -95)

            HeroCard(showTagline: false) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今月使っていいお金").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                    MoneyText(amount: 12_400, size: 40)
                    Text("+¥2,400 今週の達成で解放").font(.system(size: 12)).foregroundStyle(.white.opacity(0.75))
                    HStack {
                        GoldProgressBar(progress: 0.41, height: 8)
                        PercentLabel(progress: 0.41).font(.system(size: 12))
                    }
                    .padding(.trailing, 70)
                }
            }
            .frame(width: 290)
            .rotation3DEffect(.degrees(12), axis: (x: 0.3, y: -1, z: 0.15), perspective: 0.6)
            .offset(y: floating ? -6 : 4)

            coin(size: 62).offset(x: -150, y: 10).rotationEffect(.degrees(-18))
            coin(size: 48).offset(x: -115, y: 85)
            coin(size: 70).offset(x: 140, y: 10).offset(y: floating ? 6 : -4)
        }
        .frame(maxWidth: .infinity)
    }

    private func coin(size: CGFloat) -> some View {
        CoinView(size: size)
    }

    private func feature(icon: String, iconColor: Color, iconBg: Color, title: String, text: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemName: icon, color: iconColor, background: iconBg, size: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
                Text(text).font(.system(size: 13)).foregroundStyle(Theme.subtext).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 14)
    }
}

struct CoinView: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Theme.goldGradient)
            Circle().stroke(Color(hex: 0xFFF1C2).opacity(0.8), lineWidth: size * 0.05).padding(size * 0.1)
            Text("¥")
                .font(.system(size: size * 0.45, weight: .heavy))
                .foregroundStyle(Color(hex: 0x9A6B1C))
        }
        .frame(width: size, height: size)
        .shadow(color: Theme.gold.opacity(0.4), radius: size * 0.15, y: size * 0.08)
    }
}
