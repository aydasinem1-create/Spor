import SwiftUI
import FormaKit

extension AppModel {

    var activeWorkout: WorkoutSession? { data.activeWorkout }

    // MARK: Başlatma

    func makeSessionExercise(exercise: Exercise, sets: Int, reps: ClosedRange<Int>, rest: Int?, includeWarmups: Bool) -> SessionExercise {
        let low = lowReadiness
        let setCount = low ? max(1, sets - 1) : sets
        let suggestion = ProgressionEngine.suggest(exercise: exercise, setCount: setCount, repRange: reps,
                                                   sessions: finishedSessions, gym: data.settings.gym, lowReadiness: low)
        let logs = ProgressionEngine.makeSets(for: exercise, suggestion: suggestion, gym: data.settings.gym, includeWarmups: includeWarmups)
        return SessionExercise(exerciseID: exercise.id, targetReps: reps,
                               restSeconds: rest ?? exercise.restSeconds, sets: logs,
                               note: data.exerciseNotes[exercise.id] ?? "")
    }

    func startWorkout(_ plan: PlannedWorkout) {
        guard data.activeWorkout == nil else { return }
        var exercises: [SessionExercise] = []
        var firstCompound = true
        for slot in plan.slots {
            guard let ex = slot.resolvedExercise(equipment: profile.equipment) ?? ExerciseCatalog.exercise(slot.exerciseID) else { continue }
            let warm = firstCompound && ex.mechanic == .compound
            if warm { firstCompound = false }
            exercises.append(makeSessionExercise(exercise: ex, sets: slot.sets, reps: slot.repRange, rest: slot.restSeconds, includeWarmups: warm))
        }
        let session = WorkoutSession(title: plan.title, programID: plan.programID, programDayID: plan.programDayID,
                                     startedAt: Date(), exercises: exercises)
        update { $0.activeWorkout = session }
        restTimer = RestTimerState()
        LiveActivityService.shared.start(session: session, model: self)
        WatchSync.shared.startWatchWorkout()
        WatchSync.shared.push(model: self)
        Haptics.success()
    }

    func startEmptyWorkout(title: String = "Serbest antrenman") {
        guard data.activeWorkout == nil else { return }
        let session = WorkoutSession(title: title, startedAt: Date(), exercises: [])
        update { $0.activeWorkout = session }
        LiveActivityService.shared.start(session: session, model: self)
    }

    func updateWorkout(_ change: (inout WorkoutSession) -> Void) {
        guard var w = data.activeWorkout else { return }
        change(&w)
        update { $0.activeWorkout = w }
        LiveActivityService.shared.update(model: self)
    }

    // MARK: Setler

    func completeSet(exerciseIndex: Int, setIndex: Int) {
        guard let w = data.activeWorkout, w.exercises.indices.contains(exerciseIndex),
              w.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        let wasCompleted = w.exercises[exerciseIndex].sets[setIndex].isCompleted
        updateWorkout { w in
            w.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
            w.exercises[exerciseIndex].sets[setIndex].completedAt = wasCompleted ? nil : Date()
            // Sonraki boş setlere aynı değeri taşı (kullanıcı ağırlığı değiştirdiyse)
            let done = w.exercises[exerciseIndex].sets[setIndex]
            if !wasCompleted && done.kind == .working {
                for i in w.exercises[exerciseIndex].sets.indices where i > setIndex {
                    let next = w.exercises[exerciseIndex].sets[i]
                    if !next.isCompleted && next.kind == .working {
                        w.exercises[exerciseIndex].sets[i].weightKg = done.weightKg
                    }
                }
            }
        }
        if wasCompleted {
            Haptics.tap()
            return
        }
        Haptics.setDone()
        let se = data.activeWorkout?.exercises[exerciseIndex]
        let isWarmup = se?.sets[setIndex].kind == .warmup
        let rest = isWarmup ? 45 : (se?.restSeconds ?? data.settings.gym.defaultRestSeconds)
        let hasMoreSets = data.activeWorkout.map { nextIncompleteSet(in: $0) != nil } ?? false
        if hasMoreSets { startRest(seconds: rest, exerciseIndex: exerciseIndex) } else { skipRest() }
        WatchSync.shared.push(model: self)
    }

    func nextIncompleteSet(in w: WorkoutSession) -> (Int, Int)? {
        for (ei, e) in w.exercises.enumerated() {
            if let si = e.sets.firstIndex(where: { !$0.isCompleted }) { return (ei, si) }
        }
        return nil
    }

