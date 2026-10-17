import XCTest
@testable import FormaKit

final class CatalogTests: XCTestCase {

    func testExerciseIDsAreUnique() {
        let ids = ExerciseCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryExerciseHasImageAndCues() {
        for ex in ExerciseCatalog.all {
            XCTAssertFalse(ex.datasetIDs.isEmpty, "\(ex.id) görselsiz")
            XCTAssertFalse(ex.cues.isEmpty, "\(ex.id) form ipucu yok")
            XCTAssertFalse(ex.primary.isEmpty, "\(ex.id) ana kas yok")
            XCTAssertLessThanOrEqual(ex.repLow, ex.repHigh)
        }
    }

    func testProgramsReferenceExistingExercises() {
        for program in ProgramLibrary.all {
            for day in program.days {
                for slot in day.slots {
                    XCTAssertNotNil(ExerciseCatalog.exercise(slot.exerciseID), "\(program.id): \(slot.exerciseID)")
                    for alt in slot.alternatives {
                        XCTAssertNotNil(ExerciseCatalog.exercise(alt), "\(program.id): alt \(alt)")
                    }
                }
            }
        }
    }

    func testGeneratorPreferencesExist() {
        for (_, ids) in ProgramGenerator.preferences {
            for id in ids { XCTAssertNotNil(ExerciseCatalog.exercise(id), id) }
        }
    }

    func testEveryMuscleHasAnExercise() {
        for m in MuscleGroup.allCases {
            XCTAssertFalse(ExerciseCatalog.exercises(for: m).isEmpty, "\(m) için hareket yok")
        }
    }

    func testHomeProgramWorksWithHomeEquipment() {
        let program = ProgramLibrary.homeDumbbell
        for day in program.days {
            for slot in day.slots {
                XCTAssertNotNil(slot.resolvedExercise(equipment: Equipment.homeDumbbells), slot.exerciseID)
            }
        }
    }

    func testFoodIDsUniqueAndSearch() {
        let ids = FoodDatabase.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(FoodDatabase.search("doner", in: FoodDatabase.all).isEmpty, false)
        XCTAssertEqual(FoodDatabase.search("mercimek corba", in: FoodDatabase.all).first?.id, "mercimek-corbasi")
        XCTAssertEqual(FoodDatabase.search("YUMURTA", in: FoodDatabase.all).first?.id, "egg")
    }

    func testFoodMacrosAreConsistent() {
        // Atwater: kcal ≈ 4P + 4C + 9F (lif ve alkol farkı için geniş tolerans)
        for food in FoodDatabase.all where food.per100g.kcal > 40 {
            let m = food.per100g
            let calc = m.protein * 4 + m.carbs * 4 + m.fat * 9
            XCTAssertEqual(calc, m.kcal, accuracy: max(40, m.kcal * 0.2), food.name)
        }
    }
}

final class NutritionTests: XCTestCase {

    let profile = UserProfile(sex: .male, birthYear: 2000, heightCm: 178, weightKg: 75, goal: .buildMuscle,
                              experience: .beginner, activityLevel: .light, trainingDaysPerWeek: 3, sessionMinutes: 60)

    func testMifflinStJeor() {
        let date = Calendar.forma.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        // 10*75 + 6.25*178 - 5*26 + 5 = 1737.5
        XCTAssertEqual(NutritionEngine.bmr(profile: profile, on: date), 1737.5, accuracy: 0.01)
    }

    func testProteinWithinISSNRange() {
        let t = NutritionEngine.targets(profile: profile, settings: AppSettings())
        XCTAssertGreaterThanOrEqual(t.proteinG / 75, 1.4)
        XCTAssertLessThanOrEqual(t.proteinG / 75, 2.4)
    }

    func testMacrosAddUpToCalories() {
        for goal in Goal.allCases {
            var p = profile
            p.goal = goal
            let t = NutritionEngine.targets(profile: p, settings: AppSettings())
            let kcal = t.proteinG * 4 + t.carbsG * 4 + t.fatG * 9
            XCTAssertEqual(kcal, t.kcal, accuracy: 30, "\(goal)")
        }
    }

