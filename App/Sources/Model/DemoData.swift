import Foundation
import FormaKit

/// Ekran görüntüleri ve testler için örnek veri ("-demo" açılış argümanı).
@MainActor
enum DemoData {
    static func load(into model: AppModel) {
        let cal = Calendar.forma
        let now = Date()
        var d = FormaData()
        let profile = UserProfile(name: "Deniz", sex: .male, birthYear: 2001, heightCm: 178, weightKg: 76, goal: .buildMuscle,
                                  experience: .beginner, activityLevel: .light, trainingDaysPerWeek: 3, sessionMinutes: 60,
                                  equipment: Equipment.fullGym, focusMuscles: [.sideDelts],
                                  createdAt: cal.date(byAdding: .day, value: -24, to: now) ?? now)
        d.profile = profile
        d.settings.planMode = .program(id: ProgramLibrary.beginnerFullBody.id)
        d.supplements = FormaData.defaultSupplements(weightKg: 76)
        d.supplements[0].reminderTimes = [ReminderTime(9, 0)]

        // Antrenmanlar: son 3 hafta, Pzt-Çar-Cum benzeri
        let program = ProgramLibrary.beginnerFullBody
        let offsets = [-22, -20, -18, -15, -13, -11, -8, -6, -4, -1]
        var dayIndex = 0
        for (n, off) in offsets.enumerated() {
            guard let start = cal.date(byAdding: .day, value: off, to: cal.startOfDay(for: now))?.addingTimeInterval(18.5 * 3600) else { continue }
            let day = program.days[dayIndex % program.days.count]
            dayIndex += 1
            var exercises: [SessionExercise] = []
            var t = start
            for slot in day.slots {
                guard let ex = slot.resolvedExercise(equipment: profile.equipment) else { continue }
                let base = baseWeight(ex.id)
                let progress = Double(n / 2) * ex.loadIncrement(gym: GymSettings()) * 0.5
                let w = (base + progress).rounded(toStep: ex.loadIncrement(gym: GymSettings()))
                var sets: [SetLog] = []
                for s in 0..<slot.sets {
                    t = t.addingTimeInterval(Double(ex.restSeconds + 45))
                    let reps = ex.tracking == .duration ? 0 : max(slot.repLow, slot.repHigh - s - (n % 2))
                    sets.append(SetLog(kind: .working, weightKg: ex.tracking == .weightReps ? w : 0, reps: reps,
                                       seconds: ex.tracking == .duration ? 40 : 0, rir: 2, isCompleted: true, completedAt: t))
                }
                exercises.append(SessionExercise(exerciseID: ex.id, targetReps: slot.repRange, restSeconds: ex.restSeconds, sets: sets))
            }
            d.sessions.append(WorkoutSession(title: day.name, programID: program.id, programDayID: day.id, startedAt: start,
                                             endedAt: t.addingTimeInterval(120), exercises: exercises, sessionRPE: 7))
        }
        d.settings.programDayIndex = dayIndex % program.days.count

        // Kilo: hafif artış + gürültü
        for i in stride(from: 24, through: 0, by: -2) {
            guard let date = cal.date(byAdding: .day, value: -i, to: now) else { continue }
            let noise = [0.3, -0.2, 0.1, -0.4, 0.2, 0.0, -0.1][i % 7]
            d.measurements.append(BodyMeasurement(date: date, weightKg: 75.2 + Double(24 - i) * 0.035 + noise))
        }
        d.measurements.append(BodyMeasurement(date: cal.date(byAdding: .day, value: -20, to: now) ?? now, waistCm: 84, chestCm: 98, armCm: 33.5))
        d.measurements.append(BodyMeasurement(date: cal.date(byAdding: .day, value: -2, to: now) ?? now, waistCm: 83.5, chestCm: 99, armCm: 34))

        // Beslenme, su, kreatin
        let breakfast: [(String, Double)] = [("menemen", 250), ("feta", 40), ("bread-wholewheat", 60)]
        let lunch: [(String, Double)] = [("chicken-doner-wrap", 300), ("ayran-food", 200)]
        let dinner: [(String, Double)] = [("tavuk-sote", 250), ("bulgur-pilaf", 180), ("cobansalata", 200)]
        let snack: [(String, Double)] = [("greek-yogurt", 150), ("banana", 120), ("almond", 28)]
        for i in (0...20).reversed() {
            guard let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: now)) else { continue }
            let meals: [(MealType, [(String, Double)], Double)] = [(.breakfast, breakfast, 8.5), (.lunch, lunch, 13), (.snack, snack, 16.5), (.dinner, dinner, 20)]
            for (meal, items, hour) in meals {
                let date = day.addingTimeInterval(hour * 3600)
                if i == 0 && date > now { continue }
                for (id, g) in items {
                    if let f = FoodDatabase.food(id) { d.foodLogs.append(FoodLog(date: date, meal: meal, food: f, grams: g)) }
                }
            }
            let cups = i == 0 ? min(7, max(2, cal.component(.hour, from: now) / 2 - 2)) : 8 + (i % 3)
            for c in 0..<cups {
                d.waterLogs.append(WaterLog(date: day.addingTimeInterval(Double(8 + c * 2) * 3600 + 600), ml: c % 3 == 0 ? 500 : 330))
            }
            d.waterLogs.append(WaterLog(date: day.addingTimeInterval(9 * 3600), ml: 100, beverage: .tea))
            if i != 9 || i == 0 {
                d.supplementLogs.append(SupplementLog(supplementID: d.supplements[0].id, date: day.addingTimeInterval(9 * 3600 + 300), amount: d.supplements[0].dose))
            }
        }
        d.feelings[DayKey.key(now)] = 4
        d.records = []
        for (i, s) in d.sessions.enumerated() where i > 0 {
            d.records += StrengthMath.newRecords(in: s, history: Array(d.sessions.prefix(i + 1)))
        }
        model.update { $0 = d }
    }

    private static func baseWeight(_ id: String) -> Double {
        switch id {
        case "leg-press": return 80
        case "goblet-squat": return 16
        case "machine-chest-press": return 35
        case "lat-pulldown": return 40
        case "machine-shoulder-press": return 25
        case "lying-leg-curl": return 25
        case "seated-cable-row": return 40
        case "incline-dumbbell-press": return 14
        case "dumbbell-rdl": return 16
        case "lateral-raise": return 6
        case "triceps-pushdown": return 20
        case "dumbbell-curl": return 9
        default: return 20
        }
    }
}
