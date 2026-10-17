import SwiftUI
import Observation
import FormaKit
import WidgetKit

/// Uygulamanın merkezi durumu. Tüm veri değişiklikleri buradan geçer.
@MainActor
@Observable
final class AppModel {

    // MARK: Kalıcı veri

    private(set) var data: FormaData
    private(set) var revision = 0
    @ObservationIgnored let storage: FormaStorage

    // MARK: Geçici durum

    /// Saat: gün değişimi ve toparlanma hesapları için. Dakikada bir güncellenir.
    private(set) var now = Date()
    var restTimer = RestTimerState()
    var toast: Toast?
    var showConfetti = false
    var pendingRoute: AppRoute?
    var health = HealthSnapshot()
    var weeklyCoachText: String?

    @ObservationIgnored private var cache: [String: Any] = [:]
    @ObservationIgnored private var cacheRevision = -1
    @ObservationIgnored private var cacheMinute = -1
    @ObservationIgnored private var snapshotTask: Task<Void, Never>?
    @ObservationIgnored private var clockTask: Task<Void, Never>?

    init(storage: FormaStorage = AppConfig.storage) {
        self.storage = storage
        self.data = storage.load()
        if let active = data.activeWorkout, active.exercises.isEmpty {
            data.activeWorkout = nil
        }
        IntentBridge.handler = { [weak self] event in self?.handle(event) }
        IntentBridge.routeHandler = { [weak self] route in self?.open(route: route) }
        mergeInbox()
        startClock()
    }

    // MARK: Değişiklik

    func update(_ change: (inout FormaData) -> Void) {
        change(&data)
        revision &+= 1
        storage.save(data)
        scheduleSideEffects()
    }

