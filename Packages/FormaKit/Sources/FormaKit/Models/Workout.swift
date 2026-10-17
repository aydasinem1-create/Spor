import Foundation

// MARK: - Program

public struct ExerciseSlot: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var exerciseID: String
    public var sets: Int
    public var repLow: Int
    public var repHigh: Int
    public var restSeconds: Int?
    /// Ekipman yoksa sırayla denenecek alternatifler.
    public var alternatives: [String]

    public init(id: UUID = UUID(), _ exerciseID: String, sets: Int, reps: ClosedRange<Int>, rest: Int? = nil, alternatives: [String] = []) {
        self.id = id
        self.exerciseID = exerciseID
        self.sets = sets
        self.repLow = reps.lowerBound
        self.repHigh = reps.upperBound
        self.restSeconds = rest
        self.alternatives = alternatives
    }

    public var repRange: ClosedRange<Int> { repLow...max(repLow, repHigh) }

    /// Kullanıcının ekipmanına uyan ilk hareket.
    public func resolvedExercise(equipment: Set<Equipment>) -> Exercise? {
        for id in [exerciseID] + alternatives {
            if let ex = ExerciseCatalog.exercise(id), ex.isAvailable(with: equipment) { return ex }
        }
        return nil
    }
}

public struct ProgramDay: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var focus: String
    public var slots: [ExerciseSlot]

    public init(id: String, name: String, focus: String, slots: [ExerciseSlot]) {
        self.id = id
        self.name = name
        self.focus = focus
        self.slots = slots
    }
}

public struct WorkoutProgram: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var summary: String
    public var level: Difficulty
    public var daysPerWeek: Int
    public var weeks: Int
    public var requiredEquipment: Set<Equipment>
    public var days: [ProgramDay]
    public var notes: [String]

    public init(id: String, name: String, summary: String, level: Difficulty, daysPerWeek: Int, weeks: Int,
                requiredEquipment: Set<Equipment>, days: [ProgramDay], notes: [String] = []) {
        self.id = id
        self.name = name
        self.summary = summary
        self.level = level
        self.daysPerWeek = daysPerWeek
        self.weeks = weeks
        self.requiredEquipment = requiredEquipment
        self.days = days
        self.notes = notes
    }
}

// MARK: - Kayıtlar

public struct SetLog: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: SetKind
    public var weightKg: Double
    public var reps: Int
    /// Süre ölçülen hareketler için saniye.
    public var seconds: Int
    /// Yedekte kalan tekrar (Reps in Reserve). nil = girilmedi.
    public var rir: Int?
    public var isCompleted: Bool
    public var completedAt: Date?

    public init(id: UUID = UUID(), kind: SetKind = .working, weightKg: Double = 0, reps: Int = 0, seconds: Int = 0,
                rir: Int? = nil, isCompleted: Bool = false, completedAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.weightKg = weightKg
        self.reps = reps
        self.seconds = seconds
        self.rir = rir
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    public var volume: Double { weightKg * Double(reps) }
}

public struct SessionExercise: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var exerciseID: String
    public var targetRepLow: Int
    public var targetRepHigh: Int
    public var restSeconds: Int
    public var sets: [SetLog]
    public var note: String

    public init(id: UUID = UUID(), exerciseID: String, targetReps: ClosedRange<Int>, restSeconds: Int, sets: [SetLog], note: String = "") {
        self.id = id
        self.exerciseID = exerciseID
        self.targetRepLow = targetReps.lowerBound
        self.targetRepHigh = targetReps.upperBound
        self.restSeconds = restSeconds
        self.sets = sets
        self.note = note
    }

    public var targetReps: ClosedRange<Int> { targetRepLow...max(targetRepLow, targetRepHigh) }
    public var completedWorkingSets: [SetLog] { sets.filter { $0.isCompleted && $0.kind.countsTowardVolume } }
    public var exercise: Exercise? { ExerciseCatalog.exercise(exerciseID) }
}

public struct WorkoutSession: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var programID: String?
    public var programDayID: String?
    public var startedAt: Date
    public var endedAt: Date?
    public var exercises: [SessionExercise]
    public var note: String
    /// Seans zorluğu 1–10 (isteğe bağlı).
    public var sessionRPE: Int?
    public var averageHeartRate: Double?
    public var activeEnergyKcal: Double?
    /// Saat kaydettiyse telefonda tekrar Sağlık'a yazma.
    public var savedToHealthByWatch: Bool

    public init(id: UUID = UUID(), title: String, programID: String? = nil, programDayID: String? = nil,
                startedAt: Date = Date(), endedAt: Date? = nil, exercises: [SessionExercise], note: String = "",
                sessionRPE: Int? = nil, averageHeartRate: Double? = nil, activeEnergyKcal: Double? = nil,
                savedToHealthByWatch: Bool = false) {
        self.id = id
        self.title = title
        self.programID = programID
        self.programDayID = programDayID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercises = exercises
        self.note = note
        self.sessionRPE = sessionRPE
        self.averageHeartRate = averageHeartRate
        self.activeEnergyKcal = activeEnergyKcal
        self.savedToHealthByWatch = savedToHealthByWatch
    }

    public var duration: TimeInterval { (endedAt ?? Date()).timeIntervalSince(startedAt) }
    public var totalVolume: Double { exercises.flatMap(\.completedWorkingSets).reduce(0) { $0 + $1.volume } }
    public var completedSetCount: Int { exercises.reduce(0) { $0 + $1.completedWorkingSets.count } }
    public var isFinished: Bool { endedAt != nil }

    /// Bu seansta hangi kasa kaç kesirli set yapıldı.
    public func fractionalSets() -> [MuscleGroup: Double] {
        var result: [MuscleGroup: Double] = [:]
        for se in exercises {
            guard let ex = se.exercise else { continue }
            let n = Double(se.completedWorkingSets.count)
            guard n > 0 else { continue }
            for m in ex.primary { result[m, default: 0] += n }
            for m in ex.secondary { result[m, default: 0] += n * 0.5 }
        }
        return result
    }
}

/// Kişisel rekor türleri.
public enum PRKind: String, Codable, Sendable {
    case heaviestWeight, bestEstimated1RM, mostReps, bestSessionVolume
    public var displayName: String {
        switch self {
        case .heaviestWeight: return "En ağır"
        case .bestEstimated1RM: return "Tahmini 1RM"
        case .mostReps: return "En çok tekrar"
        case .bestSessionVolume: return "En yüksek hacim"
        }
    }
}

public struct PersonalRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var exerciseID: String
    public var kind: PRKind
    public var value: Double
    public var weightKg: Double
    public var reps: Int
    public var date: Date

    public init(exerciseID: String, kind: PRKind, value: Double, weightKg: Double, reps: Int, date: Date) {
        self.exerciseID = exerciseID
        self.kind = kind
        self.value = value
        self.weightKg = weightKg
        self.reps = reps
        self.date = date
    }
}
