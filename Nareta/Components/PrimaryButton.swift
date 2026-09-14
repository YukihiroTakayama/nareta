import SwiftUI

enum PrimaryButtonKind {
    case navy, blue, gold
}

struct PrimaryButtonStyle: ButtonStyle {
    var kind: PrimaryButtonKind = .navy

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, kind: kind)
    }

    private struct StyledBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: PrimaryButtonKind
        @Environment(\.isEnabled) private var isEnabled

        var fill: Color {
            switch kind {
            case .navy: Theme.navy
            case .blue: Theme.blue
            case .gold: Theme.gold
            }
        }

        var body: some View {
            configuration.label
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(isEnabled ? fill : Color(hex: 0xC4C8CF), in: Capsule())
                .shadow(color: isEnabled ? fill.opacity(0.25) : .clear, radius: 10, y: 5)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .opacity(configuration.isPressed ? 0.9 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String?
    var leadingIcon: String?
    var kind: PrimaryButtonKind = .navy
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let leadingIcon { Image(systemName: leadingIcon) }
                Text(title)
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .bold)) }
            }
        }
        .buttonStyle(PrimaryButtonStyle(kind: kind))
    }
}

/// 下部に固定するボタン領域
struct BottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                LinearGradient(colors: [Theme.background.opacity(0), Theme.background, Theme.background], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
    }
}
