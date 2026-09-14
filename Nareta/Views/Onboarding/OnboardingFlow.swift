import SwiftData
import SwiftUI

struct OnboardingFlow: View {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var selectedIdentities: [String] = ["健康でいたい", "学び続けたい"]
    @State private var poolAmount = 30_000
    @State private var includeSamples = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch step {
            case 0:
                WelcomeView(onStart: { go(1) }, onLater: finish)
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)).combined(with: .opacity))
            case 1:
                IdentitySetupView(selected: $selectedIdentities, onBack: { go(0) }, onNext: { go(2) })
                    .transition(.push(from: .trailing))
            default:
                RewardPoolSetupView(amount: $poolAmount, includeSamples: $includeSamples, onBack: { go(1) }, onFinish: finish)
                    .transition(.push(from: .trailing))
            }
        }
    }

    private func go(_ next: Int) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = next }
    }

    private func finish() {
        DataService.seed(context: context, identityNames: selectedIdentities, poolAmount: max(1_000, poolAmount), includeSamples: includeSamples)
        Haptics.success()
        Task {
            await NotificationService.requestAuthorization()
            await AlarmService.requestAuthorization()
            NotificationService.reschedule(context: context)
        }
        withAnimation(.easeInOut(duration: 0.35)) { hasOnboarded = true }
    }
}

struct OnboardingHeader: View {
    let step: Int
    var onBack: (() -> Void)?

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                }
            }
            Spacer()
            PageDots(count: 3, current: step)
            Spacer()
            if onBack != nil { Color.clear.frame(width: 40, height: 40) }
        }
    }
}