    private func scheduleSideEffects() {
        snapshotTask?.cancel()
        snapshotTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard let self, !Task.isCancelled else { return }
            self.checkAchievements()
            self.writeWidgetSnapshot()
            WatchSync.shared.push(model: self)
        }
    }

    func flush() {
        storage.flush(data)
        writeWidgetSnapshot()
    }

    private func startClock() {
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                self?.tick()
            }
        }
    }

    func tick() {
        let previousDay = DayKey.key(now)
        now = Date()
        if DayKey.key(now) != previousDay {
            NotificationService.shared.reschedule(model: self)
            writeWidgetSnapshot()
        }
    }

    // MARK: Ön bellek

    /// Pahalı hesapları veri ve dakika değişene kadar saklar.
    private func memo<T>(_ key: String, _ make: () -> T) -> T {
        let minute = Int(now.timeIntervalSince1970 / 60)
        if cacheRevision != revision || cacheMinute != minute {
            cache.removeAll(keepingCapacity: true)
            cacheRevision = revision
            cacheMinute = minute
        }
        if let v = cache[key] as? T { return v }
        let v = make()
        cache[key] = v
        return v
    }

    // MARK: Temel türetilmiş değerler

    var calendar: Calendar { .forma }
    var hasProfile: Bool { data.profile != nil }
    var profile: UserProfile { data.profile ?? UserProfile() }
    var settings: AppSettings { data.settings }
    var todayKey: String { DayKey.key(now) }
    var isRamadan: Bool { data.settings.ramadan.enabled }

    func isToday(_ date: Date) -> Bool { DayKey.key(date) == todayKey }

    var latestWeight: Double {
        memo("latestWeight") {
            let local = data.measurements.compactMap { m in m.weightKg.map { (m.date, $0) } }
            let all = local + health.weights.map { ($0.date, $0.kg) }
            return all.max { $0.0 < $1.0 }?.1 ?? profile.weightKg
        }
    }

    var weightPoints: [WeightPoint] {
        memo("weightPoints") {
            var pts = data.measurements.compactMap { m in m.weightKg.map { WeightPoint(date: m.date, kg: $0) } }
            let localDays = Set(pts.map { DayKey.key($0.date) })
            pts += health.weights.filter { !localDays.contains(DayKey.key($0.date)) }
            return pts.sorted { $0.date < $1.date }
        }
    }

    var adaptiveEstimate: AdaptiveExpenditure.Estimate? {
        memo("adaptive") {
            guard data.settings.useAdaptiveExpenditure else { return nil }
            let formula = NutritionEngine.formulaTDEE(profile: profile, weightKg: latestWeight)
            return AdaptiveExpenditure.estimate(dailyIntake: dailyIntakeHistory(days: 35), weights: weightPoints,
                                                formulaTDEE: formula, now: now)
        }
    }

    var baseTargets: DailyTargets {
        memo("targets") {
            let adaptive = adaptiveEstimate.flatMap { $0.confidence >= 0.5 ? $0.tdee : nil }
            return NutritionEngine.targets(profile: profile, settings: data.settings, adaptiveTDEE: adaptive, latestWeightKg: latestWeight)
        }
    }

    /// Bugünün hedefleri: antrenman günü su hedefi artar.
    var targets: DailyTargets {
        var t = baseTargets
        if !data.settings.targetsAreManual {
            let minutes = trainedToday ? max(30, todaySessions.reduce(0) { $0 + $1.duration } / 60)
                                       : (plannedTrainingToday ? Double(profile.sessionMinutes) : 0)
            t.waterMl = HydrationEngine.adjustedForTraining(base: t.waterMl, plannedMinutes: minutes)
        }
        return t
    }

    // MARK: Bugün

    var todayFoodLogs: [FoodLog] {
        memo("todayFood") { data.foodLogs.filter { isToday($0.date) }.sorted { $0.date < $1.date } }
    }

    var todayWaterLogs: [WaterLog] {
        memo("todayWater") { data.waterLogs.filter { isToday($0.date) }.sorted { $0.date < $1.date } }
    }

    var todayWaterMl: Double { todayWaterLogs.reduce(0) { $0 + $1.ml } }

    var todayCaffeineMg: Double {
        let drinks = todayWaterLogs.reduce(0) { $0 + $1.caffeineMg }
        let pills = todaySupplementLogs.reduce(0.0) { sum, log in
            sum + (supplement(log.supplementID)?.caffeinePerDose ?? 0)
        }
        return drinks + pills
    }

    var todaySupplementLogs: [SupplementLog] {
        memo("todaySupp") { data.supplementLogs.filter { isToday($0.date) } }
    }

    /// Yemek + içecek + protein tozu toplamı.
    var todayMacros: Macros {
        memo("todayMacros") {
            var m = todayFoodLogs.reduce(Macros.zero) { $0 + $1.macros }
            for w in todayWaterLogs {
                m.kcal += w.kcal
                m.protein += w.protein
            }
            for log in todaySupplementLogs {
                guard let s = supplement(log.supplementID), s.proteinPerDose > 0 else { continue }
                let doses = s.dose > 0 ? log.amount / s.dose : 1
                m.protein += s.proteinPerDose * doses
                m.kcal += s.proteinPerDose * doses * 4.6
            }
            return m
        }
    }

    func supplement(_ id: UUID) -> Supplement? { data.supplements.first { $0.id == id } }

    var activeSupplements: [Supplement] { data.supplements.filter(\.isActive) }

    /// Bugün gösterilecek takviyeler (sadece antrenman günü olanlar antrenman yoksa gizlenir).
    var todaysSupplements: [Supplement] {
        activeSupplements.filter { !$0.onlyTrainingDays || trainedToday || plannedTrainingToday }
    }

    func takenCount(_ s: Supplement) -> Int { todaySupplementLogs.filter { $0.supplementID == s.id }.count }
    func isDone(_ s: Supplement) -> Bool { takenCount(s) >= max(1, s.timesPerDay) }

    var creatine: Supplement? { activeSupplements.first { $0.kind == .creatine } }

    var creatineTakenToday: Bool { creatine.map(isDone) ?? false }

    // MARK: Antrenman

    var finishedSessions: [WorkoutSession] {
        memo("sessions") { data.sessions.filter(\.isFinished).sorted { $0.startedAt > $1.startedAt } }
    }

    var todaySessions: [WorkoutSession] { finishedSessions.filter { isToday($0.startedAt) } }
    var trainedToday: Bool { !todaySessions.isEmpty }

    var sessionsThisWeek: [WorkoutSession] {
        let start = calendar.startOfWeek(for: now)
        return finishedSessions.filter { $0.startedAt >= start }
    }

    /// Bugün antrenman planlı mı? Haftalık hedefe ulaşılmadıysa ve dün yapılmadıysa (yeni başlayanlar) evet.
    var plannedTrainingToday: Bool {
        guard !trainedToday else { return false }
        let remaining = profile.trainingDaysPerWeek - sessionsThisWeek.count
        guard remaining > 0 else { return false }
        if profile.experience == .beginner, let last = finishedSessions.first, calendar.isDateInYesterday(last.startedAt) {
            // Yeni başlayanlar için ardışık gün yerine 1 gün dinlenme önerilir; haftada kalan gün çoksa yine de izin ver
            let daysLeft = 7 - (calendar.dateComponents([.weekday], from: now).weekday.map { ($0 + 5) % 7 } ?? 0)
            return remaining >= daysLeft
        }
        return true
    }

    var recovery: [RecoveryEngine.MuscleState] {
        memo("recovery") {
            RecoveryEngine.states(sessions: finishedSessions + (data.activeWorkout.map { [$0] } ?? []),
                                  external: data.externalActivities + health.activities,
                                  soreness: data.soreness, experience: profile.experience, now: now)
        }
    }

    func recovery(of muscle: MuscleGroup) -> RecoveryEngine.MuscleState? { recovery.first { $0.muscle == muscle } }

    var weeklyVolume: [VolumeEngine.MuscleVolume] {
        memo("volume") {
            VolumeEngine.weekly(sessions: finishedSessions, experience: profile.experience, focus: profile.focusMuscles, weekContaining: now)
        }
    }

    var readiness: ReadinessEngine.Result? {
        memo("readiness") {
            let readyMuscles = recovery.filter { $0.muscle.isLarge }
            let avg = readyMuscles.isEmpty ? nil : readyMuscles.reduce(0) { $0 + $1.percent } / Double(readyMuscles.count)
            return ReadinessEngine.evaluate(.init(
                sleepHours: health.sleepHours, sleepGoalHours: data.settings.sleepHourGoal,
                hrvToday: health.hrv, hrvBaseline: health.hrvBaseline,
                restingHRToday: health.restingHR, restingHRBaseline: health.restingHRBaseline,
                muscleReadiness: avg, feeling: data.feelings[todayKey]))
        }
    }

    var lowReadiness: Bool { readiness?.level == .low }

    var currentProgram: WorkoutProgram? {
        data.settings.planMode.programID.flatMap(ProgramLibrary.program)
    }

    /// Sıradaki planlı antrenman.
    var nextPlan: PlannedWorkout {
        memo("nextPlan") {
            if let program = currentProgram, !program.days.isEmpty {
                let index = data.settings.programDayIndex % program.days.count
                let day = program.days[index]
                let minutes = day.slots.reduce(0.0) { sum, slot in
                    let rest = Double(slot.restSeconds ?? ExerciseCatalog.exercise(slot.exerciseID)?.restSeconds ?? 90)
                    return sum + Double(slot.sets) * (45 + rest) + 60
                } / 60 + 6
                return PlannedWorkout(title: day.name, focus: day.focus, slots: day.slots, programID: program.id,
                                      programDayID: day.id, rationale: program.notes.prefix(1).map { $0 }, minutes: Int(minutes))
            }
            let g = ProgramGenerator.generate(profile: profile, recovery: recovery, volume: weeklyVolume,
                                              sessions: finishedSessions, lowReadiness: lowReadiness, now: now)
            return PlannedWorkout(title: g.title, focus: g.focus, slots: g.slots, programID: nil, programDayID: nil,
                                  rationale: g.rationale, minutes: g.estimatedMinutes)
        }
    }

    /// Hazır programda 6 hafta veya 18 antrenman tamamlanınca otomatik plana geçiş öner.
    var shouldSuggestAutoPlan: Bool {
        guard let program = currentProgram, program.level == .beginner, !data.settings.hasSeenAutoPlanSuggestion else { return false }
        let done = finishedSessions.filter { $0.programID == program.id }
        guard let first = done.last else { return false }
        return done.count >= 18 || calendar.days(from: first.startedAt, to: now) >= 42
    }

    // MARK: Seriler ve oyunlaştırma

    var creatineStreak: Int {
        memo("creatineStreak") {
            guard let c = creatine else { return 0 }
            let days = Set(data.supplementLogs.filter { $0.supplementID == c.id }.map { DayKey.key($0.date) })
            return StreakEngine.dailyStreak(days: days, now: now)
        }
    }

    var waterStreak: Int {
        memo("waterStreak") {
            StreakEngine.dailyStreak(days: daysMeeting { $0.water >= $0.waterTarget * 0.95 }, now: now)
        }
    }

    var proteinStreak: Int {
        memo("proteinStreak") {
            StreakEngine.dailyStreak(days: daysMeeting { $0.protein >= $0.proteinTarget * 0.9 }, now: now)
        }
    }

    var weeklyWorkoutStreak: Int {
        memo("weeklyStreak") {
            StreakEngine.weeklyStreak(sessionDates: finishedSessions.map(\.startedAt), target: profile.trainingDaysPerWeek, now: now)
        }
    }

    private struct DaySummary { var water: Double; var protein: Double; var waterTarget: Double; var proteinTarget: Double }

    private func daysMeeting(_ predicate: (DaySummary) -> Bool) -> Set<String> {
        var water: [String: Double] = [:]
        var protein: [String: Double] = [:]
        for w in data.waterLogs { water[DayKey.key(w.date), default: 0] += w.ml }
        for f in data.foodLogs { protein[DayKey.key(f.date), default: 0] += f.macros.protein }
        for l in data.supplementLogs {
            if let s = supplement(l.supplementID), s.proteinPerDose > 0 { protein[DayKey.key(l.date), default: 0] += s.proteinPerDose }
        }
        let t = baseTargets
        var result: Set<String> = []
        for key in Set(water.keys).union(protein.keys) {
            let summary = DaySummary(water: water[key] ?? 0, protein: protein[key] ?? 0, waterTarget: t.waterMl, proteinTarget: t.proteinG)
            if predicate(summary) { result.insert(key) }
        }
        return result
    }

    var gamificationStats: GamificationStats {
        memo("gstats") {
            let sessions = finishedSessions
            let sets = sessions.reduce(0) { $0 + $1.completedSetCount }
            let volume = sessions.reduce(0) { $0 + $1.totalVolume }
            let early = sessions.filter { calendar.component(.hour, from: $0.startedAt) < 8 }.count
            return GamificationStats(totalWorkouts: sessions.count, totalSets: sets, totalVolumeKg: volume,
                                     creatineStreak: creatineStreak, waterGoalStreak: waterStreak, proteinGoalStreak: proteinStreak,
                                     weeklyStreak: weeklyWorkoutStreak, prCount: data.records.count,
                                     bestSessionVolume: sessions.map(\.totalVolume).max() ?? 0,
                                     measurementCount: data.measurements.count, photoCount: data.photos.count, earlyWorkouts: early)
        }
    }

    var level: AchievementEngine.Level {
        AchievementEngine.level(for: AchievementEngine.xp(stats: gamificationStats, unlocked: Set(data.unlockedAchievements.keys)))
    }

    private func checkAchievements() {
        let unlocked = AchievementEngine.unlocked(by: gamificationStats)
        let new = unlocked.subtracting(data.unlockedAchievements.keys)
        guard !new.isEmpty else { return }
        update { d in for id in new { d.unlockedAchievements[id] = Date() } }
        if let first = AchievementEngine.all.first(where: { new.contains($0.id) }) {
            show(Toast(symbol: first.symbol, title: "Rozet: \(first.title)", subtitle: first.detail, tint: Theme.gold))
            Haptics.success()
        }
    }

    // MARK: Geçmiş

    func dailyIntakeHistory(days: Int) -> [Date: Double] {
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
        var result: [Date: Double] = [:]
        for f in data.foodLogs where f.date >= start {
            result[calendar.startOfDay(for: f.date), default: 0] += f.macros.kcal
        }
        for w in data.waterLogs where w.date >= start && w.kcal > 0 {
            result[calendar.startOfDay(for: w.date), default: 0] += w.kcal
        }
        return result
    }

    func macros(on day: Date) -> Macros {
        let key = DayKey.key(day)
        return data.foodLogs.filter { DayKey.key($0.date) == key }.reduce(Macros.zero) { $0 + $1.macros }
    }

    func waterMl(on day: Date) -> Double {
        let key = DayKey.key(day)
        return data.waterLogs.filter { DayKey.key($0.date) == key }.reduce(0) { $0 + $1.ml }
    }

    var creatineSaturation: Double {
        memo("saturation") {
            guard let c = creatine else { return 0 }
            var grams: [Date: Double] = [:]
            for l in data.supplementLogs where l.supplementID == c.id {
                let g = c.unit == "g" ? l.amount : c.dose
                grams[calendar.startOfDay(for: l.date), default: 0] += g
            }
            return SupplementEngine.creatineSaturation(dailyGrams: grams, until: now)
        }
    }

    // MARK: Yönlendirme ve bildirim

    func open(route: String) {
        switch route {
        case "workout/start": pendingRoute = .startWorkout
        case "nutrition/add": pendingRoute = .addFood
        case "water": pendingRoute = .water
        case "today": pendingRoute = .today
        default: break
        }
    }

    func show(_ toast: Toast) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.toast = toast }
        let id = toast.id
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            guard let self, self.toast?.id == id else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.toast = nil }
        }
    }

    func celebrate() {
        showConfetti = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.showConfetti = false
        }
    }

    // MARK: Dış olaylar

    func mergeInbox() {
        let pending = storage.pendingEvents()
        guard !pending.isEmpty else { return }
        update { $0.apply(pending.map(\.1)) }
        storage.removeEvents(pending.map(\.0))
    }

    func handle(_ event: InboxEvent) {
        switch event {
        case let .water(_, _, ml, beverage):
            logWater(ml: ml, beverage: beverage)
        case let .supplement(_, _, sid, kind, _):
            if let s = sid.flatMap(supplement) ?? activeSupplements.first(where: { $0.kind == kind }) {
                take(s)
            }
        case let .setCompleted(_, _, exerciseIndex, setIndex, _, _):
            if exerciseIndex < 0 {
                completeNextSet()
            } else {
                completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
            }
        case let .restAdjust(_, _, seconds):
            adjustRest(by: seconds)
        case .skipRest:
            skipRest()
        case let .feeling(_, _, value):
            setFeeling(value)
        case .food, .weight:
            update { $0.apply([event]) }
        }
    }

    // MARK: Widget özeti

    func writeWidgetSnapshot() {
        let t = targets
        let items = todaysSupplements.map {
            WidgetSnapshot.SupplementItem(id: $0.id, kind: $0.kind, name: $0.name, dose: $0.doseLabel, taken: isDone($0))
        }
        let plan = nextPlan
        let snapshot = WidgetSnapshot(
            day: todayKey, generatedAt: Date(), targets: t, kcal: todayMacros.kcal, protein: todayMacros.protein,
            waterMl: todayWaterMl, supplements: items,
            nextWorkoutTitle: trainedToday ? nil : plan.title, nextWorkoutFocus: plan.focus, nextWorkoutMinutes: plan.minutes,
            trainedToday: trainedToday, creatineStreak: creatineStreak, weekWorkouts: sessionsThisWeek.count,
            weekTarget: profile.trainingDaysPerWeek, level: level.level, levelProgress: level.progress, readiness: readiness?.score)
        storage.writeSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Yardımcı türler

struct PlannedWorkout: Equatable {
    var title: String
    var focus: String
    var slots: [ExerciseSlot]
    var programID: String?
    var programDayID: String?
    var rationale: [String]
    var minutes: Int
}

struct RestTimerState: Equatable {
    var endsAt: Date?
    var total: Int = 90
    var exerciseIndex: Int?

    var isRunning: Bool { endsAt.map { $0 > Date() } ?? false }
    func remaining(at date: Date = Date()) -> TimeInterval { max(0, (endsAt ?? date).timeIntervalSince(date)) }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    var symbol: String
    var title: String
    var subtitle: String?
    var tint: Color = Theme.lime
}

enum AppRoute: Equatable {
    case today, startWorkout, addFood, water
}

struct HealthSnapshot: Equatable {
    var sleepHours: Double?
    var hrv: Double?
    var hrvBaseline: [Double] = []
    var restingHR: Double?
    var restingHRBaseline: [Double] = []
    var steps: Double?
    var activeEnergy: Double?
    var weights: [WeightPoint] = []
    var activities: [RecoveryEngine.ExternalActivity] = []
    var lastUpdated: Date?
}
