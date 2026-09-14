import SwiftUI

struct IdentitySetupView: View {
    @Binding var selected: [String]
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var customNames: [String] = []
    @State private var showAdd = false
    @State private var newName = ""

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingHeader(step: 1, onBack: onBack).padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("どんな自分になりたい？")
                            .font(.system(size: 30, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text("複数選択できます。作る目標と結びつき、\n「なりたい自分」への進み具合がわかります。")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.subtext)
                            .lineSpacing(3)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(IdentityPreset.all) { preset in
                            card(name: preset.name, icon: preset.icon, color: Color(hexString: preset.colorHex))
                        }
                        ForEach(customNames, id: \.self) { name in
                            card(name: name, icon: IdentityPreset.customIcon, color: Theme.blue)
                        }
                        Button {
                            newName = ""
                            showAdd = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus").font(.system(size: 20, weight: .bold))
                                Text("自分で追加").font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Theme.subtext)
                            .frame(maxWidth: .infinity, minHeight: 108)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Theme.subtext.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                PrimaryButton(title: selected.isEmpty ? "スキップ" : "次へ（\(selected.count)つ選択中）", icon: "chevron.right", kind: .navy, action: onNext)
            }
        }
        .alert("なりたい自分を追加", isPresented: $showAdd) {
            TextField("例: 早起きしたい", text: $newName)
            Button("追加") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !customNames.contains(name), IdentityPreset.find(name) == nil else { return }
                customNames.append(name)
                selected.append(name)
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear {
            customNames = selected.filter { IdentityPreset.find($0) == nil }
        }
    }

    private func card(name: String, icon: String, color: Color) -> some View {
        let isOn = selected.contains(name)
        return Button {
            Haptics.tap()
            if let i = selected.firstIndex(of: name) { selected.remove(at: i) } else { selected.append(name) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isOn ? .white : color)
                        .frame(width: 40, height: 40)
                        .background(isOn ? color : color.opacity(0.12), in: Circle())
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isOn ? Theme.navy : Theme.line)
                }
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isOn ? Theme.navy : Theme.line, lineWidth: isOn ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isOn)
    }
}