    func testFatLossDeficitIsModerate() {
        var p = profile
        p.goal = .loseFat
        let tdee = NutritionEngine.formulaTDEE(profile: p)
        let kcal = NutritionEngine.goalCalories(tdee: tdee, profile: p)
        let weeklyLoss = (tdee - kcal) * 7 / 7700
        XCTAssertGreaterThan(weeklyLoss / 75, 0.004)
        XCTAssertLessThan(weeklyLoss / 75, 0.011)
    }

    func testOverweightProteinUsesReferenceWeight() {
        var p = profile
        p.weightKg = 120
        let ref = NutritionEngine.proteinReferenceWeight(profile: p)
        XCTAssertLessThan(ref, 85)
    }

    func testManualTargetsWin() {
        var s = AppSettings()
        s.targetsAreManual = true
        s.manualTargets = DailyTargets(kcal: 1234, proteinG: 99, carbsG: 100, fatG: 50, fiberG: 25, waterMl: 2000, creatineG: 3)
        XCTAssertEqual(NutritionEngine.targets(profile: profile, settings: s).kcal, 1234)
    }

    func testWeightTrendSmoothsNoise() {
        let cal = Calendar.forma
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let points = (0..<30).map { i in
            WeightPoint(date: cal.date(byAdding: .day, value: i, to: start)!, kg: 80 - Double(i) * 0.05 + (i % 2 == 0 ? 0.8 : -0.8))
        }
        let trend = WeightTrend.smoothed(points)
        XCTAssertEqual(trend.count, 30)
        let swings = zip(trend, trend.dropFirst()).map { abs($1.kg - $0.kg) }.max()!
        XCTAssertLessThan(swings, 0.3)
        let rate = WeightTrend.weeklyRate(points, now: points.last!.date)!
        XCTAssertLessThan(rate, 0)
    }

    func testAdaptiveExpenditureFindsMaintenance() {
        let cal = Calendar.forma
        let start = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        var intake: [Date: Double] = [:]
        var weights: [WeightPoint] = []
        // Gerçek harcama 2600, alım 2100 → haftada ~0,45 kg kayıp
        for i in 0..<28 {
            let d = cal.date(byAdding: .day, value: i, to: start)!
            intake[cal.startOfDay(for: d)] = 2100
            weights.append(WeightPoint(date: d, kg: 80 - Double(i) * 500 / 7700))
        }
        let now = cal.date(byAdding: .day, value: 27, to: start)!
        let e = AdaptiveExpenditure.estimate(dailyIntake: intake, weights: weights, formulaTDEE: 2400, now: now)
        XCTAssertNotNil(e)
        XCTAssertEqual(e!.tdee, 2600, accuracy: 120)
    }
}

final class SupplementTests: XCTestCase {

    func testCreatineDoseRange() {
        for w in stride(from: 45.0, through: 140.0, by: 5) {
            let d = SupplementEngine.creatineMaintenanceDose(weightKg: w)
            XCTAssertTrue((3...5).contains(d), "\(w) kg → \(d) g")
        }
    }

    func testCreatineSaturationTimeline() {
        let cal = Calendar.forma
        let start = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        func days(_ n: Int, grams: (Int) -> Double) -> [Date: Double] {
            var r: [Date: Double] = [:]
            for i in 0..<n { r[cal.date(byAdding: .day, value: i, to: start)!] = grams(i) }
            return r
        }
        let five = SupplementEngine.creatineSaturation(dailyGrams: days(28) { _ in 5 }, until: cal.date(byAdding: .day, value: 27, to: start)!)
        XCTAssertGreaterThanOrEqual(five, 95)
        let fiveEarly = SupplementEngine.creatineSaturation(dailyGrams: days(7) { _ in 5 }, until: cal.date(byAdding: .day, value: 6, to: start)!)
        XCTAssertLessThan(fiveEarly, 60)
        let loading = SupplementEngine.creatineSaturation(dailyGrams: days(6) { _ in 20 }, until: cal.date(byAdding: .day, value: 5, to: start)!)
        XCTAssertGreaterThanOrEqual(loading, 90)
    }

    func testHydrationTargets() {
        XCTAssertEqual(HydrationEngine.dailyTarget(weightKg: 70, sex: .male, trainingMinutes: 0, hotWeather: false), 2100)
        XCTAssertEqual(HydrationEngine.dailyTarget(weightKg: 50, sex: .female, trainingMinutes: 0, hotWeather: false), 1600)
        XCTAssertEqual(HydrationEngine.dailyTarget(weightKg: 70, sex: .male, trainingMinutes: 60, hotWeather: true), 3100)
    }
}

final class StrengthTests: XCTestCase {