    func completeNextSet() {
        guard let w = data.activeWorkout, let next = nextIncompleteSet(in: w) else { return }
        completeSet(exerciseIndex: next.0, setIndex: next.1)
    }

    func setValue(exerciseIndex: Int, setIndex: Int, weight: Double? = nil, reps: Int? = nil, seconds: Int? = nil, rir: Int?? = nil, kind: SetKind? = nil) {
        updateWorkout { w in
            guard w.exercises.indices.contains(exerciseIndex), w.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
            if let weight { w.exercises[exerciseIndex].sets[setIndex].weightKg = max(0, weight) }
            if let reps { w.exercises[exerciseIndex].sets[setIndex].reps = max(0, reps) }
            if let seconds { w.exercises[exerciseIndex].sets[setIndex].seconds = max(0, seconds) }
            if let rir { w.exercises[exerciseIndex].sets[setIndex].rir = rir }
            if let kind { w.exercises[exerciseIndex].sets[setIndex].kind = kind }
        }
    }

    func addSet(exerciseIndex: Int) {
        updateWorkout { w in
            guard w.exercises.indices.contains(exerciseIndex) else { return }
            let last = w.exercises[exerciseIndex].sets.last { $0.kind != .warmup }
            w.exercises[exerciseIndex].sets.append(SetLog(kind: .working, weightKg: last?.weightKg ?? 0,
                                                          reps: last?.reps ?? w.exercises[exerciseIndex].targetRepLow,
                                                          seconds: last?.seconds ?? 0))
        }
        Haptics.tap()
    }

    func removeSet(exerciseIndex: Int, setIndex: Int) {
        updateWorkout { w in
            guard w.exercises.indices.contains(exerciseIndex), w.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
            w.exercises[exerciseIndex].sets.remove(at: setIndex)
        }
    }

    func addExercise(_ exercise: Exercise) {
        let se = makeSessionExercise(exercise: exercise, sets: 3, reps: exercise.repRange, rest: nil, includeWarmups: false)
        updateWorkout { $0.exercises.append(se) }
    }

    func replaceExercise(at index: Int, with exercise: Exercise) {
        guard let old = data.activeWorkout?.exercises[safe: index] else { return }
        let count = max(1, old.sets.filter { $0.kind != .warmup }.count)
        let se = makeSessionExercise(exercise: exercise, sets: count, reps: exercise.repRange, rest: nil, includeWarmups: false)
        updateWorkout { w in
            guard w.exercises.indices.contains(index) else { return }
            w.exercises[index] = se
        }
    }

    func removeExercise(at index: Int) {
        updateWorkout { w in
            guard w.exercises.indices.contains(index) else { return }
            w.exercises.remove(at: index)
        }
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        updateWorkout { $0.exercises.move(fromOffsets: source, toOffset: destination) }
    }

    func setExerciseNote(_ note: String, exerciseID: String) {
        update { d in
            d.exerciseNotes[exerciseID] = note.isEmpty ? nil : note
            if var w = d.activeWorkout {
                for i in w.exercises.indices where w.exercises[i].exerciseID == exerciseID { w.exercises[i].note = note }
                d.activeWorkout = w
            }
        }
    }

    // MARK: Dinlenme

    func startRest(seconds: Int, exerciseIndex: Int?) {
        restTimer = RestTimerState(endsAt: Date().addingTimeInterval(TimeInterval(seconds)), total: seconds, exerciseIndex: exerciseIndex)
        NotificationService.shared.scheduleRestEnd(at: restTimer.endsAt!, enabled: data.settings.gym.restTimerSound)
        LiveActivityService.shared.update(model: self)
        WatchSync.shared.push(model: self)
    }

    func adjustRest(by seconds: Int) {
        guard let end = restTimer.endsAt else { return }
        let newEnd = max(Date().addingTimeInterval(5), end.addingTimeInterval(TimeInterval(seconds)))
        restTimer.endsAt = newEnd
        restTimer.total = max(5, restTimer.total + seconds)
        NotificationService.shared.scheduleRestEnd(at: newEnd, enabled: data.settings.gym.restTimerSound)
        LiveActivityService.shared.update(model: self)
        WatchSync.shared.push(model: self)
    }

