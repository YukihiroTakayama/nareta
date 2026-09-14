import SwiftData
import SwiftUI

struct HistoryView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case earned = "Earned", spent = "Spent", all = "All"
        var id: String { rawValue }
    }

    var showsCloseButton = false

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RewardTransaction.createdAt, order: .reverse) private var transactions: [RewardTransaction]
    @State private var filter: Filter = .all

    var body: some View {
        let items = transactions.filter {
            switch filter {
            case .earned: $0.typeValue == .earn
            case .spent: $0.typeValue == .spend
            case .all: true
            }
        }
        let groups = Dictionary(grouping: items) { $0.createdAt.startOfDay }
            .sorted { $0.key > $1.key }
        let monthStart = Date().startOfMonth
        let monthTx = transactions.filter { $0.createdAt >= monthStart }
        let earned = monthTx.filter { $0.typeValue == .earn }.reduce(0) { $0 + $1.amount }
        let spent = monthTx.filter { $0.typeValue == .spend }.reduce(0) { $0 + $1.amount }

        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    summaryTile("今月の獲得", earned.signedYen, Theme.green)
                    summaryTile("今月の使用", spent == 0 ? "¥0" : spent.yen, Theme.ink)
                }

                Picker("種類", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if groups.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock").font(.system(size: 30)).foregroundStyle(Theme.subtext)
                        Text("まだ履歴はありません").font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .cardStyle(padding: 28)
                }

                ForEach(groups, id: \.key) { day, rows in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(day.japaneseDayText).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.subtext)
                            Spacer()
                            Text(rows.reduce(0) { $0 + $1.amount }.signedYen)
                                .font(.system(size: 13, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.subtext)
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, tx in
                                if index > 0 { Divider().padding(.leading, 64) }
                                row(tx)
                            }
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
        }
    }

    private func summaryTile(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.subtext)
            Text(value).font(.system(size: 22, weight: .heavy)).monospacedDigit().foregroundStyle(color)
        }
        .cardStyle(padding: 14)
    }

    private func row(_ tx: RewardTransaction) -> some View {
        let (icon, color): (String, Color) = switch tx.typeValue {
        case .earn: ("yensign.circle.fill", Theme.gold)
        case .spend: ("gift.fill", Theme.blue)
        case .adjustment: ("slider.horizontal.3", Theme.subtext)
        }
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text("\(tx.createdAt.monthDayText) \(tx.createdAt.timeText)").font(.system(size: 12)).foregroundStyle(Theme.subtext)
            }
            Spacer()
            Text(tx.amount.signedYen)
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tx.amount >= 0 ? Theme.green : Theme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
