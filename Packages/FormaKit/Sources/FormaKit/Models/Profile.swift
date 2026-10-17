import Foundation

public struct UserProfile: Codable, Equatable, Sendable {
    public var name: String
    public var sex: Sex
    public var birthYear: Int
    public var heightCm: Double
    public var weightKg: Double
    public var goal: Goal
    public var experience: Experience
    public var activityLevel: ActivityLevel
    public var trainingDaysPerWeek: Int
    public var sessionMinutes: Int
    public var equipment: Set<Equipment>
    /// Daha fazla hacim verilecek "odak" bölgeleri (bölgesel kas gelişimi). Bölgesel yağ yakma DEĞİL.
    public var focusMuscles: Set<MuscleGroup>
    public var createdAt: Date

    public init(
        name: String = "",
        sex: Sex = .male,
        birthYear: Int = 2000,
        heightCm: Double = 175,
        weightKg: Double = 75,
        goal: Goal = .buildMuscle,
        experience: Experience = .beginner,
        activityLevel: ActivityLevel = .light,
        trainingDaysPerWeek: Int = 3,
        sessionMinutes: Int = 60,
        equipment: Set<Equipment> = Equipment.fullGym,
        focusMuscles: Set<MuscleGroup> = [],
        createdAt: Date = Date()
    ) {
        self.name = name
        self.sex = sex
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goal = goal
        self.experience = experience
        self.activityLevel = activityLevel
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.sessionMinutes = sessionMinutes
        self.equipment = equipment
        self.focusMuscles = focusMuscles
        self.createdAt = createdAt
    }

    public func age(on date: Date = Date(), calendar: Calendar = .current) -> Int {
        max(14, calendar.component(.year, from: date) - birthYear)
    }
}

/// Günlük hedefler. `isManual` false ise profil ve verilere göre otomatik hesaplanır.
public struct DailyTargets: Codable, Hashable, Sendable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    public var fiberG: Double
    public var waterMl: Double
    public var creatineG: Double

    public init(kcal: Double, proteinG: Double, carbsG: Double, fatG: Double, fiberG: Double, waterMl: Double, creatineG: Double) {
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.waterMl = waterMl
        self.creatineG = creatineG
    }

    public static let placeholder = DailyTargets(kcal: 2200, proteinG: 130, carbsG: 250, fatG: 70, fiberG: 30, waterMl: 2500, creatineG: 5)
}

public enum PlanMode: Codable, Equatable, Sendable {
    /// Hazır programı sırayla takip et
    case program(id: String)
    /// Toparlanma ve haftalık hacme göre her gün otomatik antrenman üret
    case auto

    public var isAuto: Bool { if case .auto = self { return true } else { return false } }
    public var programID: String? { if case .program(let id) = self { return id } else { return nil } }
}

public struct ReminderSettings: Codable, Equatable, Sendable {
    public var waterEnabled: Bool = true
    public var waterStartHour: Int = 9
    public var waterEndHour: Int = 21
    public var waterIntervalMinutes: Int = 120
    public var supplementsEnabled: Bool = true
    public var postWorkoutProteinEnabled: Bool = true
    public var workoutDayEnabled: Bool = true
    public var workoutReminderHour: Int = 17
    public var workoutReminderMinute: Int = 30
    public var eveningSummaryEnabled: Bool = true
    public var eveningSummaryHour: Int = 21
    public init() {}
}

public struct RamadanSettings: Codable, Equatable, Sendable {
    public var enabled: Bool = false
    /// Konum yoksa kullanılacak elle girilen saatler (dakika cinsinden gece yarısından itibaren).
    public var manualIftarMinutes: Int? = nil
    public var manualImsakMinutes: Int? = nil
    public var latitude: Double? = nil
    public var longitude: Double? = nil
    /// Diyanet takvimiyle uyum için ince ayar (dakika).
    public var iftarOffsetMinutes: Int = 0
    public var imsakOffsetMinutes: Int = 0
    public init() {}
}

public struct GymSettings: Codable, Equatable, Sendable {
    public var barWeightKg: Double = 20
    /// Salondaki plakalar (bir taraf için çift sayısı sınırsız kabul edilir).
    public var plates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    public var dumbbellStepKg: Double = 2
    public var machineStepKg: Double = 5
    public var showWarmups: Bool = true
    public var defaultRestSeconds: Int = 90
    public var restTimerSound: Bool = true
    public var restTimerHaptics: Bool = true
    public init() {}
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var targetsAreManual: Bool = false
    public var manualTargets: DailyTargets? = nil
    public var planMode: PlanMode = .program(id: ProgramLibrary.beginnerFullBody.id)
    /// Programdaki sıradaki gün indeksi.
    public var programDayIndex: Int = 0
    public var reminders = ReminderSettings()
    public var ramadan = RamadanSettings()
    public var gym = GymSettings()
    public var healthKitEnabled: Bool = false
    public var useAdaptiveExpenditure: Bool = true
    public var hotWeather: Bool = false
    public var caffeineSensitive: Bool = false
    public var sleepHourGoal: Double = 8
    public var bedtimeHour: Int = 23
    public var hasSeenAutoPlanSuggestion: Bool = false
    public init() {}
}


