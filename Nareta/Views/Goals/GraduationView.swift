import SwiftData
import SwiftUI

struct GraduationView: View {
    let goal: Goal
    let completions: [GoalCompletion]
    let onNext: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var graduated = false

    var body: some View {
        VStack(spacing: 0) {
            if graduated {
                success
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            } else {
                confirm
            }
        }
        .background(Theme.background)
    }

    private var confirm: some View {
        let days = HabitService.days(since: goal)
        let rate = HabitService.recentRate(goal, completions)
        let earned = completions.reduce(0) { $0 + $1.rewardAmount }

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    medal(size: 116)
                        .padding(.top, 36)
                    Text("習慣になりました")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text("「\(goal.title)」は\(days)日つづき、\n考えなくてもできるようになっています。")
                        .font(.system(size: 16))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.subtext)

                    VStack(spacing: 0) {
                        row("続けた日数", "\(days)日")
                        Divider()
                        row("累計達成", "\(completions.count)回")
                        Divider()
                        row("直近4週の達成率", "\(Int((rate * 100).rounded()))%")
                        Divider()
                        row("解放したお金", earned.yen)
                    }
                    .cardStyle(padding: 4)

                    HabitNoticeCard(
                        icon: "archivebox.fill",
                        color: Theme.navy,
                        title: "卒業するとどうなる？",
                        message: "報酬とTodayの対象から外れ、Meの「定着した習慣」に残ります。崩れてきたら、いつでも習慣に戻せます。"
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            BottomBar {
                VStack(spacing: 8) {
                    PrimaryButton(title: "卒業する", leadingIcon: "medal.fill", kind: .gold) {
                        RewardService(context: context).graduate(goal)
                        NotificationService.reschedule(context: context)
                        Haptics.success()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { graduated = true }
                    }
                    Button("まだ続ける") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.subtext)
                        .padding(.vertical, 6)
                }
            }
        }
    }

    private var success: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                CoinBurst()
                medal(size: 140)
            }
            Text("卒業おめでとう！")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("「\(goal.title)」は、なりたい自分の一部になりました。")
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.subtext)
            Text("この目標に使っていた 月およそ\(HabitService.monthlyRewardEstimate(goal).yen) を、\n次の目標に回せます。")
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.goldDeep)
            Spacer()
            PrimaryButton(title: "次の目標を作る", icon: "arrow.right", kind: .navy) {
                dismiss()
                onNext()
            }
            Button("閉じる") { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.subtext)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func medal(size: CGFloat) -> some View {
        Image(systemName: "medal.fill")
            .font(.system(size: size * 0.45))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.goldGradient, in: Circle())
            .shadow(color: Theme.gold.opacity(0.45), radius: 20)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.subtext)
            Spacer()
            Text(value).font(.system(size: 17, weight: .bold)).monospacedDigit().foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}
