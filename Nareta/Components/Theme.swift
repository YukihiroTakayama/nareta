import SwiftUI

enum Theme {
    static let navy = Color(hex: 0x0B1426)
    static let navyLight = Color(hex: 0x16213A)
    static let ink = Color(hex: 0x0F172A)
    static let subtext = Color(hex: 0x6B7280)
    static let blue = Color(hex: 0x0A7AFF)
    static let gold = Color(hex: 0xD4A537)
    static let goldLight = Color(hex: 0xF3D27A)
    static let goldDeep = Color(hex: 0xB0812A)
    static let green = Color(hex: 0x22B35E)
    static let doneBackground = Color(hex: 0xEFFAF3)
    static let background = Color(hex: 0xF7F7F8)
    static let chip = Color(hex: 0xEEF0F3)
    static let line = Color(hex: 0xE6E8EC)
    static let red = Color(hex: 0xE5484D)

    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xFBE3A0), Color(hex: 0xE2B24E), Color(hex: 0xC8922F)],
        startPoint: .top, endPoint: .bottom
    )
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var background: Color = .white
    var radius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line.opacity(0.8), lineWidth: 1))
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16, background: Color = .white, radius: CGFloat = 18) -> some View {
        modifier(CardStyle(padding: padding, background: background, radius: radius))
    }
}
