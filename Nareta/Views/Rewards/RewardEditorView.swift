import PhotosUI
import SwiftData
import SwiftUI

struct RewardEditorView: View {
    let reward: Reward?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var note = ""
    @State private var price = 0
    @State private var category: RewardCategory = .gadget
    @State private var priority: RewardPriority = .normal
    @State private var imageData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var didLoad = false

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && price > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    EditorSection(title: "名前") {
                        VStack(spacing: 10) {
                            TextField("例: AirPods Pro", text: $name)
                                .font(.system(size: 18, weight: .semibold))
                                .padding(.horizontal, 14)
                                .frame(height: 50)
                                .background(Theme.chip.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            TextField("ひとこと（任意） 例: より良い毎日を、もっと快適に", text: $note)
                                .font(.system(size: 14))
                                .padding(.horizontal, 14)
                                .frame(height: 42)
                                .background(Theme.chip.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                    EditorSection(title: "価格") {
                        YenAmountField(amount: $price, placeholder: "39800")
                    }

                    EditorSection(title: "画像", subtitle: "任意") {
                        HStack(spacing: 14) {
                            preview
                            VStack(alignment: .leading, spacing: 8) {
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Label(imageData == nil ? "写真を選ぶ" : "写真を変更", systemImage: "photo")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                if imageData != nil {
                                    Button("画像を削除", role: .destructive) { imageData = nil; photoItem = nil }
                                        .font(.system(size: 14))
                                }
                            }
                            Spacer()
                        }
                    }

                    EditorSection(title: "カテゴリ") {
                        FlowLayout(spacing: 8) {
                            ForEach(RewardCategory.allCases) { item in
                                SelectChip(title: item.label, icon: item.icon, selected: category == item, showsCheck: false) {
                                    category = item
                                }
                            }
                        }
                    }

                    EditorSection(title: "優先度", subtitle: "Highのごほうびがホームの「次のごほうび」に表示されます") {
                        Picker("優先度", selection: $priority) {
                            ForEach(RewardPriority.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(reward == nil ? "ごほうびを追加" : "ごほうびを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                BottomBar {
                    PrimaryButton(title: reward == nil ? "追加" : "保存する", kind: .navy, action: save)
                        .disabled(!isValid)
                }
            }
            .onAppear(perform: load)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        imageData = ImageDownscaler.jpegData(from: data)
                    }
                }
            }
        }
    }

    private var preview: some View {
        let colors = category.gradient
        return ZStack {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Color(hex: colors.0), Color(hex: colors.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: category.icon).font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let reward else { return }
        name = reward.name
        note = reward.note
        price = reward.price
        category = reward.categoryValue
        priority = reward.priorityValue
        imageData = reward.imageData
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let reward {
            reward.name = trimmed
            reward.note = note
            reward.price = price
            reward.category = category.rawValue
            reward.priority = priority.rawValue
            reward.imageData = imageData
        } else {
            context.insert(Reward(name: trimmed, note: note, price: price, category: category, imageData: imageData, priority: priority))
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
