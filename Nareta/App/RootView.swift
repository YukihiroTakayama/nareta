import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash = true
    @State private var newMonthPool: MonthlyRewardPool?
    @State private var editingNewPool: MonthlyRewardPool?

    var body: some View {
        ZStack {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingFlow()
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            #if DEBUG
            if DemoData.isRequested && !hasOnboarded {
                DemoData.seed(context: context)
                hasOnboarded = true
            }
            #endif
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.4)) { showSplash = false }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            checkNewMonth()
            if hasOnboarded { NotificationService.reschedule(context: context) }
        }
        .onChange(of: hasOnboarded) { _, _ in checkNewMonth() }
        .alert(
            newMonthPool.map { "\($0.month)月のReward Pool" } ?? "",
            isPresented: Binding(get: { newMonthPool != nil && !showSplash }, set: { if !$0 { newMonthPool = nil } }),
            presenting: newMonthPool
        ) { pool in
            Button("この金額で開始") { newMonthPool = nil }
            Button("金額を変更") {
                editingNewPool = pool
                newMonthPool = nil
            }
        } message: { pool in
            let carry = pool.carriedOverAmount > 0 ? "\n先月の未使用額 \(pool.carriedOverAmount.yen) を繰り越しました。" : ""
            Text("\(pool.month)月のReward Poolを\(pool.totalAmount.yen)で開始しますか？\(carry)")
        }
        .sheet(item: $editingNewPool) { pool in
            PoolAmountEditorView(pool: pool)
        }
    }

    private func checkNewMonth() {
        guard hasOnboarded else { return }
        DataService.ensureRoutines(context: context)
        let service = RewardService(context: context)
        if service.ensureCurrentPool() {
            newMonthPool = service.currentPool()
        }
    }
}

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var appState = appState

        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                Tab("Home", systemImage: "house.fill", value: AppTab.home) { HomeView() }
                Tab("Goals", systemImage: "target", value: AppTab.goals) { GoalListView() }
                Tab("Rewards", systemImage: "gift.fill", value: AppTab.rewards) { RewardListView() }
                Tab("Me", systemImage: "person.fill", value: AppTab.me) { StatsView() }
            }
            .tint(Theme.blue)
            .onAppear {
                switch UserDefaults.standard.string(forKey: "initialTab") {
                case "goals": appState.selectedTab = .goals
                case "rewards": appState.selectedTab = .rewards
                case "me": appState.selectedTab = .me
                default: break
                }
            }

            if let item = appState.undoItem {
                UndoToast(result: item) { appState.undo(context: context) }
                    .padding(.bottom, 62)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(4)
            }

            if let result = appState.celebration {
                GoalCompletionView(result: result) { appState.finishCelebration() }
                    .transition(.opacity)
                    .zIndex(5)
            }
        }
        .onAppear {
            let router = NotificationRouter.shared
            router.handler = { route in appState.handle(route) }
            if let pending = router.pending {
                router.pending = nil
                appState.handle(pending)
            }
        }
        .onOpenURL { url in
            if let route = AppRoute(url: url) { appState.handle(route) }
        }
    }
}

struct UndoToast: View {
    let result: CompletionResult
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
            Text("\(result.amount.signedYen) 解放しました")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            Button("取り消す", action: onUndo)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.goldLight)
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(Theme.navy, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .padding(.horizontal, 16)
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()
            RadialGradient(colors: [Theme.blue.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 320)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                NaretaLogo(size: 104)
                Text("NARETA")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(.white)
                Text("なりたい自分に、報酬を。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

/// 「N」を抽象化した上昇グラフ + ゴールドのコイン
struct NaretaLogo: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x1A2744), Color(hex: 0x0A1020)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))

            NLogoShape()
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: -size * 0.04, y: size * 0.04)

            Circle()
                .fill(Theme.goldGradient)
                .overlay(Text("¥").font(.system(size: size * 0.11, weight: .heavy)).foregroundStyle(Color(hex: 0x7A5516)))
                .frame(width: size * 0.2, height: size * 0.2)
                .offset(x: size * 0.25, y: -size * 0.25)
        }
        .frame(width: size, height: size)
    }
}

struct NLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15))
        p.addLine(to: CGPoint(x: rect.maxX * 0.72, y: rect.maxY * 0.82))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}
