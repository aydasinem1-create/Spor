import Foundation

/// Uygulamanın tüm kalıcı verisi. Tek bir JSON dosyası olarak App Group klasöründe tutulur;
/// böylece widget'lar ve Siri komutları da okuyabilir.
public struct FormaData: Codable, Sendable {
    public static let currentSchema = 1

    public var schemaVersion: Int = FormaData.currentSchema
    public var profile: UserProfile?
    public var settings: AppSettings = AppSettings()
    public var sessions: [WorkoutSession] = []
    public var activeWorkout: WorkoutSession?
    public var records: [PersonalRecord] = []
    public var foodLogs: [FoodLog] = []
    public var customFoods: [Food] = []
    public var favoriteFoodIDs: [String] = []
    public var recentFoodIDs: [String] = []
    public var supplements: [Supplement] = []
    public var supplementLogs: [SupplementLog] = []
    public var waterLogs: [WaterLog] = []
    public var measurements: [BodyMeasurement] = []
    public var photos: [ProgressPhoto] = []
    public var soreness: [RecoveryEngine.Soreness] = []
    public var externalActivities: [RecoveryEngine.ExternalActivity] = []
    public var unlockedAchievements: [String: Date] = [:]
    public var exerciseNotes: [String: String] = [:]
    public var customExercises: [Exercise] = []
    /// Günlük "nasıl hissediyorsun" (gün anahtarı → 1–5).
    public var feelings: [String: Int] = [:]
    /// Haftalık koç özetleri (hafta başlangıcı anahtarı → metin).
    public var weeklySummaries: [String: String] = [:]

    public init() {}

    enum CodingKeys: String, CodingKey {
        case schemaVersion, profile, settings, sessions, activeWorkout, records, foodLogs, customFoods, favoriteFoodIDs
        case recentFoodIDs, supplements, supplementLogs, waterLogs, measurements, photos, soreness, externalActivities
        case unlockedAchievements, exerciseNotes, customExercises, feelings, weeklySummaries
    }

    /// Her alan bağımsız çözülür: biri bozulsa bile diğer veriler kaybolmaz.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.value(.schemaVersion, FormaData.currentSchema)
        profile = c.value(.profile, nil)
        settings = c.value(.settings, AppSettings())
        sessions = c.value(.sessions, [])
        activeWorkout = c.value(.activeWorkout, nil)
        records = c.value(.records, [])
        foodLogs = c.value(.foodLogs, [])
        customFoods = c.value(.customFoods, [])
        favoriteFoodIDs = c.value(.favoriteFoodIDs, [])
        recentFoodIDs = c.value(.recentFoodIDs, [])
        supplements = c.value(.supplements, [])
        supplementLogs = c.value(.supplementLogs, [])
        waterLogs = c.value(.waterLogs, [])
        measurements = c.value(.measurements, [])
        photos = c.value(.photos, [])
        soreness = c.value(.soreness, [])
        externalActivities = c.value(.externalActivities, [])
        unlockedAchievements = c.value(.unlockedAchievements, [:])
        exerciseNotes = c.value(.exerciseNotes, [:])
        customExercises = c.value(.customExercises, [])
        feelings = c.value(.feelings, [:])
        weeklySummaries = c.value(.weeklySummaries, [:])
    }

    /// Yeni kullanıcı için varsayılan takviyeler: kreatin + whey.
    public static func defaultSupplements(weightKg: Double) -> [Supplement] {
        [
            Supplement(kind: .creatine, dose: SupplementEngine.creatineMaintenanceDose(weightKg: weightKg),
                       reminderTimes: [ReminderTime(9, 0)]),
            Supplement(kind: .whey, name: "Whey protein", dose: 1, unit: "ölçek",
                       reminderTimes: [], proteinPerDose: 24, onlyTrainingDays: true)
        ]
    }
}

// MARK: - Dış olay kutusu

