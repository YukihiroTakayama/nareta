import SwiftUI

/// 昨日の記録し忘れをその場で入れる
struct YesterdayCheckCard: View {
    let day: Date
    let goals: [Goal]
    let onRecord: (Goal) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                    .frame(width: 38, height: 38)
                    .background(Theme.blue.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("昨日（\(day.monthDayText)）の記録はお済みですか？")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("記録し忘れた分は、\(GoalService.backfillDays)日前まであとから入れられます")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.subtext)
                }
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.subtext)
                        .frame(width: 28, height: 28)
                        .background(Theme.chip, in: Circle())
                }
                .buttonStyle(.borderless)
            }

            ForEach(goals) { goal in
                HStack(spacing: 10) {
                    Text(goal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(goal.rewardAmount.signedYen)
                        .font(.system(size: 14, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.goldDeep)
                    Button { onRecord(goal) } label: {
                        Text("やった")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .background(Theme.green, in: Capsule())
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .cardStyle(background: Color(hex: 0xF3F8FF))
    }
}
