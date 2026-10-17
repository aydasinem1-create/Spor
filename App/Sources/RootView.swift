import SwiftUI
import FormaKit

enum AppTab: String, CaseIterable, Identifiable {
    case today, workout, nutrition, progress, profile
    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Bugün"
        case .workout: return "Antrenman"
        case .nutrition: return "Beslenme"
        case .progress: return "İlerleme"
        case .profile: return "Profil"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sun.max.fill"
        case .workout: return "figure.strengthtraining.traditional"
        case .nutrition: return "fork.knife"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.hasProfile {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.hasProfile)
        .screenBackground()
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model
    @State private var tab: AppTab = .today
    @State private var showWorkout = false
    @State private var showWater = false
    @State private var showAddFood = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .today: TodayView(tab: $tab, showWorkout: $showWorkout)
                case .workout: WorkoutHomeView(showWorkout: $showWorkout)
                case .nutrition: NutritionView()
                case .progress: ProgressHubView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: model.activeWorkout == nil ? 76 : 136) }

            VStack(spacing: 8) {
                if model.activeWorkout != nil {
                    ActiveWorkoutBar { showWorkout = true }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                FormaTabBar(selection: $tab)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.activeWorkout != nil)

            if let toast = model.toast {
                VStack {
                    ToastView(symbol: toast.symbol, title: toast.title, subtitle: toast.subtitle, tint: toast.tint)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { model.toast = nil }
                    Spacer()
                }
                .padding(.top, 4)
                .zIndex(10)
            }

            if model.showConfetti {
                ConfettiView().ignoresSafeArea().zIndex(11)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $showWorkout) {
            ActiveWorkoutView()
                .environment(model)
        }
        .sheet(isPresented: $showWater) {
            WaterSheet().environment(model)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showAddFood) {
            FoodSearchView(meal: MealType.suggested(for: Date(), ramadan: model.isRamadan)).environment(model)
                .presentationBackground(Theme.background)
        }
        .onChange(of: model.pendingRoute) { _, route in
            guard let route else { return }
            model.pendingRoute = nil
            switch route {
            case .today: tab = .today
            case .startWorkout:
                if model.activeWorkout == nil { model.startWorkout(model.nextPlan) }
                showWorkout = true
            case .addFood:
                tab = .nutrition
                showAddFood = true
            case .water:
                showWater = true
            }
        }
        .onAppear {
            if model.activeWorkout != nil && ProcessInfo.processInfo.arguments.contains("-openWorkout") { showWorkout = true }
        }
    }
}

struct FormaTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                let selected = tab == selection
                Button {
                    guard tab != selection else { return }
                    Haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 17, weight: .semibold))
                        if selected {
                            Text(tab.title)
                                .font(.forma(.callout))
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .foregroundStyle(selected ? Theme.onLime : Theme.textTertiary)
                    .padding(.horizontal, selected ? 14 : 0)
                    .frame(height: 44)
                    .frame(maxWidth: selected ? nil : .infinity)
                    .background {
                        if selected {
                            Capsule().fill(Theme.lime).matchedGeometryEffect(id: "tab", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityIdentifier("tab.\(tab.rawValue)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            Capsule().fill(Theme.surface.opacity(0.92))
                .background(.ultraThinMaterial, in: Capsule())
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 4)
    }
}

struct ActiveWorkoutBar: View {
    @Environment(AppModel.self) private var model
    var onTap: () -> Void

    var body: some View {
        if let w = model.activeWorkout {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.lime.opacity(0.18))
                        Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(Theme.lime)
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(w.title).formaFont(.bodyMedium).lineLimit(1)
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            if model.restTimer.isRunning {
                                Text("Dinlenme \(Fmt.duration(model.restTimer.remaining(at: ctx.date)))")
                                    .formaFont(.caption, Theme.water)
                                    .monospacedDigit()
                            } else {
                                Text("\(Fmt.duration(ctx.date.timeIntervalSince(w.startedAt))) · \(w.completedSetCount) set")
                                    .formaFont(.caption, Theme.textSecondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    Spacer()
                    Text("Devam").font(.forma(.callout)).foregroundStyle(Theme.onLime)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Theme.lime, in: Capsule())
                }
                .padding(10)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.lime.opacity(0.25), lineWidth: 1))
                .padding(.horizontal, Theme.gutter)
            }
            .buttonStyle(PressableStyle())
            .accessibilityIdentifier("activeWorkoutBar")
        }
    }
}
