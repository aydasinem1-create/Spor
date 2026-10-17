import SwiftUI
import FormaKit

@main
struct FormaApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-uitest")
        let storage: FormaStorage
        if isUITest {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("uitest-\(UUID().uuidString)")
            storage = FormaStorage(directory: dir)
        } else {
            storage = AppConfig.storage
        }
        let model = AppModel(storage: storage)
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            DemoData.load(into: model)
        }
        _model = State(initialValue: model)
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Theme.lime)
                .onAppear {
                    NotificationService.shared.configure(model: model)
                    WatchSync.shared.activate(model: model)
                    LiveActivityService.shared.reattach(model: model)
                }
                .onOpenURL { url in
                    guard url.scheme == AppConfig.urlScheme else { return }
                    let route = [url.host, url.path.isEmpty ? nil : String(url.path.dropFirst())].compactMap { $0 }.joined(separator: "/")
                    model.open(route: route)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                model.tick()
                model.mergeInbox()
                NotificationService.shared.reschedule(model: model)
                Task { await HealthService.shared.refresh(into: model) }
                WatchSync.shared.push(model: model)
            case .background:
                model.flush()
            default:
                break
            }
        }
    }
}

enum Appearance {
    static func configure() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = UIColor(Theme.background)
        let titleFont = UIFont(name: "SpaceGrotesk-SemiBold", size: 17) ?? .systemFont(ofSize: 17, weight: .semibold)
        let largeFont = UIFont(name: "SpaceGrotesk-Bold", size: 32) ?? .systemFont(ofSize: 32, weight: .bold)
        nav.titleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary), .font: titleFont]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(Theme.textPrimary), .font: largeFont]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UITableView.appearance().backgroundColor = .clear
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Theme.lime)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Theme.onLime)], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(Theme.textSecondary)], for: .normal)
    }
}
