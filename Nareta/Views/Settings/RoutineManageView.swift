import SwiftData
import SwiftUI

struct RoutineManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RoutineAnchor.sortOrder) private var routines: [RoutineAnchor]
    @Query private var goals: [Goal]

    @State private var editing: RoutineAnchor?
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(routines) { routine in
                    Button { editing = routine } label: {
                        HStack(spacing: 12) {
                            Image(systemName: routine.icon)
                                .foregroundStyle(Theme.blue)
                                .frame(width: 34, height: 34)
                                .background(Theme.blue.opacity(0.1), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.name).foregroundStyle(Theme.ink)
                                let linked = goals.filter { $0.routineId == routine.id }.count
                                if linked > 0 {
                                    Text("\(linked)個の目標").font(.caption).foregroundStyle(Theme.subtext)
                                }
                            }
                            Spacer()
                            Text(TriggerService.timeText(routine.minutes))
                                .font(.system(size: 17, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button { delete(routine) } label: { Label("削除", systemImage: "trash") }
                            .tint(Theme.red)
                        Button { editing = routine } label: { Label("編集", systemImage: "pencil") }
                            .tint(Theme.blue)
                    }
                    .contextMenu {
                        Button("編集", systemImage: "pencil") { editing = routine }
                        Button("削除", systemImage: "trash", role: .destructive) { delete(routine) }
                    }
                }
            } footer: {
                Text("夕食など日によって変わるものは、いつもの時刻を登録しておきましょう。時刻を変えると、紐づく目標のアラームもまとめて変わります。削除すると、紐づく目標はその時刻のまま残ります。")
            }
        }
        .navigationTitle("ルーティン時刻")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { RoutineEditorSheet(routine: $0) }
        .sheet(isPresented: $showAdd) {
            RoutineEditorSheet(routine: nil, nextSortOrder: (routines.map(\.sortOrder).max() ?? 0) + 1)
        }
    }

    private func delete(_ routine: RoutineAnchor) {
        for goal in goals where goal.routineId == routine.id {
            goal.triggerMinutes = TriggerService.normalize(routine.minutes + goal.triggerOffset)
            goal.routineId = nil
            goal.triggerOffset = 0
        }
        context.delete(routine)
        try? context.save()
        NotificationService.reschedule(context: context)
    }
}

struct RoutineEditorSheet: View {
    let routine: RoutineAnchor?
    var nextSortOrder = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var time = Calendar.nareta.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var icon = "clock"
    @State private var didLoad = false

    private static let icons = [
        "sunrise.fill", "cup.and.saucer.fill", "fork.knife", "briefcase.fill", "takeoutbag.and.cup.and.straw.fill",
        "house.fill", "bathtub.fill", "bed.double.fill", "figure.walk", "clock",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例: 夕食", text: $name)
                }
                Section("いつもの時刻") {
                    DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                }
                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Self.icons, id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(icon == symbol ? .white : Theme.ink)
                                    .background(icon == symbol ? Theme.navy : Theme.chip, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(routine == nil ? "ルーティンを追加" : "ルーティンを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let routine else { return }
        name = routine.name
        icon = routine.icon
        time = TriggerService.date(routine.minutes, on: Date())
    }

    private func save() {
        let components = Calendar.nareta.dateComponents([.hour, .minute], from: time)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let routine {
            routine.name = trimmed
            routine.icon = icon
            routine.minutes = minutes
        } else {
            context.insert(RoutineAnchor(name: trimmed, icon: icon, minutes: minutes, sortOrder: nextSortOrder))
        }
        try? context.save()
        NotificationService.reschedule(context: context)
        Haptics.success()
        dismiss()
    }
}
