import SwiftData
import SwiftUI

/// 自動化度チェック（SRBAI: Gardner et al., 2012 をもとにした4問・7段階）
struct AutomaticityCheckView: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var scores = Array(repeating: 0, count: AutomaticityCheck.questions.count)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("「\(goal.title)」は…")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text("この1週間をふりかえって、どれくらい当てはまりますか？\n1 = まったくそう思わない ／ 7 = とてもそう思う")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.subtext)
                            .lineSpacing(3)
                    }
                    .padding(.bottom, 4)

                    ForEach(AutomaticityCheck.questions.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AutomaticityCheck.questions[index])
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            HStack(spacing: 6) {
                                ForEach(1...7, id: \.self) { value in
                                    let selected = scores[index] == value
                                    Button {
                                        Haptics.tap()
                                        scores[index] = value
                                    } label: {
                                        Text("\(value)")
                                            .font(.system(size: 16, weight: .bold))
                                            .monospacedDigit()
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .foregroundStyle(selected ? .white : Theme.ink)
                                            .background(selected ? Theme.navy : Theme.chip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            HStack {
                                Text("そう思わない")
                                Spacer()
                                Text("とてもそう思う")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.subtext)
                        }
                        .cardStyle()
                    }

                    Text("Self-Report Behavioural Automaticity Index（Gardner et al., 2012）をもとにした質問です。2回連続で平均5.5以上になると、卒業の条件の1つを満たします。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.subtext)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Theme.background)
            .navigationTitle("自動化度チェック")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                BottomBar {
                    PrimaryButton(title: "記録する", kind: .navy) {
                        RewardService(context: context).recordAutomaticity(goal, scores: scores)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(scores.contains(0))
                }
            }
        }
    }
}
