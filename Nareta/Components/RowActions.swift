import SwiftUI

extension View {
    /// List内でカードをそのまま並べるための行スタイル
    func cardRow(top: CGFloat = 5, bottom: CGFloat = 5) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    func goalDeleteDialog(_ goal: Binding<Goal?>, onDelete: @escaping (Goal) -> Void) -> some View {
        confirmationDialog(
            "この目標を削除しますか？",
            isPresented: Binding(get: { goal.wrappedValue != nil }, set: { if !$0 { goal.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: goal.wrappedValue
        ) { target in
            Button("「\(target.title)」を削除", role: .destructive) { onDelete(target) }
        } message: { _ in
            Text("解放したお金と履歴はそのまま残ります。")
        }
    }

    func rewardDeleteDialog(_ reward: Binding<Reward?>, onDelete: @escaping (Reward) -> Void) -> some View {
        confirmationDialog(
            "このごほうびを削除しますか？",
            isPresented: Binding(get: { reward.wrappedValue != nil }, set: { if !$0 { reward.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: reward.wrappedValue
        ) { target in
            Button("「\(target.name)」を削除", role: .destructive) { onDelete(target) }
        } message: { target in
            Text(target.isPurchased ? "受け取りの履歴はそのまま残ります。" : "登録したごほうびが一覧から消えます。")
        }
    }
}

/// 目標行: 右スワイプで達成 / 左スワイプで編集・停止・削除 / 長押しメニュー
struct GoalRowActions: ViewModifier {
    let goal: Goal
    let canComplete: Bool
    let onComplete: () -> Void
    let onEdit: () -> Void
    let onTogglePause: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if canComplete {
                    Button(action: onComplete) { Label("達成", systemImage: "checkmark") }
                        .tint(Theme.green)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(action: onDelete) { Label("削除", systemImage: "trash") }
                    .tint(Theme.red)
                Button(action: onEdit) { Label("編集", systemImage: "pencil") }
                    .tint(Theme.blue)
                Button(action: onTogglePause) {
                    Label(goal.isActive ? "停止" : "再開", systemImage: goal.isActive ? "pause.fill" : "play.fill")
                }
                .tint(.orange)
            }
            .contextMenu {
                if canComplete {
                    Button("達成する", systemImage: "checkmark.circle", action: onComplete)
                }
                Button("編集", systemImage: "pencil", action: onEdit)
                Button(goal.isActive ? "一時停止" : "再開", systemImage: goal.isActive ? "pause" : "play", action: onTogglePause)
                Divider()
                Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
            }
    }
}

/// ごほうび行: 右スワイプで受け取る / 左スワイプで編集・削除 / 長押しメニュー
struct RewardRowActions: ViewModifier {
    let canPurchase: Bool
    let onPurchase: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if canPurchase {
                    Button(action: onPurchase) { Label("受け取る", systemImage: "gift.fill") }
                        .tint(Theme.gold)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(action: onDelete) { Label("削除", systemImage: "trash") }
                    .tint(Theme.red)
                Button(action: onEdit) { Label("編集", systemImage: "pencil") }
                    .tint(Theme.blue)
            }
            .contextMenu {
                if canPurchase {
                    Button("受け取る", systemImage: "gift", action: onPurchase)
                }
                Button("編集", systemImage: "pencil", action: onEdit)
                Divider()
                Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
            }
    }
}
