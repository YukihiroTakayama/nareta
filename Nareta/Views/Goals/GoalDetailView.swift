import SwiftData
import SwiftUI

struct GoalDetailView: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query private var allCompletions: [GoalCompletion]
    @Query private var identities: [Identity]
    @Query private var allChecks: [AutomaticityCheck]
    @Query private var allFreezes: [StreakFreeze]
    @Query private var routines: [RoutineAnchor]

    @State private var displayedMonth = Date().startOfMonth
    @State private var confirmDelete = false
    @State private var isDeleted = false
    @State private var showEditor = false
    @State private var showCheck = false
    @State private var showGraduation = false
    @State private var calendarDay: Date?

    var body: some View {
        if isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        let completions = allCompletions.filter { $0.goalId == goal.id }
        let checks = allChecks.filter { $0.goalId == goal.id }
        let goalFreezes = allFreezes.filter { $0.goalId == goal.id }
        let frozen = Set(goalFreezes.map(\.date))
        let identity = identities.first { $0.id == goal.identityId }
        let isArchived = goal.archivedAt != nil
        let canComplete = GoalService.canComplete(goal, completions)
        let completedToday = GoalService.isCompletedToday(completions)
        let bonus = canComplete ? HabitService.comebackBonus(goal, completions, frozenDays: frozen) : 0
        let freezableDay = HabitService.freezableDay(goal, completions, goalFreezes: goalFreezes, allFreezes: allFreezes)
        let freezesLeft = HabitService.freezesPerMonth - HabitService.freezesUsed(allFreezes)
        let graduation = HabitService.graduationStatus(goal, completions, checks)

        return ScrollView {
            VStack(spacing: 14) {
                hero(identity: identity, isArchived: isArchived)

                if let archivedAt = goal.archivedAt {
                    HabitNoticeCard(
                        icon: "medal.fill", color: Theme.gold, title: "卒業した習慣です",
                        message: "\(archivedAt.japaneseDayText)に卒業しました。報酬とTodayの対象から外れています。崩れてきたら、いつでも戻せます。",
                        buttonTitle: "習慣に戻す", action: restore
                    )
                }

                if bonus > 0 {
                    HabitNoticeCard(
                        icon: "arrow.uturn.up", color: Theme.gold, title: "おかえりなさい！ 今日は復帰ボーナス",
                        message: "間が空いても、戻ってきたことに価値があります。今日達成すると \(goal.rewardAmount.signedYen) に \(bonus.signedYen) を上乗せして解放します。"
                    )
                }

                if let day = freezableDay {
                    HabitNoticeCard(
                        icon: "snowflake", color: Color(hex: 0x38BDF8), title: "\(day.monthDayText) の連続記録を守れます",
                        message: "Streak Freezeを使うと、休んだ日も連続記録が途切れません（今月あと\(freezesLeft)回）。\(bonus > 0 ? "使うと今日の復帰ボーナスは付きません。" : "1回の失敗であきらめないための仕組みです。")",
                        buttonTitle: "Freezeを使う"
                    ) {
                        RewardService(context: context).applyFreeze(goal, day: day)
                        Haptics.success()
                    }
                }

                if HabitService.needsAutomaticityCheck(goal, checks) {
                    HabitNoticeCard(
                        icon: "brain.head.profile", color: Color(hex: 0x8B5CF6), title: "今週の自動化度チェック",
                        message: "「考えずにできているか」を4問でふりかえります。30秒で終わります。",
                        buttonTitle: "チェックする"
                    ) { showCheck = true }
                }

                if goal.hasPlan {
                    GoalPlanCard(goal: goal, triggerLabel: TriggerService.label(for: goal, routines: routines))
                }

                if HabitService.isGraduatable(goal) || isArchived {
                    HabitMeterCard(goal: goal, status: graduation) { showGraduation = true }
                }

                statGrid(completions: completions, frozen: frozen)

                VStack(alignment: .leading, spacing: 6) {
                    MonthCalendarView(
                        month: $displayedMonth,
                        markedDays: Set(completions.map { $0.completedAt.startOfDay }),
                        frozenDays: frozen,
                        onTapDay: { day in
                            if isEditableDay(day, completions: completions) { calendarDay = day }
                        }
                    )
                    if !isArchived {
                        Label("\(GoalService.backfillDays)日前までの日付をタップすると、記録し忘れた分の追加や取り消しができます", systemImage: "hand.tap")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.subtext)
                            .padding(.horizontal, 4)
                    }
                }

                if !isArchived {
                    actions(completions: completions, canComplete: canComplete, completedToday: completedToday)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("編集", systemImage: "pencil") { showEditor = true }
                    if isArchived {
                        Button("習慣に戻す", systemImage: "arrow.uturn.backward", action: restore)
                    } else {
                        Button(goal.isActive ? "一時停止" : "再開", systemImage: goal.isActive ? "pause" : "play") {
                            RewardService(context: context).togglePause(goal)
                            NotificationService.reschedule(context: context)
                        }
                        if graduation.isReady {
                            Button("卒業する", systemImage: "medal") { showGraduation = true }
                        }
                    }
                    Divider()
                    Button("削除", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "記録を編集",
            isPresented: Binding(get: { calendarDay != nil }, set: { if !$0 { calendarDay = nil } }),
            titleVisibility: .visible,
            presenting: calendarDay
        ) { day in
            let goalCompletions = allCompletions.filter { $0.goalId == goal.id }
            if let existing = goalCompletions.first(where: { $0.completedAt.isSameDay(as: day) }) {
                Button("\(day.monthDayText)の達成を取り消す（-\(existing.rewardAmount.yen)）", role: .destructive) {
                    RewardService(context: context).undoCompletion(id: existing.id)
                    NotificationService.reschedule(context: context)
                    Haptics.tap()
                }
            } else if day.isSameDay(as: Date()) {
                Button("今日達成した（\(goal.rewardAmount.signedYen)）") {
                    appState.complete(goal, context: context)
                }
            } else {
                Button("\(day.monthDayText)を達成として記録する（\(goal.rewardAmount.signedYen)）") {
                    appState.backfill(goal, day: day, context: context)
                }
            }
        } message: { day in
            Text(day.japaneseDayText)
        }
        .navigationDestination(isPresented: $showEditor) { GoalEditorView(goal: goal) }
        .sheet(isPresented: $showCheck) { AutomaticityCheckView(goal: goal) }
        .sheet(isPresented: $showGraduation) {
            GraduationView(goal: goal, completions: completions) {
                dismiss()
                appState.suggestNextGoal(after: goal)
            }
        }
        .confirmationDialog("「\(goal.title)」を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除する", role: .destructive, action: delete)
        } message: {
            Text("解放したお金と履歴はそのまま残ります。")
        }
    }

    // MARK: - Parts

    private func hero(identity: Identity?, isArchived: Bool) -> some View {
        HeroCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    if let identity {
                        TagChip(text: identity.name, color: Color(hexString: identity.colorHex).mix(with: .white, by: 0.35))
                    }
                    Text(goal.frequencyLabel).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                    if isArchived {
                        TagChip(text: "卒業済み", color: Theme.goldLight)
                    } else if !goal.isActive {
                        TagChip(text: "一時停止中", color: .orange)
                    }
                }
                Text(goal.title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !goal.note.isEmpty {
                    Text(goal.note).font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("報酬").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                    MoneyText(amount: goal.rewardAmount, size: 32, signed: true)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("/ 回").font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 4)
            }
            .padding(.trailing, 60)
        }
    }

    private func statGrid(completions: [GoalCompletion], frozen: Set<Date>) -> some View {
        let monthStart = Date().startOfMonth
        let monthEarned = completions.filter { $0.completedAt >= monthStart }.reduce(0) { $0 + $1.rewardAmount }
        let streak = GoalService.streak(goal, completions, frozenDays: frozen)

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            periodTile(completions: completions)
            statTile(icon: "yensign.circle.fill", color: Theme.gold, label: "今月獲得", value: monthEarned.yen)
            statTile(icon: "flame.fill", color: .orange, label: "Streak", value: GoalService.streakText(goal, streak))
            statTile(icon: "checkmark.seal.fill", color: Theme.green, label: "累計達成", value: "\(completions.count)回")
        }
    }

    private func actions(completions: [GoalCompletion], canComplete: Bool, completedToday: Bool) -> some View {
        VStack(spacing: 10) {
            PrimaryButton(title: completedToday ? "今日は達成済み" : "今日達成した", leadingIcon: "checkmark", kind: .blue) {
                appState.complete(goal, context: context)
            }
            .disabled(!canComplete)

            if !canComplete, !completedToday, let reason = GoalService.blockedReason(goal, completions) {
                Text(reason).font(.system(size: 13)).foregroundStyle(Theme.subtext)
            }

            let yesterday = Date().startOfDay.adding(days: -1)
            if GoalService.canBackfill(goal, completions, day: yesterday) {
                Button {
                    appState.backfill(goal, day: yesterday, context: context)
                } label: {
                    Label("昨日の分を記録する（記録し忘れ）", systemImage: "calendar.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                }
                .padding(.vertical, 2)
            }

            if completedToday, let today = completions.first(where: { $0.completedAt.isSameDay(as: Date()) }) {
                Button {
                    RewardService(context: context).undoCompletion(id: today.id)
                    NotificationService.reschedule(context: context)
                    Haptics.tap()
                } label: {
                    Label("今日の達成を取り消す（\(today.rewardAmount.signedYen)）", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.subtext)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 4)
    }

    private func periodTile(completions: [GoalCompletion]) -> some View {
        let label: String
        let count: Int
        let target: Int
        switch goal.frequency {
        case .monthly:
            label = "今月"
            count = GoalService.periodCount(goal, completions)
            target = GoalService.periodTarget(goal)
        case .weekly:
            label = "今週"
            count = GoalService.periodCount(goal, completions)
            target = GoalService.periodTarget(goal)
        case .once:
            label = "達成"
            count = min(1, completions.count)
            target = 1
        case .daily, .weekdays:
            label = "今週"
            count = GoalService.count(completions, in: DateInterval(start: Date().startOfWeek, duration: 7 * 86_400))
            target = goal.frequency == .daily ? 7 : max(1, goal.weekdays.count)
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: "calendar").font(.system(size: 13)).foregroundStyle(Theme.subtext)
            Text("\(count) / \(target)").font(.system(size: 24, weight: .heavy)).monospacedDigit().foregroundStyle(Theme.ink)
            LinearBar(progress: Double(count) / Double(max(1, target)), color: count >= target ? Theme.green : Theme.blue, height: 6)
        }
        .cardStyle(padding: 14)
    }

    private func statTile(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.subtext)
            Text(value)
                .font(.system(size: 24, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 68, alignment: .topLeading)
        .cardStyle(padding: 14)
    }

    // MARK: - Actions

    private func isEditableDay(_ day: Date, completions: [GoalCompletion]) -> Bool {
        let today = Date().startOfDay
        guard goal.archivedAt == nil, day <= today, day >= today.adding(days: -GoalService.backfillDays) else { return false }
        if completions.contains(where: { $0.completedAt.isSameDay(as: day) }) { return true }
        if day == today { return GoalService.canComplete(goal, completions) }
        return GoalService.canBackfill(goal, completions, day: day)
    }

    private func restore() {
        RewardService(context: context).restore(goal)
        NotificationService.reschedule(context: context)
        Haptics.tap()
    }

    private func delete() {
        isDeleted = true
        let target = goal
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            RewardService(context: context).deleteGoal(target)
            NotificationService.reschedule(context: context)
        }
    }
}

struct MonthCalendarView: View {
    @Binding var month: Date
    let markedDays: Set<Date>
    var frozenDays: Set<Date> = []
    var onTapDay: ((Date) -> Void)?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let cal = Calendar.nareta
        let start = month.startOfMonth
        let daysInMonth = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let leading = (start.weekday + 5) % 7
        let today = Date().startOfDay

        VStack(spacing: 12) {
            HStack {
                Text("\(String(start.year))年\(start.month)月").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                Spacer()
                if !frozenDays.isEmpty {
                    Label("Freeze", systemImage: "snowflake")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x0EA5E9))
                        .padding(.trailing, 8)
                }
                Button { month = start.adding(months: -1) } label: { Image(systemName: "chevron.left") }
                    .padding(.horizontal, 8)
                Button { month = start.adding(months: 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(start >= Date().startOfMonth)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Weekday.mondayFirst, id: \.self) { day in
                    Text(Weekday.label(day)).font(.system(size: 12)).foregroundStyle(Theme.subtext)
                }
                ForEach(0..<leading, id: \.self) { i in
                    Color.clear.frame(height: 34).id("blank-\(i)")
                }
                ForEach(0..<daysInMonth, id: \.self) { offset in
                    let date = start.adding(days: offset)
                    let marked = markedDays.contains(date)
                    let frozen = !marked && frozenDays.contains(date)
                    let isToday = date == today
                    Text("\(offset + 1)")
                        .font(.system(size: 14, weight: marked || isToday ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(marked ? .white : (date > today ? Theme.subtext.opacity(0.5) : Theme.ink))
                        .frame(width: 34, height: 34)
                        .background {
                            if marked {
                                Circle().fill(Theme.green)
                            } else if frozen {
                                Circle().fill(Color(hex: 0xBAE6FD))
                            } else if isToday {
                                Circle().stroke(Theme.blue, lineWidth: 1.5)
                            }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            if date <= today { onTapDay?(date) }
                        }
                }
            }
        }
        .cardStyle()
    }
}