/// Widget, Siri, bildirim ve saatten gelen küçük işlemler. Ana veriye uygulamada birleştirilir.
/// Böylece aynı dosyaya iki süreç aynı anda yazmaz.
public enum InboxEvent: Codable, Hashable, Sendable {
    case water(id: UUID, date: Date, ml: Double, beverage: Beverage)
    case supplement(id: UUID, date: Date, supplementID: UUID?, kind: SupplementKind, amount: Double)
    case food(id: UUID, date: Date, foodID: String, grams: Double, meal: MealType)
    case weight(id: UUID, date: Date, kg: Double)
    case setCompleted(id: UUID, date: Date, exerciseIndex: Int, setIndex: Int, weightKg: Double, reps: Int)
    case restAdjust(id: UUID, date: Date, seconds: Int)
    case skipRest(id: UUID, date: Date)
    case feeling(id: UUID, date: Date, value: Int)

    public var eventID: UUID {
        switch self {
        case .water(let id, _, _, _), .supplement(let id, _, _, _, _), .food(let id, _, _, _, _),
             .weight(let id, _, _), .setCompleted(let id, _, _, _, _, _), .restAdjust(let id, _, _),
             .skipRest(let id, _), .feeling(let id, _, _):
            return id
        }
    }

    public var date: Date {
        switch self {
        case .water(_, let d, _, _), .supplement(_, let d, _, _, _), .food(_, let d, _, _, _),
             .weight(_, let d, _), .setCompleted(_, let d, _, _, _, _), .restAdjust(_, let d, _),
             .skipRest(_, let d), .feeling(_, let d, _):
            return d
        }
    }
}

extension FormaData {
    /// Kutudaki olayları ana veriye uygular. Aynı olay iki kez uygulanmaz.
    public mutating func apply(_ events: [InboxEvent]) {
        let knownWater = Set(waterLogs.map(\.id))
        let knownSupp = Set(supplementLogs.map(\.id))
        let knownFood = Set(foodLogs.map(\.id))
        let knownMeasure = Set(measurements.map(\.id))
        for event in events.sorted(by: { $0.date < $1.date }) {
            switch event {
            case let .water(id, date, ml, beverage):
                if !knownWater.contains(id) { waterLogs.append(WaterLog(id: id, date: date, ml: ml, beverage: beverage)) }
            case let .supplement(id, date, supplementID, kind, amount):
                guard !knownSupp.contains(id) else { continue }
                let target = supplementID.flatMap { sid in supplements.first { $0.id == sid } }
                    ?? supplements.first { $0.kind == kind && $0.isActive }
                if let s = target {
                    supplementLogs.append(SupplementLog(id: id, supplementID: s.id, date: date, amount: amount > 0 ? amount : s.dose))
                }
            case let .food(id, date, foodID, grams, meal):
                guard !knownFood.contains(id) else { continue }
                if let food = FoodDatabase.food(foodID) ?? customFoods.first(where: { $0.id == foodID }) {
                    foodLogs.append(FoodLog(id: id, date: date, meal: meal, food: food, grams: grams))
                }
            case let .weight(id, date, kg):
                if !knownMeasure.contains(id) { measurements.append(BodyMeasurement(id: id, date: date, weightKg: kg)) }
            case let .setCompleted(_, date, exerciseIndex, setIndex, weightKg, reps):
                guard var w = activeWorkout, w.exercises.indices.contains(exerciseIndex),
                      w.exercises[exerciseIndex].sets.indices.contains(setIndex) else { continue }
                w.exercises[exerciseIndex].sets[setIndex].weightKg = weightKg
                w.exercises[exerciseIndex].sets[setIndex].reps = reps
                w.exercises[exerciseIndex].sets[setIndex].isCompleted = true
                w.exercises[exerciseIndex].sets[setIndex].completedAt = date
                activeWorkout = w
            case .restAdjust, .skipRest:
                // Dinlenme sayacı uygulama içindeki canlı durumda tutulur.
                continue
            case let .feeling(_, date, value):
                feelings[DayKey.key(date)] = value
            }
        }
    }
}
