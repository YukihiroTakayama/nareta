import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = true
    @AppStorage(SettingsKey.carryOver) private var carryOver = true
    @AppStorage(SettingsKey.notifications) private var notifications = true
    @AppStorage(SettingsKey.haptics) private var haptics = true

    @Query private var pools: [MonthlyRewardPool]
    @Query private var routines: [RoutineAnchor]
    @State private var exportURL: URL?
    @State private var alarmAuthorization: AlarmAuthorization = .unsupported
    @State private var confirmReset = false
    @State private var editingPool: MonthlyRewardPool?

    private var pool: MonthlyRewardPool? {
        let now = Date()
        return pools.first { $0.year == now.year && $0.month == now.month }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let pool {
                        Button { editingPool = pool } label: {
                            LabeledContent("\(pool.month)月のReward Pool") {
                                Text(pool.totalAmount.yen).monospacedDigit().foregroundStyle(Theme.ink).fontWeight(.semibold)
                            }
                        }
                        .foregroundStyle(Theme.ink)
                        LabeledContent("解放済み", value: pool.unlockedAmount.yen)
                        LabeledContent("使用済み", value: pool.spentAmount.yen)
                        if pool.carriedOverAmount > 0 {
                            LabeledContent("先月からの繰越", value: pool.carriedOverAmount.yen)
                        }
                    }
                    Toggle("未使用額を翌月に繰越", isOn: $carryOver)
                } header: {
                    Text("Reward Pool")
                } footer: {
                    Text(carryOver ? "月が変わったとき、使わなかった金額を翌月に持ち越します。" : "月が変わると、使わなかった金額はリセットされます。")
                }

                Section("なりたい自分") {
                    NavigationLink("Identityを管理") { IdentityManageView() }
                }

                Section {
                    Toggle("HealthKit", isOn: .constant(false)).disabled(true)
                    Toggle("Location", isOn: .constant(false)).disabled(true)
                } header: {
                    Text("連携")
                } footer: {
                    Text("HealthKit・位置情報による自動判定は今後のアップデートで対応予定です。")
                }

                Section {
                    Toggle("Notifications", isOn: $notifications)
                        .onChange(of: notifications) { _, on in
                            Task {
                                if on { await NotificationService.requestAuthorization() }
                                NotificationService.reschedule(context: context)
                            }
                        }
                    Toggle("Haptics", isOn: $haptics)
                } header: {
                    Text("通知・フィードバック")
                } footer: {
                    Text("朝8:00に今日の目標、21:00に未達の目標、日曜21:00に週のふりかえりをお知らせします。")
                }

                Section {
                    NavigationLink {
                        RoutineManageView()
                    } label: {
                        LabeledContent("ルーティン時刻", value: "\(routines.count)件")
                    }
                    alarmRow
                } header: {
                    Text("If-Then・アラーム")
                } footer: {
                    Text("「夕食 19:00」のようにいつもの時刻を登録しておくと、目標のトリガーに使えます。時刻を変えると、紐づく目標のアラームもまとめて変わります。")
                }

                Section("Data") {
                    NavigationLink("History") { HistoryView() }
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export JSON", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("すべてのデータをリセット", role: .destructive) { confirmReset = true }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                } footer: {
                    Text("NARETA — なりたい自分に、報酬を。\nこのアプリは実際の送金を行いません。")
                }
            }
            .tint(Theme.blue)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
            }
            .onAppear {
                exportURL = DataService.exportJSON(context: context)
                alarmAuthorization = AlarmService.authorization
            }
            .sheet(item: $editingPool) { PoolAmountEditorView(pool: $0) }
            .confirmationDialog("すべてのデータを削除しますか？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("リセットする", role: .destructive) {
                    DataService.resetAll(context: context)
                    NotificationService.reschedule(context: context)
                    dismiss()
                    hasOnboarded = false
                }
            } message: {
                Text("目標・ごほうび・履歴がすべて削除され、初回設定からやり直します。この操作は取り消せません。")
            }
        }
    }
}

extension SettingsView {
    @ViewBuilder
    var alarmRow: some View {
        switch alarmAuthorization {
        case .unsupported:
            LabeledContent("アラーム", value: "iOS 26以降で利用可")
        case .authorized:
            LabeledContent("アラーム", value: "許可済み")
        case .denied:
            Button("アラームが許可されていません（設定を開く）") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .notDetermined:
            Button("アラームを許可する") {
                Task {
                    await AlarmService.requestAuthorization()
                    alarmAuthorization = AlarmService.authorization
                    NotificationService.reschedule(context: context)
                }
            }
        }
    }
}

struct PoolAmountEditorView: View {
    let pool: MonthlyRewardPool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var amount = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("\(pool.month)月、自分にいくら使っていい？")
                    .font(.system(size: 24, weight: .heavy))

                HeroCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reward Pool").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                        MoneyText(amount: amount, size: 46).animation(.snappy, value: amount)
                        Text("解放済み \(pool.unlockedAmount.yen)").font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                    }
                }

                HStack(spacing: 8) {
                    ForEach(RewardPoolSetupView.presets, id: \.self) { value in
                        SelectChip(title: value.yen, selected: amount == value, style: .gold) { amount = value }
                    }
                }
                YenAmountField(amount: $amount)

                if amount < pool.unlockedAmount {
                    Label("解放済みの金額より小さくすると、解放済みも \(amount.yen) に調整されます。", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                }
                Spacer()
                PrimaryButton(title: "保存する", kind: .navy) {
                    RewardService(context: context).setTotal(amount, for: pool)
                    Haptics.success()
                    dismiss()
                }
                .disabled(amount < 1_000)
            }
            .padding(20)
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            }
            .onAppear { amount = pool.totalAmount }
        }
    }
}

struct IdentityManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Identity.createdAt) private var identities: [Identity]
    @Query private var goals: [Goal]

    @State private var showAdd = false
    @State private var newName = ""

    var body: some View {
        List {
            Section {
                ForEach(identities) { identity in
                    HStack(spacing: 12) {
                        Image(systemName: identity.icon ?? IdentityPreset.customIcon)
                            .foregroundStyle(Color(hexString: identity.colorHex))
                            .frame(width: 32, height: 32)
                            .background(Color(hexString: identity.colorHex).opacity(0.12), in: Circle())
                        Text(identity.name)
                        Spacer()
                        Text("\(goals.filter { $0.identityId == identity.id }.count)個の目標")
                            .font(.footnote)
                            .foregroundStyle(Theme.subtext)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        let identity = identities[index]
                        goals.filter { $0.identityId == identity.id }.forEach { $0.identityId = nil }
                        context.delete(identity)
                    }
                    try? context.save()
                }
            } footer: {
                Text("削除しても目標は残ります。")
            }

            Section("おすすめ") {
                ForEach(IdentityPreset.all.filter { preset in !identities.contains { $0.name == preset.name } }) { preset in
                    Button {
                        context.insert(Identity(name: preset.name, icon: preset.icon, colorHex: preset.colorHex))
                        try? context.save()
                    } label: {
                        Label(preset.name, systemImage: "plus.circle.fill")
                    }
                }
            }
        }
        .navigationTitle("なりたい自分")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { newName = ""; showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("なりたい自分を追加", isPresented: $showAdd) {
            TextField("例: 早起きしたい", text: $newName)
            Button("追加") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !identities.contains(where: { $0.name == name }) else { return }
                context.insert(Identity(
                    name: name,
                    icon: IdentityPreset.customIcon,
                    colorHex: IdentityPreset.customColors[identities.count % IdentityPreset.customColors.count]
                ))
                try? context.save()
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}
