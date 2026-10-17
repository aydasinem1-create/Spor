import Foundation
import WatchConnectivity
import FormaKit

/// iPhone ↔ Apple Watch iletişimi.
/// Telefon: bugünün özeti ve canlı antrenman durumunu gönderir.
/// Saat: su, takviye, set tamamlama, dinlenme ve nabız bilgisini gönderir.
@MainActor
final class WatchSync: NSObject {
    static let shared = WatchSync()

    weak var model: AppModel?
    private var session: WCSession? { WCSession.isSupported() ? WCSession.default : nil }
    private var lastPayloadHash: Int?

    func activate(model: AppModel) {
        self.model = model
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func push(model: AppModel) {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        let payload = Self.payload(for: model)
        guard let data = try? JSONEncoder.watch.encode(payload) else { return }
        let hash = data.hashValue
        guard hash != lastPayloadHash else { return }
        lastPayloadHash = hash
        let context: [String: Any] = ["payload": data]
        try? session.updateApplicationContext(context)
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    func startWatchWorkout() {
        guard let session, session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
        HealthService.shared.startWatchApp()
    }

    static func payload(for model: AppModel) -> WatchPayload {
        let t = model.targets
        let supps = model.todaysSupplements.map {
            WatchPayload.Supplement(id: $0.id, kind: $0.kind, name: $0.name, dose: $0.doseLabel, taken: model.isDone($0))
        }
        var live: WatchPayload.Live?
        if let w = model.activeWorkout {
            let state = LiveActivityService.state(for: model)
            live = WatchPayload.Live(sessionID: w.id, title: w.title, startedAt: w.startedAt,
                                     exerciseName: state?.exerciseName ?? "", setIndex: state?.setIndex ?? 0, setCount: state?.setCount ?? 0,
                                     weight: state?.targetWeight ?? 0, reps: state?.targetReps ?? 0, isTimed: state?.isTimed ?? false,
                                     restEndsAt: state?.restEndsAt, completedSets: state?.completedSets ?? 0, totalSets: state?.totalSets ?? 0,
                                     nextExerciseName: state?.nextExerciseName)
        }
        return WatchPayload(day: model.todayKey, waterMl: model.todayWaterMl, waterTarget: t.waterMl,
                            protein: model.todayMacros.protein, proteinTarget: t.proteinG,
                            kcal: model.todayMacros.kcal, kcalTarget: t.kcal, supplements: supps,
                            nextWorkout: model.trainedToday ? nil : model.nextPlan.title, live: live,
                            creatineStreak: model.creatineStreak)
    }

    fileprivate func handle(message: [String: Any]) {
        guard let model, let action = message["action"] as? String else { return }
        switch action {
        case "water":
            model.logWater(ml: (message["ml"] as? Double) ?? 250)
        case "supplement":
            if let idString = message["id"] as? String, let id = UUID(uuidString: idString), let s = model.supplement(id) {
                if !model.isDone(s) { model.take(s) }
            } else if let c = model.creatine, !model.isDone(c) {
                model.take(c)
            }
        case "completeSet":
            model.completeNextSet()
        case "skipRest":
            model.skipRest()
        case "addRest":
            model.adjustRest(by: (message["seconds"] as? Int) ?? 30)
        case "startWorkout":
            if model.activeWorkout == nil { model.startWorkout(model.nextPlan) }
        case "heartRate":
            if let bpm = message["bpm"] as? Double, model.activeWorkout != nil {
                model.updateWorkout { $0.averageHeartRate = bpm }
            }
        case "watchSavedWorkout":
            model.updateWorkout { $0.savedToHealthByWatch = true }
        case "refresh":
            lastPayloadHash = nil
            push(model: model)
        default:
            break
        }
    }
}

extension WatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let model = self.model { self.push(model: model) }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let copy = message.compactMapValues { $0 as? any Sendable }
        Task { @MainActor in self.handle(message: copy) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let copy = userInfo.compactMapValues { $0 as? any Sendable }
        Task { @MainActor in self.handle(message: copy) }
    }
}

extension JSONEncoder {
    static let watch: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()
}