    func skipRest() {
        restTimer.endsAt = nil
        NotificationService.shared.cancelRestEnd()
        LiveActivityService.shared.update(model: self)
        WatchSync.shared.push(model: self)
    }

    // MARK: Bitirme

    struct WorkoutResult: Identifiable {
        let id = UUID()
        var session: WorkoutSession
        var records: [PersonalRecord]
        var xpGained: Int
        var previousVolume: Double?
    }

    @discardableResult
    func finishWorkout(rpe: Int?, note: String) -> WorkoutResult? {
        guard var w = data.activeWorkout else { return nil }
        // Tamamlanmamış setleri at, boş hareketleri kaldır
        for i in w.exercises.indices { w.exercises[i].sets.removeAll { !$0.isCompleted } }
        w.exercises.removeAll { $0.sets.isEmpty }
        w.endedAt = Date()
        w.sessionRPE = rpe
        w.note = note

        // Sadece ısınma setleri yapıldıysa antrenman sayılmaz (hacim, XP ve seri şişmesin)
        guard w.completedSetCount > 0 else {
            discardWorkout()
            show(Toast(symbol: "xmark.circle.fill", title: "Antrenman kaydedilmedi",
                       subtitle: "Hiç çalışma seti tamamlanmadı.", tint: Theme.energy))
            return nil
        }

        let previous = finishedSessions.first { $0.programDayID != nil && $0.programDayID == w.programDayID }?.totalVolume
        let records = StrengthMath.newRecords(in: w, history: finishedSessions + [w])
        let xpBefore = AchievementEngine.xp(stats: gamificationStats, unlocked: Set(data.unlockedAchievements.keys))
        let finished = w

        update { d in
            d.sessions.append(finished)
            d.records.append(contentsOf: records)
            d.activeWorkout = nil
            if let pid = finished.programID, let program = ProgramLibrary.program(pid), pid == d.settings.planMode.programID {
                d.settings.programDayIndex = (d.settings.programDayIndex + 1) % max(1, program.days.count)
            }
        }
        restTimer = RestTimerState()
        NotificationService.shared.cancelRestEnd()
        LiveActivityService.shared.end()
        HealthService.shared.saveWorkout(finished, enabled: data.settings.healthKitEnabled)
        NotificationService.shared.schedulePostWorkout(model: self)
        let xpAfter = AchievementEngine.xp(stats: gamificationStats, unlocked: Set(data.unlockedAchievements.keys))
        if !records.isEmpty { celebrate() }
        Haptics.success()
        WatchSync.shared.push(model: self)
        return WorkoutResult(session: finished, records: records, xpGained: max(0, xpAfter - xpBefore), previousVolume: previous)
    }

    func discardWorkout() {
        update { $0.activeWorkout = nil }
        restTimer = RestTimerState()
        NotificationService.shared.cancelRestEnd()
        LiveActivityService.shared.end()
        WatchSync.shared.push(model: self)
    }

    func deleteSession(_ id: UUID) {
        update { d in
            let ended = d.sessions.first { $0.id == id }?.endedAt
            d.sessions.removeAll { $0.id == id }
            if let ended {
                d.records.removeAll { abs($0.date.timeIntervalSince(ended)) < 1 }
            }
        }
    }

    func choosePlan(_ mode: PlanMode) {
        updateSettings { s in
            s.planMode = mode
            s.programDayIndex = 0
            s.hasSeenAutoPlanSuggestion = true
        }
    }

    // MARK: Hareket geçmişi

    func history(of exerciseID: String) -> [(date: Date, sets: [SetLog])] {
        finishedSessions.compactMap { s in
            let sets = s.exercises.filter { $0.exerciseID == exerciseID }.flatMap(\.completedWorkingSets)
            return sets.isEmpty ? nil : (s.startedAt, sets)
        }
    }

    func bestE1RM(of exerciseID: String) -> Double? {
        history(of: exerciseID).flatMap(\.sets).map { StrengthMath.estimated1RM(weight: $0.weightKg, reps: $0.reps) }.max()
    }

    func exercise(_ id: String) -> Exercise? {
        ExerciseCatalog.exercise(id) ?? data.customExercises.first { $0.id == id }
    }

    var allExercises: [Exercise] { ExerciseCatalog.all + data.customExercises }

    func saveCustomExercise(_ e: Exercise) {
        update { d in
            if let i = d.customExercises.firstIndex(where: { $0.id == e.id }) { d.customExercises[i] = e } else { d.customExercises.append(e) }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
