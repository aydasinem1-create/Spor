import Foundation
import ActivityKit
import FormaKit

/// Kilit ekranı ve Dynamic Island'daki canlı antrenman.
@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    private var activity: Activity<WorkoutActivityAttributes>?

    var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(session: WorkoutSession, model: AppModel) {
        end()
        guard isEnabled else { return }
        let attributes = WorkoutActivityAttributes(sessionID: session.id.uuidString, title: session.title, startedAt: session.startedAt)
        guard let state = Self.state(for: model) else { return }
        do {
            activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: state, staleDate: nil),
                                            pushType: nil)
        } catch {
            activity = nil
        }
    }

    /// Uygulama yeniden açıldığında yarım kalan antrenmanın etkinliğini bul.
    func reattach(model: AppModel) {
        guard let session = model.activeWorkout else {
            end()
            return
        }
        if let existing = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.attributes.sessionID == session.id.uuidString }) {
            activity = existing
            update(model: model)
        } else {
            start(session: session, model: model)
        }
    }

    func update(model: AppModel) {
        guard let activity, let state = Self.state(for: model) else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        let all = Activity<WorkoutActivityAttributes>.activities
        activity = nil
        Task {
            for a in all {
                var final = a.content.state
                final.isFinished = true
                final.restEndsAt = nil
                await a.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .immediate)
            }
        }
    }

    static func state(for model: AppModel) -> WorkoutActivityAttributes.ContentState? {
        guard let w = model.activeWorkout else { return nil }
        let total = w.exercises.reduce(0) { $0 + $1.sets.filter { $0.kind != .warmup }.count }
        let done = w.exercises.reduce(0) { $0 + $1.sets.filter { $0.kind != .warmup && $0.isCompleted }.count }
        let rest = model.restTimer.isRunning ? model.restTimer.endsAt : nil

        guard let next = model.nextIncompleteSet(in: w) else {
            return .init(exerciseName: "Tüm setler bitti", setIndex: 0, setCount: 0, targetWeight: 0, targetReps: 0, isTimed: false,
                         restEndsAt: nil, restTotalSeconds: 0, nextExerciseName: nil, completedSets: done, totalSets: total, isFinished: false)
        }
        let se = w.exercises[next.0]
        let set = se.sets[next.1]
        let ex = model.exercise(se.exerciseID)
        let working = se.sets.enumerated().filter { $0.element.kind != .warmup }
        let workingIndex = working.firstIndex { $0.offset == next.1 } ?? 0
        let nextName = w.exercises[safe: next.0 + 1].flatMap { model.exercise($0.exerciseID)?.name }
        let label = set.kind == .warmup ? "\(ex?.name ?? "Hareket") · ısınma" : (ex?.name ?? "Hareket")
        return .init(exerciseName: label, setIndex: workingIndex + 1, setCount: working.count,
                     targetWeight: set.weightKg, targetReps: ex?.tracking == .duration ? set.seconds : set.reps,
                     isTimed: ex?.tracking == .duration, restEndsAt: rest, restTotalSeconds: model.restTimer.total,
                     nextExerciseName: nextName, completedSets: done, totalSets: total, isFinished: false)
    }
}