// Ayar yapıları zamanla yeni alanlar kazanacak. Eski kayıtlar açılırken eksik alanlar
// varsayılan değerleri alsın diye çözme işlemini elle yazıyoruz (veri kaybı olmasın).

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, _ fallback: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback()
    }
}

extension ReminderSettings {
    enum CodingKeys: String, CodingKey {
        case waterEnabled, waterStartHour, waterEndHour, waterIntervalMinutes, supplementsEnabled
        case postWorkoutProteinEnabled, workoutDayEnabled, workoutReminderHour, workoutReminderMinute
        case eveningSummaryEnabled, eveningSummaryHour
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        waterEnabled = c.value(.waterEnabled, waterEnabled)
        waterStartHour = c.value(.waterStartHour, waterStartHour)
        waterEndHour = c.value(.waterEndHour, waterEndHour)
        waterIntervalMinutes = c.value(.waterIntervalMinutes, waterIntervalMinutes)
        supplementsEnabled = c.value(.supplementsEnabled, supplementsEnabled)
        postWorkoutProteinEnabled = c.value(.postWorkoutProteinEnabled, postWorkoutProteinEnabled)
        workoutDayEnabled = c.value(.workoutDayEnabled, workoutDayEnabled)
        workoutReminderHour = c.value(.workoutReminderHour, workoutReminderHour)
        workoutReminderMinute = c.value(.workoutReminderMinute, workoutReminderMinute)
        eveningSummaryEnabled = c.value(.eveningSummaryEnabled, eveningSummaryEnabled)
        eveningSummaryHour = c.value(.eveningSummaryHour, eveningSummaryHour)
    }
}

extension RamadanSettings {
    enum CodingKeys: String, CodingKey {
        case enabled, manualIftarMinutes, manualImsakMinutes, latitude, longitude, iftarOffsetMinutes, imsakOffsetMinutes
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = c.value(.enabled, enabled)
        manualIftarMinutes = c.value(.manualIftarMinutes, manualIftarMinutes)
        manualImsakMinutes = c.value(.manualImsakMinutes, manualImsakMinutes)
        latitude = c.value(.latitude, latitude)
        longitude = c.value(.longitude, longitude)
        iftarOffsetMinutes = c.value(.iftarOffsetMinutes, iftarOffsetMinutes)
        imsakOffsetMinutes = c.value(.imsakOffsetMinutes, imsakOffsetMinutes)
    }
}

extension GymSettings {
    enum CodingKeys: String, CodingKey {
        case barWeightKg, plates, dumbbellStepKg, machineStepKg, showWarmups, defaultRestSeconds, restTimerSound, restTimerHaptics
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        barWeightKg = c.value(.barWeightKg, barWeightKg)
        plates = c.value(.plates, plates)
        dumbbellStepKg = c.value(.dumbbellStepKg, dumbbellStepKg)
        machineStepKg = c.value(.machineStepKg, machineStepKg)
        showWarmups = c.value(.showWarmups, showWarmups)
        defaultRestSeconds = c.value(.defaultRestSeconds, defaultRestSeconds)
        restTimerSound = c.value(.restTimerSound, restTimerSound)
        restTimerHaptics = c.value(.restTimerHaptics, restTimerHaptics)
    }
}

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case targetsAreManual, manualTargets, planMode, programDayIndex, reminders, ramadan, gym
        case healthKitEnabled, useAdaptiveExpenditure, hotWeather, caffeineSensitive, sleepHourGoal, bedtimeHour
        case hasSeenAutoPlanSuggestion
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        targetsAreManual = c.value(.targetsAreManual, targetsAreManual)
        manualTargets = c.value(.manualTargets, manualTargets)
        planMode = c.value(.planMode, planMode)
        programDayIndex = c.value(.programDayIndex, programDayIndex)
        reminders = c.value(.reminders, reminders)
        ramadan = c.value(.ramadan, ramadan)
        gym = c.value(.gym, gym)
        healthKitEnabled = c.value(.healthKitEnabled, healthKitEnabled)
        useAdaptiveExpenditure = c.value(.useAdaptiveExpenditure, useAdaptiveExpenditure)
        hotWeather = c.value(.hotWeather, hotWeather)
        caffeineSensitive = c.value(.caffeineSensitive, caffeineSensitive)
        sleepHourGoal = c.value(.sleepHourGoal, sleepHourGoal)
        bedtimeHour = c.value(.bedtimeHour, bedtimeHour)
        hasSeenAutoPlanSuggestion = c.value(.hasSeenAutoPlanSuggestion, hasSeenAutoPlanSuggestion)
    }
}
