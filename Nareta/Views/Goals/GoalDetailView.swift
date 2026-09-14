import SwiftData
import SwiftUI

struct GoalDetailView: View {
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState

    @Query private var allCompletions: [GoalCompletion]
    @Query private var identities: [Identity]

    @State private var displayedMonth = Date().startOfMonth
    @State private var confirmDelete = false
    @State private var isDeleted = false

    var body: some View {
        if isDeleted {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        let completions = allCompletions.filter { $0.goalId == goal.id }
        let identity = identities.first { $0.id == goal.identityId }
        let now = Date()
        let monthCompletions = completions.filter { $0.completedAt >= now.startOfMonth }
        let weekInterval = DateInterval(start: now.startOfWeek, duration: 7 * 86_400)
        let canComplete = GoalService.canComplete(goal, completions)
        let completedToday = GoalService.isCompletedToday(completions)
        let streak = GoalService.streak(goal, completions)

        return ScrollView {
            VStack(spacing: 14) {
                HeroCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            if let identity { TagChip(text: identity.name, color: Color(hexString: identity.colorHex).mix(with: .white, by: 0.35)) }
                            Text(goal.frequencyLabel).font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                            if !goal.isActive { TagChip(text: "一時停止中", color: .orange) }
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

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    periodTile(completions: completions, week: weekInterval)
                    statTile(icon: "yensign.circle.fill", color: Theme.gold, label: "今月獲得",
                             value: monthCompletions.reduce(0) { $0 + $1.rewardAmount }.yen)
                    statTile(icon: "flame.fill", color: .orange, label: "Streak", value: GoalService.streakText(goal, streak))
                    statTile(icon: "checkmark.seal.fill", color: Theme.green, label: "累計達成", value: "\(completions.count)回")
                }

                MonthCalendarView(month: $displayedMonth, markedDays: Set(completions.map { $0.completedAt.startOfDay }))

                VStack(spacing: 10) {
                    PrimaryButton(title: completedToday ? "今日は達成済み" : "今日達成した", leadingIcon: "checkmark", kind: .blue) {
                        appState.complete(goal, context: context)
                    }
                    .disabled(!canComplete)

                    if !canComplete, !completedToday, let reason = GoalService.blockedReason(goal, completions) {
                        Text(reason).font(.system(size: 13)).foregroundStyle(Theme.subtext)
                    }

                    if completedToday, let today = completions.first(where: { $0.completedAt.isSameDay(as: now) }) {
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

                    HStack(spacing: 10) {
                        NavigationLink {
                            GoalEditorView(goal: goal)
                        } label: {
                            secondaryLabel("編集", icon: "pencil")
                        }
                        Button {
                            goal.isActive.toggle()
                            try? context.save()
                            NotificationService.reschedule(context: context)
                        } label: {
                            secondaryLabel(goal.isActive ? "一時停止" : "再開", icon: goal.isActive ? "pause.fill" : "play.fill")
                        }
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text("この目標を削除").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.red)
                    }
                    .padding(.top, 6)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("「\(goal.title)」を削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除する", role: .destructive, action: delete)
        } message: {
            Text("これまでに解放したお金と履歴はそのまま残ります。")
        }
    }

    private func periodTile(completions: [GoalCompletion], week: DateInterval) -> some View {
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
            count = GoalService.count(completions, in: week)
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

    private func secondaryLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Theme.line))
    }

    private func delete() {
        isDeleted = true
        let target = goal
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            context.delete(target)
            try? context.save()
            NotificationService.reschedule(context: context)
        }
    }
}

struct MonthCalendarView: View {
    @Binding var month: Date
    let markedDays: Set<Date>

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
                    let isToday = date == today
                    Text("\(offset + 1)")
                        .font(.system(size: 14, weight: marked || isToday ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundStyle(marked ? .white : (date > today ? Theme.subtext.opacity(0.5) : Theme.ink))
                        .frame(width: 34, height: 34)
                        .background {
                            if marked {
                                Circle().fill(Theme.green)
                            } else if isToday {
                                Circle().stroke(Theme.blue, lineWidth: 1.5)
                            }
                        }
                }
            }
        }
        .cardStyle()
    }
}