    func testOneRepMax() {
        XCTAssertEqual(StrengthMath.estimated1RM(weight: 100, reps: 1), 100)
        let e = StrengthMath.estimated1RM(weight: 100, reps: 5)
        XCTAssertEqual(e, 114.4, accuracy: 1.5)
    }

    func testPlates() {
        let r = StrengthMath.plates(target: 100, bar: 20, available: [25, 20, 15, 10, 5, 2.5, 1.25])
        XCTAssertEqual(r.perSide, [25, 15])
        XCTAssertEqual(r.remainder, 0)
        let odd = StrengthMath.plates(target: 63, bar: 20, available: [20, 10, 5, 2.5, 1.25])
        XCTAssertEqual(odd.achievable, 62.5)
    }

    func testWarmupsBelowWorkingWeight() {
        let bench = ExerciseCatalog.exercise("barbell-bench-press")!
        let w = StrengthMath.warmups(workingWeight: 80, exercise: bench, gym: GymSettings())
        XCTAssertFalse(w.isEmpty)
        XCTAssertTrue(w.allSatisfy { $0.weight < 80 })
        XCTAssertEqual(w.map(\.weight), w.map(\.weight).sorted())
    }

    private func session(_ exID: String, weight: Double, reps: [Int], daysAgo: Double, rir: Int? = nil) -> WorkoutSession {
        let date = Date().addingTimeInterval(-daysAgo * 86_400)
        let sets = reps.map { SetLog(kind: .working, weightKg: weight, reps: $0, rir: rir, isCompleted: true, completedAt: date) }
        return WorkoutSession(title: "Test", startedAt: date, endedAt: date.addingTimeInterval(3600),
                              exercises: [SessionExercise(exerciseID: exID, targetReps: 10...12, restSeconds: 90, sets: sets)])
    }

    func testProgressionIncreasesWhenTopOfRangeHit() {
        let ex = ExerciseCatalog.exercise("machine-chest-press")!
        let s = [session(ex.id, weight: 40, reps: [12, 12, 12], daysAgo: 3)]
        let sug = ProgressionEngine.suggest(exercise: ex, setCount: 3, repRange: 10...12, sessions: s, gym: GymSettings())
        XCTAssertEqual(sug.kind, .increase)
        XCTAssertEqual(sug.weightKg, 45)
        XCTAssertEqual(sug.reps, [10, 10, 10])
    }

    func testProgressionAddsRepsOtherwise() {
        let ex = ExerciseCatalog.exercise("dumbbell-curl")!
        let s = [session(ex.id, weight: 10, reps: [12, 11, 10], daysAgo: 3)]
        let sug = ProgressionEngine.suggest(exercise: ex, setCount: 3, repRange: 10...15, sessions: s, gym: GymSettings())
        XCTAssertEqual(sug.kind, .repsUp)
        XCTAssertEqual(sug.weightKg, 10)
        XCTAssertEqual(sug.reps, [13, 12, 11])
    }

    func testDeloadAfterTwoFailedSessions() {
        let ex = ExerciseCatalog.exercise("barbell-squat")!
        let s = [session(ex.id, weight: 100, reps: [4, 3, 3], daysAgo: 2), session(ex.id, weight: 100, reps: [4, 4, 3], daysAgo: 5)]
        let sug = ProgressionEngine.suggest(exercise: ex, setCount: 3, repRange: 5...8, sessions: s, gym: GymSettings())
        XCTAssertEqual(sug.kind, .deload)
        XCTAssertEqual(sug.weightKg, 90)
    }

    func testLowReadinessHolds() {
        let ex = ExerciseCatalog.exercise("machine-chest-press")!
        let s = [session(ex.id, weight: 40, reps: [12, 12, 12], daysAgo: 3)]
        let sug = ProgressionEngine.suggest(exercise: ex, setCount: 3, repRange: 10...12, sessions: s, gym: GymSettings(), lowReadiness: true)
        XCTAssertNotEqual(sug.kind, .increase)
    }

