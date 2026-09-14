import SwiftUI

struct HabitNoticeCard: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                if let buttonTitle, let action {
                    Button(action: action) {
                        Text(buttonTitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(color, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle(padding: 14)
    }
}

struct GoalPlanCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("行動プラン", systemImage: "arrow.triangle.branch")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.ink)
            if !goal.cue.isEmpty {
                row("If-Then", Theme.blue, "\(goal.cue) → \(goal.title)")
            }
            if !goal.wishOutcome.isEmpty {
                row("Outcome", Theme.green, goal.wishOutcome)
            }
            if !goal.obstacle.isEmpty {
                row("Obstacle", .orange, goal.obstacle)
            }
            if !goal.obstaclePlan.isEmpty {
                row("Plan", Theme.goldDeep, goal.obstacle.isEmpty ? goal.obstaclePlan : "もし「\(goal.obstacle)」なら → \(goal.obstaclePlan)")
            }
        }
        .cardStyle()
    }

    private func row(_ tag: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(tag)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
                .frame(width: 76, alignment: .leading)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct HabitMeterCard: View {
    let goal: Goal
    let status: HabitService.GraduationStatus
    let onGraduate: () -> Void

    var body: some View {
        let archived = goal.archivedAt != nil
        let progress = min(1, Double(status.days) / Double(HabitService.formationDays))

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("習慣化メーター", systemImage: "gauge.with.needle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(archived ? "卒業済み" : "\(min(status.days, HabitService.formationDays)) / \(HabitService.formationDays)日")
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(archived ? Theme.goldDeep : Theme.subtext)
            }

            LinearBar(progress: archived ? 1 : progress, color: archived || status.daysPassed ? Theme.gold : Theme.blue, height: 10)

            Text("行動が自動化するまでの目安は約66日（個人差は18〜254日）。1日休んでも習慣化への影響は小さいとされています。（Lally et al., 2010）")
                .font(.system(size: 12))
                .foregroundStyle(Theme.subtext)
                .fixedSize(horizontal: false, vertical: true)

            if !archived {
                Divider()
                Text("卒業の条件").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                condition(status.daysPassed, "66日以上つづける", "\(status.days)日目")
                condition(status.ratePassed, "直近4週の達成率 80%以上", "\(Int((status.rate * 100).rounded()))%")
                condition(status.automaticityPassed, "自動化度が2回連続で5.5以上",
                          status.latestAutomaticity.map { String(format: "最新 %.1f", $0) } ?? "未チェック")

                if status.isReady {
                    PrimaryButton(title: "卒業する", leadingIcon: "medal.fill", kind: .gold, action: onGraduate)
                        .padding(.top, 4)
                }
            }
        }
        .cardStyle()
    }

    private func condition(_ ok: Bool, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(ok ? Theme.green : Color(hex: 0xC4C8CF))
            Text(label).font(.system(size: 14)).foregroundStyle(Theme.ink)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.subtext)
        }
    }
}
