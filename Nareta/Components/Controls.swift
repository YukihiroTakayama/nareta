import SwiftUI

struct SelectChip: View {
    enum Style { case navy, gold }

    let title: String
    var icon: String?
    let selected: Bool
    var style: Style = .navy
    var showsCheck = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected && showsCheck && style == .navy {
                    Image(systemName: "checkmark.circle.fill")
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(selected ? .white : Theme.ink)
            .background(selected ? (style == .gold ? Theme.gold : Theme.navy) : Theme.chip, in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: selected)
    }
}

struct TagChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

extension TagChip {
    init(identity: Identity) {
        self.init(text: identity.name, color: Color(hexString: identity.colorHex))
    }
}

struct CheckCircle: View {
    let done: Bool
    var size: CGFloat = 32

    var body: some View {
        ZStack {
            if done {
                Circle().fill(Theme.green)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .heavy))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle().stroke(Color(hex: 0x9CA3AF), lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
    }
}

struct IconBadge: View {
    let systemName: String
    var color: Color = Theme.ink
    var background: Color = Theme.chip
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

struct EditorSection<Content: View>: View {
    let title: String
    var subtitle: String?
    var trailing: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    if let trailing {
                        Text(trailing).font(.footnote).foregroundStyle(Theme.subtext).monospacedDigit()
                    }
                }
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(Theme.subtext)
                }
            }
            content
        }
        .cardStyle()
    }
}

struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Theme.blue : Color(hex: 0xD6D9DE))
                    .frame(width: i == current ? 18 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.35), value: current)
    }
}

/// チップ等を折り返して並べるレイアウト
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: proposal.width ?? width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct YenAmountField: View {
    @Binding var amount: Int
    var placeholder = "金額を入力"

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("¥").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.subtext)
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .focused($focused)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Theme.chip.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { text = amount > 0 ? "\(amount)" : "" }
        .onChange(of: amount) { _, newValue in
            if Int(text) != newValue { text = newValue > 0 ? "\(newValue)" : "" }
        }
        .onChange(of: text) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(8))
            if digits != newValue { text = digits }
            amount = Int(digits) ?? 0
        }
        .toolbar {
            if focused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focused = false }
                }
            }
        }
    }
}