    func testRecordsDetected() {
        let ex = "barbell-bench-press"
        let old = session(ex, weight: 60, reps: [8, 8, 8], daysAgo: 7)
        let new = session(ex, weight: 65, reps: [8, 7, 6], daysAgo: 0)
        let prs = StrengthMath.newRecords(in: new, history: [old, new])
        XCTAssertTrue(prs.contains { $0.kind == .heaviestWeight && $0.weightKg == 65 })
        XCTAssertTrue(StrengthMath.newRecords(in: old, history: [old]).isEmpty, "ilk seans rekor sayılmaz")
    }
}

final class RecoveryTests: XCTestCase {

    private func chestSession(hoursAgo: Double, sets: Int, rir: Int?) -> WorkoutSession {
        let date = Date().addingTimeInterval(-hoursAgo * 3600)
        let logs = (0..<sets).map { _ in SetLog(weightKg: 40, reps: 10, rir: rir, isCompleted: true, completedAt: date) }
        return WorkoutSession(title: "Göğüs", startedAt: date, endedAt: date,
                              exercises: [SessionExercise(exerciseID: "machine-chest-press", targetReps: 10...12, restSeconds: 90, sets: logs)])
    }

    private func state(_ m: MuscleGroup, _ sessions: [WorkoutSession], now: Date = Date()) -> RecoveryEngine.MuscleState {
        RecoveryEngine.states(sessions: sessions, experience: .beginner, now: now).first { $0.muscle == m }!
    }

    func testFreshWhenNoTraining() {
        XCTAssertEqual(state(.chest, []).percent, 100)
    }

    func testFatiguedRightAfterHeavySession() {
        let s = state(.chest, [chestSession(hoursAgo: 1, sets: 6, rir: 1)])
        XCTAssertEqual(s.status, .fatigued)
        XCTAssertGreaterThan(s.hoursUntilReady, 24)
    }

    func testRecoversWithinThreeDays() {
        let s = state(.chest, [chestSession(hoursAgo: 72, sets: 6, rir: 1)])
        XCTAssertGreaterThanOrEqual(s.percent, 80)
    }

    func testSecondaryMuscleLessFatigued() {
        let sessions = [chestSession(hoursAgo: 2, sets: 4, rir: 2)]
        XCTAssertGreaterThan(state(.triceps, sessions).percent, state(.chest, sessions).percent)
    }

    func testFailureSetsFatigueMore() {
        let easy = state(.chest, [chestSession(hoursAgo: 24, sets: 4, rir: 4)])
        let hard = state(.chest, [chestSession(hoursAgo: 24, sets: 4, rir: 0)])
        XCTAssertGreaterThan(easy.percent, hard.percent)
    }

    func testSorenessOverridesEstimate() {
        let soreness = [RecoveryEngine.Soreness(muscle: .quads, date: Date(), level: 3)]
        let s = RecoveryEngine.states(sessions: [], soreness: soreness, experience: .beginner).first { $0.muscle == .quads }!
        XCTAssertLessThan(s.percent, 50)
    }

    func testRunningFatiguesLegs() {
        let run = RecoveryEngine.ExternalActivity(kind: .running, start: Date().addingTimeInterval(-3600), minutes: 60)
        let s = RecoveryEngine.states(sessions: [], external: [run], experience: .beginner)
        XCTAssertLessThan(s.first { $0.muscle == .calves }!.percent, 100)
        XCTAssertEqual(s.first { $0.muscle == .chest }!.percent, 100)
    }

    func testWeeklyVolumeCountsFractionalSets() {
        let session = chestSession(hoursAgo: 1, sets: 4, rir: 2)
        let v = VolumeEngine.weekly(sessions: [session], experience: .beginner, focus: [], weekContaining: session.startedAt)
        XCTAssertEqual(v.first { $0.muscle == .chest }!.sets, 4)
        XCTAssertEqual(v.first { $0.muscle == .triceps }!.sets, 2)
    }
}

final class GeneratorTests: XCTestCase {

    let profile = UserProfile(experience: .beginner, trainingDaysPerWeek: 3, sessionMinutes: 60, equipment: Equipment.fullGym)

