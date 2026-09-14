import SwiftUI

/// ダークネイビー + 山のシルエットのヒーローカード
struct HeroCard<Content: View>: View {
    var showTagline = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { HeroBackground(showTagline: showTagline) }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Theme.navy.opacity(0.22), radius: 16, y: 8)
    }
}

struct HeroBackground: View {
    var showTagline = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: [Color(hex: 0x0A1020), Color(hex: 0x17223B)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Theme.blue.opacity(0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: 260)

            GeometryReader { geo in
                let w = geo.size.width * 0.62
                let h = geo.size.height * 0.85
                ZStack {
                    MountainShape(closed: true)
                        .fill(LinearGradient(colors: [Color(hex: 0x3A4663), Color(hex: 0x0E1628).opacity(0)], startPoint: .top, endPoint: .bottom))
                    MountainShape(closed: false)
                        .stroke(LinearGradient(colors: [Theme.goldLight.opacity(0.85), Theme.goldLight.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
                }
                .frame(width: w, height: h)
                .position(x: geo.size.width - w / 2, y: geo.size.height - h / 2 + 8)
            }
            .allowsHitTesting(false)

            if showTagline {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DISCIPLINE")
                    Text("CREATES")
                    Text("FREEDOM")
                }
                .font(.system(size: 9, weight: .medium))
                .tracking(2.6)
                .foregroundStyle(.white.opacity(0.6))
                .padding(18)
            }
        }
    }
}

struct MountainShape: Shape {
    var closed: Bool

    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            .init(x: 0, y: 1), .init(x: 0.18, y: 0.62), .init(x: 0.28, y: 0.68), .init(x: 0.46, y: 0.32),
            .init(x: 0.54, y: 0.4), .init(x: 0.7, y: 0.08), .init(x: 0.8, y: 0.3), .init(x: 0.88, y: 0.24), .init(x: 1, y: 0.46),
        ]
        var path = Path()
        for (i, p) in points.enumerated() {
            let pt = CGPoint(x: rect.minX + p.x * rect.width, y: rect.minY + p.y * rect.height)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct GoldProgressBar: View {
    let progress: Double
    var height: CGFloat = 10
    var track: Color = .white.opacity(0.14)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0xF7D98A), Color(hex: 0xD9A544)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(progress > 0 ? height : 0, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
    }
}

struct LinearBar: View {
    let progress: Double
    var color: Color = Theme.blue
    var height: CGFloat = 8
    var track: Color = Theme.chip

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: max(progress > 0 ? height : 0, geo.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: height)
    }
}

struct StreakBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFC857), Color(hex: 0xF08A24)], startPoint: .top, endPoint: .bottom))
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(Theme.goldLight)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.black.opacity(0.25)))
        .overlay(Capsule().stroke(Theme.gold.opacity(0.7), lineWidth: 1))
    }
}

struct PercentLabel: View {
    let progress: Double

    var body: some View {
        Text("\(Int((progress * 100).rounded()))%")
            .font(.system(size: 15, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .contentTransition(.numericText())
    }
}
