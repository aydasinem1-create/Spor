import Foundation

/// Telefondan saate giden özet.
public struct WatchPayload: Codable, Equatable, Sendable {
    public struct Supplement: Codable, Equatable, Sendable, Identifiable {
        public var id: UUID
        public var kind: SupplementKind
        public var name: String
        public var dose: String
        public var taken: Bool
        public init(id: UUID, kind: SupplementKind, name: String, dose: String, taken: Bool) {
            self.id = id
            self.kind = kind
            self.name = name
            self.dose = dose
            self.taken = taken
        }
    }

    public struct Live: Codable, Equatable, Sendable {
        public var sessionID: UUID
        public var title: String
        public var startedAt: Date
        public var exerciseName: String
        public var setIndex: Int
        public var setCount: Int
        public var weight: Double
        public var reps: Int
        public var isTimed: Bool
        public var restEndsAt: Date?
        public var completedSets: Int
        public var totalSets: Int
        public var nextExerciseName: String?

        public init(sessionID: UUID, title: String, startedAt: Date, exerciseName: String, setIndex: Int, setCount: Int,
                    weight: Double, reps: Int, isTimed: Bool, restEndsAt: Date?, completedSets: Int, totalSets: Int,
                    nextExerciseName: String?) {
            self.sessionID = sessionID
            self.title = title
            self.startedAt = startedAt
            self.exerciseName = exerciseName
            self.setIndex = setIndex
            self.setCount = setCount
            self.weight = weight
            self.reps = reps
            self.isTimed = isTimed
            self.restEndsAt = restEndsAt
            self.completedSets = completedSets
            self.totalSets = totalSets
            self.nextExerciseName = nextExerciseName
        }
    }

    public var day: String
    public var waterMl: Double
    public var waterTarget: Double
    public var protein: Double
    public var proteinTarget: Double
    public var kcal: Double
    public var kcalTarget: Double
    public var supplements: [Supplement]
    public var nextWorkout: String?
    public var live: Live?
    public var creatineStreak: Int

    public init(day: String, waterMl: Double, waterTarget: Double, protein: Double, proteinTarget: Double, kcal: Double,
                kcalTarget: Double, supplements: [Supplement], nextWorkout: String?, live: Live?, creatineStreak: Int) {
        self.day = day
        self.waterMl = waterMl
        self.waterTarget = waterTarget
        self.protein = protein
        self.proteinTarget = proteinTarget
        self.kcal = kcal
        self.kcalTarget = kcalTarget
        self.supplements = supplements
        self.nextWorkout = nextWorkout
        self.live = live
        self.creatineStreak = creatineStreak
    }

    public static let empty = WatchPayload(day: "", waterMl: 0, waterTarget: 2500, protein: 0, proteinTarget: 120, kcal: 0,
                                           kcalTarget: 2200, supplements: [], nextWorkout: nil, live: nil, creatineStreak: 0)
}