    func testFreshUserGetsFullBody() {
        let rec = RecoveryEngine.states(sessions: [], experience: .beginner)
        let vol = VolumeEngine.weekly(sessions: [], experience: .beginner, focus: [])
        let w = ProgramGenerator.generate(profile: profile, recovery: rec, volume: vol, sessions: [], lowReadiness: false)
        XCTAssertEqual(w.title, "Tam Vücut")
        XCTAssertGreaterThanOrEqual(w.slots.count, 4)
        XCTAssertLessThanOrEqual(w.estimatedMinutes, 70)
        let muscles = Set(w.slots.compactMap { ExerciseCatalog.exercise($0.exerciseID)?.primary }.flatMap { $0 })
        XCTAssertTrue(muscles.contains(.quads) || muscles.contains(.glutes))
        XCTAssertTrue(muscles.contains(.chest))
    }

    func testAvoidsFatiguedMuscles() {
        let date = Date().addingTimeInterval(-3600)
        let legs = WorkoutSession(title: "Bacak", startedAt: date, endedAt: date, exercises: [
            SessionExercise(exerciseID: "leg-press", targetReps: 10...12, restSeconds: 120,
                            sets: (0..<6).map { _ in SetLog(weightKg: 100, reps: 10, rir: 1, isCompleted: true, completedAt: date) }),
            SessionExercise(exerciseID: "lying-leg-curl", targetReps: 10...12, restSeconds: 60,
                            sets: (0..<5).map { _ in SetLog(weightKg: 30, reps: 12, rir: 1, isCompleted: true, completedAt: date) })
        ])
        var p = profile
        p.trainingDaysPerWeek = 4
        let rec = RecoveryEngine.states(sessions: [legs], experience: .beginner)
        let vol = VolumeEngine.weekly(sessions: [legs], experience: .beginner, focus: [])
        let w = ProgramGenerator.generate(profile: p, recovery: rec, volume: vol, sessions: [legs], lowReadiness: false)
        XCTAssertEqual(w.title, "Üst Vücut")
        XCTAssertFalse(w.slots.contains { $0.exerciseID == "leg-press" })
    }

    func testRespectsEquipment() {
        var p = profile
        p.equipment = Equipment.homeDumbbells
        let rec = RecoveryEngine.states(sessions: [], experience: .beginner)
        let vol = VolumeEngine.weekly(sessions: [], experience: .beginner, focus: [])
        let w = ProgramGenerator.generate(profile: p, recovery: rec, volume: vol, sessions: [], lowReadiness: false)
        XCTAssertFalse(w.slots.isEmpty)
        for slot in w.slots {
            XCTAssertTrue(ExerciseCatalog.exercise(slot.exerciseID)!.isAvailable(with: p.equipment), slot.exerciseID)
        }
    }

    func testFocusMuscleIncluded() {
        var p = profile
        p.focusMuscles = [.sideDelts]
        let rec = RecoveryEngine.states(sessions: [], experience: .beginner)
        let vol = VolumeEngine.weekly(sessions: [], experience: .beginner, focus: p.focusMuscles)
        let w = ProgramGenerator.generate(profile: p, recovery: rec, volume: vol, sessions: [], lowReadiness: false)
        XCTAssertTrue(w.slots.contains { ExerciseCatalog.exercise($0.exerciseID)!.primary.contains(.sideDelts) })
    }
}

final class MiscTests: XCTestCase {

    func testRamadanTimesIstanbul() {
        var s = RamadanSettings()
        s.latitude = 41.01
        s.longitude = 28.98
        var cal = Calendar.forma
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let date = cal.date(from: DateComponents(year: 2027, month: 2, day: 20, hour: 12))!
        let t = RamadanCalculator.times(on: date, settings: s, calendar: cal)!
        let iftar = cal.dateComponents([.hour, .minute], from: t.iftar)
        let imsak = cal.dateComponents([.hour], from: t.imsak)
        XCTAssertEqual(iftar.hour, 18)
        XCTAssertTrue((5...6).contains(imsak.hour!))
        XCTAssertGreaterThan(t.fastingHours, 11)
    }

    func testStreaks() {
        let cal = Calendar.forma
        let today = Date()
        let keys = Set((0..<5).map { DayKey.key(cal.date(byAdding: .day, value: -$0, to: today)!) })
        XCTAssertEqual(StreakEngine.dailyStreak(days: keys, now: today), 5)
        let fromYesterday = Set((1..<4).map { DayKey.key(cal.date(byAdding: .day, value: -$0, to: today)!) })
        XCTAssertEqual(StreakEngine.dailyStreak(days: fromYesterday, now: today), 3)
    }

