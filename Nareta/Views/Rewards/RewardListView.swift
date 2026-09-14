import SwiftData
import SwiftUI

struct RewardListView: View {
    @Query(sort: [SortDescriptor(\Reward.priority), SortDescriptor(\Reward.price)]) private var rewards: [Reward]
    @Query private var pools: [MonthlyRewardPool]

    @State private var showEditor = false
    @State private var showSettings = false
    @State private var showPurchased = false

    private var pool: MonthlyRewardPool? {
        let now = Date()
        return pools.first { $0.year == now.year && $0.month == now.month }
    }

    var body: some View {
        let available = pool?.availableAmount ?? 0
        let active = rewards.filter { !$0.isPurchased }
        let purchased = rewards.filter(\.isPurchased).sorted { ($0.purchasedAt ?? .distantPast) > ($1.purchasedAt ?? .distantPast) }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Rewards").font(.system(size: 34, weight: .heavy)).foregroundStyle(Theme.ink)
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 42, height: 42)
                                .background(Theme.chip, in: Circle())
                        }
                    }
                    .padding(.top, 8)

                    HeroCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("現在使える金額").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
                            MoneyText(amount: available, size: 54)
                            HStack(spacing: 18) {
                                Text("今月のPool \((pool?.totalAmount ?? 0).yen)")
                                Text("使用済み \((pool?.spentAmount ?? 0).yen)")
                            }
                            .font(.system(size: 14))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.trailing, 80)
                            HStack(spacing: 12) {
                                GoldProgressBar(progress: pool?.progress ?? 0)
                                PercentLabel(progress: pool?.progress ?? 0)
                            }
                            .padding(.trailing, 96)
                            .padding(.top, 4)
                        }
                    }

                    HStack {
                        Text("ごほうび一覧").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(active.count)件のごほうび").font(.system(size: 14)).foregroundStyle(Theme.subtext)
                    }
                    .padding(.top, 4)

                    if active.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "gift").font(.system(size: 32)).foregroundStyle(Theme.subtext)
                            Text("欲しいものを登録しよう").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                            Text("目標を達成するたびに、ごほうびに近づいていきます。")
                                .font(.system(size: 13)).foregroundStyle(Theme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .cardStyle(padding: 28)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(active) { reward in
                                NavigationLink(value: reward) {
                                    RewardRow(reward: reward, available: available)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !purchased.isEmpty {
                        Button {
                            withAnimation(.snappy) { showPurchased.toggle() }
                        } label: {
                            HStack {
                                Text("受け取り済み（\(purchased.count)）").font(.system(size: 16, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.down").rotationEffect(.degrees(showPurchased ? 180 : 0))
                            }
                            .foregroundStyle(Theme.subtext)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        if showPurchased {
                            VStack(spacing: 12) {
                                ForEach(purchased) { reward in
                                    NavigationLink(value: reward) {
                                        RewardRow(reward: reward, available: available)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                BottomBar {
                    Button { showEditor = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Theme.navy)
                                .frame(width: 28, height: 28)
                                .background(.white, in: Circle())
                            Text("ごほうびを追加")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(kind: .navy))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Reward.self) { RewardDetailView(reward: $0) }
            .sheet(isPresented: $showEditor) { RewardEditorView(reward: nil) }
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }
}
