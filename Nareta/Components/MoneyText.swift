import SwiftUI

struct MoneyText: View {
    let amount: Int
    var size: CGFloat = 44
    var signed = false
    var gold = true
    var color: Color = Theme.ink

    var body: some View {
        Text(signed ? amount.signedYen : amount.yen)
            .font(.system(size: size, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(gold ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(color))
            .contentTransition(.numericText(value: Double(amount)))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}