    func testLevels() {
        XCTAssertEqual(AchievementEngine.level(for: 0).level, 1)
        XCTAssertEqual(AchievementEngine.level(for: 200).level, 2)
        let l = AchievementEngine.level(for: 350)
        XCTAssertEqual(l.level, 2)
        XCTAssertGreaterThan(l.progress, 0)
        XCTAssertLessThan(l.progress, 1)
    }

    func testReadiness() {
        let good = ReadinessEngine.evaluate(.init(sleepHours: 8.2, hrvToday: 70, hrvBaseline: (0..<20).map { 55 + Double($0 % 10) },
                                                  restingHRToday: 52, restingHRBaseline: (0..<20).map { 55 + Double($0 % 4) }))!
        XCTAssertEqual(good.level, .high)
        let bad = ReadinessEngine.evaluate(.init(sleepHours: 4.5, hrvToday: 35, hrvBaseline: (0..<20).map { 55 + Double($0 % 10) },
                                                 restingHRToday: 68, restingHRBaseline: (0..<20).map { 55 + Double($0 % 4) }))!
        XCTAssertEqual(bad.level, .low)
        XCTAssertNil(ReadinessEngine.evaluate(.init()))
    }

    func testOpenFoodFactsParse() throws {
        let json = """
        {"status":1,"product":{"product_name":"Protein Bar","brands":"Marka, Diğer","serving_quantity":45,
        "nutriments":{"energy-kcal_100g":380,"proteins_100g":30,"carbohydrates_100g":35,"fat_100g":12,"fiber_100g":8}}}
        """.data(using: .utf8)!
        let food = try OpenFoodFacts.parse(json, barcode: "8690000000000")
        XCTAssertEqual(food.name, "Protein Bar")
        XCTAssertEqual(food.brand, "Marka")
        XCTAssertEqual(food.per100g.protein, 30)
        XCTAssertEqual(food.defaultServing.grams, 45)
        XCTAssertThrowsError(try OpenFoodFacts.parse(#"{"status":0}"#.data(using: .utf8)!, barcode: "1"))
    }

    func testDataSurvivesRoundTripAndMissingFields() throws {
        var data = FormaData()
        data.profile = UserProfile(name: "Test")
        data.waterLogs = [WaterLog(ml: 250)]
        data.settings.planMode = .auto
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        let back = try dec.decode(FormaData.self, from: enc.encode(data))
        XCTAssertEqual(back.profile?.name, "Test")
        XCTAssertEqual(back.waterLogs.count, 1)
        XCTAssertTrue(back.settings.planMode.isAuto)
        // Eski sürüm dosyası: eksik alanlar varsayılan olmalı
        let old = try dec.decode(FormaData.self, from: #"{"waterLogs":[],"settings":{"hotWeather":true}}"#.data(using: .utf8)!)
        XCTAssertTrue(old.settings.hotWeather)
        XCTAssertEqual(old.settings.gym.barWeightKg, 20)
    }

    func testInboxAppliesOnce() {
        var data = FormaData()
        data.supplements = FormaData.defaultSupplements(weightKg: 75)
        let id = UUID()
        let events: [InboxEvent] = [.water(id: id, date: Date(), ml: 300, beverage: .water),
                                    .supplement(id: UUID(), date: Date(), supplementID: nil, kind: .creatine, amount: 0)]
        data.apply(events)
        data.apply(events)
        XCTAssertEqual(data.waterLogs.count, 1)
        XCTAssertEqual(data.supplementLogs.count, 1)
        XCTAssertEqual(data.supplementLogs.first?.amount, data.supplements.first?.dose)
    }

    func testStorageSaveLoad() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let storage = FormaStorage(directory: dir)
        var data = FormaData()
        data.profile = UserProfile(name: "Kayıt")
        try storage.saveNow(data)
        try storage.saveNow(data)
        XCTAssertEqual(storage.load().profile?.name, "Kayıt")
        // Bozuk ana dosya → yedekten açılır
        try Data("bozuk".utf8).write(to: storage.dataURL)
        XCTAssertEqual(storage.load().profile?.name, "Kayıt")
        storage.append(.water(id: UUID(), date: Date(), ml: 200, beverage: .tea))
        XCTAssertEqual(storage.pendingEvents().count, 1)
    }
}
