import SwiftUI
import WatchKit
import WatchConnectivity
import HealthKit
import FormaKit

@main
struct FormaWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate
    @State private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environment(store)
                .tint(WColor.lime)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        Task { @MainActor in WatchStore.shared.activate() }
    }

    /// Telefon antrenmanı başlatınca saat uygulaması bu yapılandırmayla açılır.
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in WorkoutManager.shared.start(configuration: workoutConfiguration) }
    }
}

enum WColor {
    static let lime = Color(red: 0.776, green: 0.949, blue: 0.306)
    static let onLime = Color(red: 0.07, green: 0.08, blue: 0.04)
    static let water = Color(red: 0.353, green: 0.69, blue: 1.0)
    static let energy = Color(red: 1.0, green: 0.608, blue: 0.29)
    static let violet = Color(red: 0.725, green: 0.651, blue: 1.0)
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.357)
    static let track = Color(red: 0.165, green: 0.184, blue: 0.216)
    static let secondary = Color(red: 0.655, green: 0.69, blue: 0.729)
}

// MARK: - Durum

@MainActor
@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    static let shared = WatchStore()

    var payload: WatchPayload = .empty
    var isReachable = false
    var lastUpdate: Date?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        if let data = UserDefaults.standard.data(forKey: "lastPayload"), let p = try? decoder.decode(WatchPayload.self, from: data) {
            payload = p
        }
    }

    func send(_ message: [String: Any]) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            session.transferUserInfo(message)
        }
        WKInterfaceDevice.current().play(.click)
    }

    // İyimser yerel güncellemeler
    func addWater(_ ml: Double) {
        payload.waterMl += ml
        send(["action": "water", "ml": ml])
    }

    func take(_ s: WatchPayload.Supplement) {
        if let i = payload.supplements.firstIndex(where: { $0.id == s.id }) { payload.supplements[i].taken = true }
        send(["action": "supplement", "id": s.id.uuidString])
    }

    func completeSet() {
        send(["action": "completeSet"])
        WKInterfaceDevice.current().play(.success)
    }

    fileprivate func receive(_ data: Data) {
        guard let p = try? decoder.decode(WatchPayload.self, from: data) else { return }
        let wasLive = payload.live != nil
        payload = p
        lastUpdate = Date()
        UserDefaults.standard.set(data, forKey: "lastPayload")
        if wasLive && p.live == nil { WorkoutManager.shared.end() }
        if !wasLive, p.live != nil, !WorkoutManager.shared.isRunning {
            WorkoutManager.shared.start(configuration: nil)
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let ctx = session.receivedApplicationContext["payload"] as? Data
        let reachable = session.isReachable
        Task { @MainActor in
            self.isReachable = reachable
            if let ctx { self.receive(ctx) }
            self.send(["action": "refresh"])
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["payload"] as? Data else { return }
        Task { @MainActor in self.receive(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["payload"] as? Data else { return }
        Task { @MainActor in self.receive(data) }
    }
}

// MARK: - Nabız ve antrenman kaydı

@MainActor
@Observable
final class WorkoutManager: NSObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    static let shared = WorkoutManager()

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    var heartRate: Double = 0
    var activeEnergy: Double = 0
    var isRunning = false
    private var lastSent = Date.distantPast

    func start(configuration: HKWorkoutConfiguration?) {
        guard HKHealthStore.isHealthDataAvailable(), !isRunning else { return }
        let config = configuration ?? {
            let c = HKWorkoutConfiguration()
            c.activityType = .traditionalStrengthTraining
            c.locationType = .indoor
            return c
        }()
        Task {
            let types: Set<HKSampleType> = [HKObjectType.workoutType()]
            var read: Set<HKObjectType> = []
            if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { read.insert(hr) }
            if let ae = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(ae) }
            try? await healthStore.requestAuthorization(toShare: types, read: read)
            do {
                let s = try HKWorkoutSession(healthStore: healthStore, configuration: config)
                let b = s.associatedWorkoutBuilder()
                b.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
                s.delegate = self
                b.delegate = self
                session = s
                builder = b
                let start = Date()
                s.startActivity(with: start)
                try await b.beginCollection(at: start)
                isRunning = true
                WatchStore.shared.send(["action": "watchSavedWorkout"])
            } catch {
                isRunning = false
            }
        }
    }

    func end() {
        guard let session, let builder, isRunning else { return }
        isRunning = false
        session.end()
        Task {
            try? await builder.endCollection(at: Date())
            _ = try? await builder.finishWorkout()
            self.session = nil
            self.builder = nil
            self.heartRate = 0
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.isRunning = false }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        var bpm: Double?
        var kcal: Double?
        if let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate), collectedTypes.contains(hrType),
           let stats = workoutBuilder.statistics(for: hrType) {
            bpm = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        if let aeType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned), collectedTypes.contains(aeType),
           let stats = workoutBuilder.statistics(for: aeType) {
            kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie())
        }
        Task { @MainActor in
            if let bpm { self.heartRate = bpm }
            if let kcal { self.activeEnergy = kcal }
            if Date().timeIntervalSince(self.lastSent) > 15, self.heartRate > 0 {
                self.lastSent = Date()
                WatchStore.shared.send(["action": "heartRate", "bpm": self.heartRate])
            }
        }
    }
}
