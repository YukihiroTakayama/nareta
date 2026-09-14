import SwiftData
import SwiftUI

struct RewardDetailView: View {
    let reward: Reward

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var pools: [MonthlyRewardPool]

    @State private var showPurchase = false
    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var isDeleted = false

    private var available: Int {
        let now = Date()
        return pools.first { $0.year == now.year && $0.month == now.month }?.availableAmount ?? 0
    }

    var body: some View {
        if isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        let available = available
        let progress = reward.price > 0 ? min(1, Double(max(0, available)) / Double(reward.price)) : 1
        let remaining = max(0, reward.price - available)
        let status = RewardStatus(reward: reward, available: available)

        return ScrollView {
            VStack(spacing: 16) {
                RewardThumbnail(reward: reward, size: .infinity, height: 230, radius: 22)

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        TagChip(text: reward.categoryValue.label, color: Theme.subtext)
                        TagChip(text: "優先度 \(reward.priorityValue.label)", color: Theme.subtext)
                        RewardStatusBadge(status: status)
                    }
                    Text(reward.name)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                    if !reward.note.isEmpty {
                        Text(reward.note).font(.system(size: 14)).foregroundStyle(Theme.subtext)
                    }
                    Text(reward.price.yen)
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                }

                if reward.isPurchased {
                    VStack(spacing: 8) {
                        Image(systemName: "gift.fill").font(.system(size: 32)).foregroundStyle(Theme.gold)
                        Text("ごほうびを受け取りました").font(.system(size: 17, weight: .bold))
                        if let date = reward.purchasedAt {
                            Text(date.japaneseDayText).font(.system(size: 13)).foregroundStyle(Theme.subtext)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle(padding: 24)
                } else {
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().stroke(Theme.chip, lineWidth: 12)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(status == .claimable ? Theme.green : Theme.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text("\(Int((progress * 100).rounded()))%")
                                    .font(.system(size: 26, weight: .heavy))
                                    .monospacedDigit()
                                Text("Progress").font(.system(size: 11)).foregroundStyle(Theme.subtext)
                            }
                        }
                        .frame(width: 118, height: 118)

                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("使える").font(.system(size: 13)).foregroundStyle(Theme.subtext)
                                Text(available.yen).font(.system(size: 22, weight: .bold)).monospacedDigit()
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("あと").font(.system(size: 13)).foregroundStyle(Theme.subtext)
                                Text(remaining == 0 ? "達成！" : remaining.yen)
                                    .font(.system(size: 22, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(remaining == 0 ? Theme.green : Theme.ink)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .cardStyle(padding: 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("編集", systemImage: "pencil") { showEditor = true }
                    Button("削除", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !reward.isPurchased {
                BottomBar {
                    VStack(spacing: 6) {
                        PrimaryButton(title: "これを買う", leadingIcon: "gift.fill", kind: status == .claimable ? .gold : .navy) {
                            showPurchase = true
                        }
                        .disabled(status != .claimable)
                        if status != .claimable {
                            Text("あと \(remaining.yen) 解放すると受け取れます")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.subtext)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPurchase) {
            RewardPurchaseView(reward: reward, available: available)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showEditor) { RewardEditorView(reward: reward) }
        .confirmationDialog("「\(reward.name)」を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除する", role: .destructive, action: delete)
        }
    }

    private func delete() {
        isDeleted = true
        let target = reward
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            context.delete(target)
            try? context.save()
        }
    }
}
