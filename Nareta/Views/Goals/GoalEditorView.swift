import SwiftData
import SwiftUI

struct GoalEditorView: View {
    let goal: Goal?
    var suggestion: GoalSuggestion?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Identity.createdAt) private var identities: [Identity]
    @Query(sort: \RoutineAnchor.sortOrder) private var routines: [RoutineAnchor]

    @State private var title = ""
    @State private var note = ""
    @State private var triggerMode: TriggerMode = .time
    @State private var triggerTime = Calendar.nareta.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var routineId: UUID?
    @State private var triggerOffset = 0
    @State private var alertStyle: AlertStyle = .alarm
    @State private var outcome = ""
    @State private var obstacle = ""
    @State private var obstaclePlan = ""
    @State private var identityId: UUID?
    @State private var frequency: FrequencyType = .daily
    @State private var targetCount = 3
    @State private var weekdays: Set<Int> = [2, 4, 6]
    @State private var duration = 0
    @State private var reward = 200
    @State private var verification: VerificationType = .manual
    @State private var didLoad = false

    @State private var showAddIdentity = false
    @State private var newIdentityName = ""
    @State private var comingSoon: VerificationType?

    private static let quickAmounts = [50, 100, 200, 500, 1_000]
    private static let durations = [0, 10, 15, 20, 30, 45, 60, 90, 120]
    private static let titleLimit = 30

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && reward > 0
            && (frequency != .weekdays || !weekdays.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                suggestionBanner
                titleSection
                ifThenSection
                identitySection
                frequencySection
                rewardSection
                woopSection
                verificationSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(goal == nil ? "New Goal" : "Edit Goal").font(.system(size: 19, weight: .bold))
                    Text("なりたい自分に、一歩ずつ").font(.system(size: 12)).foregroundStyle(Theme.subtext)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                PrimaryButton(title: goal == nil ? "目標を作成" : "保存する", icon: "arrow.right", kind: .navy, action: save)
                    .disabled(!isValid)
            }
        }
        .onAppear(perform: load)
        .alert("なりたい自分を追加", isPresented: $showAddIdentity) {
            TextField("例: 早起きしたい", text: $newIdentityName)
            Button("追加", action: addIdentity)
            Button("キャンセル", role: .cancel) {}
        }
        .alert("\(comingSoon?.label ?? "") は近日対応", isPresented: Binding(get: { comingSoon != nil }, set: { if !$0 { comingSoon = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("MVPでは手動での記録のみ対応しています。")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var suggestionBanner: some View {
        if let suggestion, goal == nil {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "medal.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.goldGradient)
                    .frame(width: 40, height: 40)
                    .background(Theme.gold.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("「\(suggestion.sourceTitle)」卒業おめでとう")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("月およそ\(suggestion.monthlyEstimate.yen)分の報酬を、次の目標に回せます。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subtext)
                }
                Spacer(minLength: 0)
            }
            .cardStyle(background: Color(hex: 0xFFF9EA))
        }
    }

    private var titleSection: some View {
        EditorSection(title: "タイトル", trailing: "\(title.count)/\(Self.titleLimit)") {
            VStack(spacing: 10) {
                TextField("例: ジムに行く", text: $title)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(Theme.chip.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: title) { _, value in
                        if value.count > Self.titleLimit { title = String(value.prefix(Self.titleLimit)) }
                    }
                TextField("ひとこと（任意） 例: 理想の自分に近づく", text: $note)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Theme.chip.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var ifThenSection: some View {
        EditorSection(title: "If-Then（いつやる？）", subtitle: "やる時刻を決めておくと、その時間にアラームで知らせます") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("トリガー", selection: $triggerMode) {
                    ForEach(TriggerMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: triggerMode) { _, mode in
                    if mode == .routine && routineId == nil { routineId = routines.first?.id }
                }

                switch triggerMode {
                case .none:
                    Text("時刻を決めない目標は、Todayに表示されるだけです。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subtext)
                case .time:
                    HStack(spacing: 10) {
                        ifBadge
                        DatePicker("時刻", selection: $triggerTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                        Text("になったら").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                    }
                case .routine:
                    VStack(alignment: .leading, spacing: 10) {
                        FlowLayout(spacing: 8) {
                            ForEach(routines) { routine in
                                SelectChip(
                                    title: "\(routine.name) \(TriggerService.timeText(routine.minutes))",
                                    icon: routine.icon,
                                    selected: routineId == routine.id,
                                    showsCheck: false
                                ) { routineId = routine.id }
                            }
                        }
                        HStack(spacing: 8) {
                            ifBadge
                            Menu {
                                Picker("タイミング", selection: $triggerOffset) {
                                    ForEach(TriggerService.offsets, id: \.self) { Text(TriggerService.offsetText($0)).tag($0) }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(TriggerService.offsetText(triggerOffset))
                                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11))
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(Theme.chip, in: Capsule())
                            }
                            Spacer()
                            NavigationLink {
                                RoutineManageView()
                            } label: {
                                Label("時刻を編集", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                    }
                }

                if let label = previewTriggerLabel {
                    HStack(spacing: 6) {
                        Text("\(label)になったら").fontWeight(.bold)
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                        Text(title.isEmpty ? "（目標）" : title).fontWeight(.bold)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("知らせ方").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.ink)
                        HStack(spacing: 6) {
                            ForEach(AlertStyle.allCases) { style in
                                SelectChip(title: style.label, icon: style.icon, selected: alertStyle == style, showsCheck: false) {
                                    alertStyle = style
                                }
                            }
                        }
                        Text(alertStyleCaption)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var ifBadge: some View {
        Text("If")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 34, height: 28)
            .background(Theme.blue, in: Capsule())
    }

    private var triggerMinutesValue: Int? {
        switch triggerMode {
        case .none:
            return nil
        case .time:
            let components = Calendar.nareta.dateComponents([.hour, .minute], from: triggerTime)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        case .routine:
            guard let routine = routines.first(where: { $0.id == routineId }) else { return nil }
            return TriggerService.normalize(routine.minutes + triggerOffset)
        }
    }

    private var previewTriggerLabel: String? {
        guard let minutes = triggerMinutesValue else { return nil }
        if triggerMode == .routine, let routine = routines.first(where: { $0.id == routineId }) {
            let suffix = triggerOffset == 0 ? "" : "の" + TriggerService.offsetText(triggerOffset)
            return "\(routine.name)\(suffix)（\(TriggerService.timeText(minutes))）"
        }
        return TriggerService.timeText(minutes)
    }

    private var alertStyleCaption: String {
        switch alertStyle {
        case .alarm:
            AlarmService.isSupported
                ? "マナーモード中でも、時計のアラームと同じように鳴ります。アラームの「達成した」ボタンで、そのまま記録できます。"
                : "アラームはiOS 26以降で使えます。このiPhoneでは通知でお知らせします。"
        case .notification:
            "通知でお知らせします（マナーモード中は音が鳴りません）。"
        case .none:
            "時刻は目安として表示するだけで、お知らせはしません。"
        }
    }

    private var identitySection: some View {
        EditorSection(title: "どんな自分になりたいですか？", subtitle: "目標の背景にある、なりたい自分を選びましょう") {
            FlowLayout(spacing: 8) {
                ForEach(identities) { identity in
                    SelectChip(title: identity.name, selected: identityId == identity.id) {
                        identityId = identityId == identity.id ? nil : identity.id
                    }
                }
                SelectChip(title: "追加", icon: "plus", selected: false) {
                    newIdentityName = ""
                    showAddIdentity = true
                }
            }
        }
    }

    private var frequencySection: some View {
        EditorSection(title: "実施の頻度", subtitle: "どのくらいのペースで取り組みますか？") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Menu {
                        Picker("頻度", selection: $frequency) {
                            ForEach(FrequencyType.allCases) { Text($0.label).tag($0) }
                        }
                    } label: {
                        menuLabel(icon: "calendar", text: frequencySummary)
                    }
                    Menu {
                        Picker("時間", selection: $duration) {
                            ForEach(Self.durations, id: \.self) { Text($0 == 0 ? "指定なし" : "\($0)分").tag($0) }
                        }
                    } label: {
                        menuLabel(icon: "clock", text: duration == 0 ? "時間なし" : "\(duration)分")
                    }
                }

                switch frequency {
                case .weekly, .monthly:
                    Stepper(value: $targetCount, in: 1...(frequency == .weekly ? 7 : 31)) {
                        Text("\(frequency == .weekly ? "週" : "月")に \(targetCount) 回")
                            .font(.system(size: 16, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 4)
                case .weekdays:
                    HStack(spacing: 6) {
                        ForEach(Weekday.mondayFirst, id: \.self) { day in
                            let on = weekdays.contains(day)
                            Button {
                                if on { weekdays.remove(day) } else { weekdays.insert(day) }
                            } label: {
                                Text(Weekday.label(day))
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .foregroundStyle(on ? .white : Theme.ink)
                                    .background(on ? Theme.navy : Theme.chip, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                default:
                    EmptyView()
                }
            }
        }
    }

    private var frequencySummary: String {
        switch frequency {
        case .weekly: "週\(targetCount)回"
        case .monthly: "月\(targetCount)回"
        default: frequency.label
        }
    }

    private func menuLabel(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Theme.subtext)
            Text(text).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.subtext)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line))
    }

    private var rewardSection: some View {
        EditorSection(title: "リワード（達成時のごほうび）", subtitle: "目標を達成したときに、いくら受け取りますか？") {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Image(systemName: "gift")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 56, height: 56)
                        .background(Theme.gold.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("達成時のリワード").font(.system(size: 13)).foregroundStyle(Theme.subtext)
                        Text(reward.signedYen)
                            .font(.system(size: 36, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.goldGradient)
                            .contentTransition(.numericText(value: Double(reward)))
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        stepButton("plus") { reward = min(100_000, reward + 50) }
                        stepButton("minus") { reward = max(10, reward - 50) }
                    }
                }
                .padding(14)
                .background(Color(hex: 0xFFF8E6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.gold.opacity(0.35)))
                .animation(.snappy, value: reward)

                HStack(spacing: 6) {
                    ForEach(Self.quickAmounts, id: \.self) { amount in
                        Button {
                            Haptics.tap()
                            reward = amount
                        } label: {
                            Text(amount.yen)
                                .font(.system(size: 14, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .foregroundStyle(reward == amount ? .white : Theme.ink)
                                .background(reward == amount ? Theme.gold : Theme.chip, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.goldDeep)
                .frame(width: 32, height: 26)
                .background(.white, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var woopSection: some View {
        EditorSection(title: "障害への備え（WOOP）", subtitle: "うまくいかない場面を先に想像して、対策を決めておきます（任意）") {
            VStack(alignment: .leading, spacing: 12) {
                labeledField("Outcome", "達成できたら、どうなる？", "例: 体が軽くなって自信が持てる", $outcome)
                labeledField("Obstacle", "邪魔になりそうなことは？", "例: 残業で疲れて帰りたくなる", $obstacle)
                labeledField("Plan", "そのとき、どうする？", "例: ウェアを持って出社し、10分だけでも行く", $obstaclePlan)

                if !obstacle.isEmpty && !obstaclePlan.isEmpty {
                    Text("もし「\(obstacle)」なら → 「\(obstaclePlan)」")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Text("願いと障害をセットで考える「メンタル・コントラスティング」（Oettingen）にもとづく手法です。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.subtext)
            }
        }
    }

    private func labeledField(_ tag: String, _ label: String, _ placeholder: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(tag).font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.goldDeep)
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            }
            TextField(placeholder, text: text, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...3)
                .padding(12)
                .background(Theme.chip.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var verificationSection: some View {
        EditorSection(title: "判定方法", subtitle: "目標の達成をどのように判定しますか？") {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(VerificationType.allCases) { type in
                        Button {
                            if type.isAvailable { verification = type } else { comingSoon = type }
                        } label: {
                            VStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Image(systemName: verification == type ? "checkmark.circle.fill" : type.icon)
                                    Text(type.label).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(verification == type ? .white : Theme.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(verification == type ? Theme.navy : Theme.chip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                Text(type.isAvailable ? type.caption : "近日対応")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.subtext)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .opacity(type.isAvailable ? 1 : 0.55)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Label("達成するとReward Poolから解放されます", systemImage: "info.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Actions

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let goal {
            title = goal.title
            note = goal.note
            if let goalRoutineId = goal.routineId {
                triggerMode = .routine
                routineId = goalRoutineId
                triggerOffset = goal.triggerOffset
            } else if goal.triggerMinutes >= 0 {
                triggerMode = .time
                triggerTime = TriggerService.date(goal.triggerMinutes, on: Date())
            } else {
                triggerMode = .none
            }
            alertStyle = goal.alertStyleValue
            outcome = goal.wishOutcome
            obstacle = goal.obstacle
            obstaclePlan = goal.obstaclePlan
            identityId = goal.identityId
            frequency = goal.frequency
            targetCount = max(1, goal.targetCount)
            weekdays = Set(goal.weekdays)
            duration = goal.durationMinutes
            reward = goal.rewardAmount
            verification = goal.verification
        } else if let suggestion {
            identityId = suggestion.identityId ?? identities.first?.id
            reward = suggestion.reward
        } else {
            identityId = identities.first?.id
        }
    }

    private func addIdentity() {
        let name = newIdentityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let existing = identities.first(where: { $0.name == name }) {
            identityId = existing.id
            return
        }
        let preset = IdentityPreset.find(name)
        let identity = Identity(
            name: name,
            icon: preset?.icon ?? IdentityPreset.customIcon,
            colorHex: preset?.colorHex ?? IdentityPreset.customColors[identities.count % IdentityPreset.customColors.count]
        )
        context.insert(identity)
        try? context.save()
        identityId = identity.id
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let count = (frequency == .weekly || frequency == .monthly) ? targetCount : 1
        let days = frequency == .weekdays ? Array(weekdays).sorted() : []

        let target: Goal
        if let goal {
            target = goal
            target.title = trimmed
            target.identityId = identityId
            target.frequencyType = frequency.rawValue
            target.targetCount = count
            target.weekdays = days
            target.durationMinutes = duration
            target.rewardAmount = reward
            target.verificationType = verification.rawValue
        } else {
            target = Goal(
                title: trimmed, rewardAmount: reward, frequency: frequency, targetCount: count,
                weekdays: days, durationMinutes: duration, identityId: identityId, verification: verification
            )
            context.insert(target)
        }
        target.note = note
        switch triggerMode {
        case .none:
            target.routineId = nil
            target.triggerMinutes = -1
            target.triggerOffset = 0
        case .time:
            target.routineId = nil
            target.triggerMinutes = triggerMinutesValue ?? -1
            target.triggerOffset = 0
        case .routine:
            target.routineId = routineId
            target.triggerOffset = triggerOffset
            target.triggerMinutes = triggerMinutesValue ?? -1
        }
        target.alertStyle = alertStyle.rawValue
        target.wishOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
        target.obstacle = obstacle.trimmingCharacters(in: .whitespacesAndNewlines)
        target.obstaclePlan = obstaclePlan.trimmingCharacters(in: .whitespacesAndNewlines)

        try? context.save()
        Haptics.success()
        let needsAlarm = triggerMode != .none && alertStyle == .alarm
        Task {
            if needsAlarm { await AlarmService.requestAuthorization() }
            NotificationService.reschedule(context: context)
        }
        dismiss()
    }
}

enum TriggerMode: String, CaseIterable, Identifiable {
    case none, time, routine
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "なし"
        case .time: "時刻"
        case .routine: "ルーティン"
        }
    }
}
