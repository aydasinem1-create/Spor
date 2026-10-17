import Foundation

public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var englishName: String
    public var primary: [MuscleGroup]
    public var secondary: [MuscleGroup]
    /// Hareketi yapmak için gereken ekipmanların hepsi.
    public var equipment: [Equipment]
    public var mechanic: Mechanic
    public var pattern: MovementPattern
    public var difficulty: Difficulty
    public var tracking: TrackingType
    public var repLow: Int
    public var repHigh: Int
    public var restSeconds: Int
    /// Doğru form için kısa ipuçları.
    public var cues: [String]
    /// Sık yapılan hatalar.
    public var mistakes: [String]
    /// free-exercise-db içindeki olası kimlikler (görseller buradan gelir).
    public var datasetIDs: [String]
    /// Kimlik bulunamazsa veri setinde aranacak kelimeler (hepsi adda geçmeli).
    public var searchTerms: [String]
    public var isCustom: Bool

    public init(
        id: String, name: String, englishName: String,
        primary: [MuscleGroup], secondary: [MuscleGroup] = [],
        equipment: [Equipment], mechanic: Mechanic, pattern: MovementPattern,
        difficulty: Difficulty = .beginner, tracking: TrackingType = .weightReps,
        reps: ClosedRange<Int>, rest: Int,
        cues: [String], mistakes: [String] = [],
        datasetIDs: [String] = [], searchTerms: [String] = [],
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.englishName = englishName
        self.primary = primary
        self.secondary = secondary
        self.equipment = equipment
        self.mechanic = mechanic
        self.pattern = pattern
        self.difficulty = difficulty
        self.tracking = tracking
        self.repLow = reps.lowerBound
        self.repHigh = reps.upperBound
        self.restSeconds = rest
        self.cues = cues
        self.mistakes = mistakes
        self.datasetIDs = datasetIDs
        self.searchTerms = searchTerms
        self.isCustom = isCustom
    }

    public var repRange: ClosedRange<Int> { repLow...max(repLow, repHigh) }

    public var allMuscles: [MuscleGroup] { primary + secondary }

    public var isLowerBody: Bool {
        switch pattern {
        case .squat, .hinge, .lunge, .isolationLower: return true
        default: return primary.contains { $0.region == .lower }
        }
    }

    /// Bir setin bu kasa "kaç set" sayılacağı. Ana kas 1, yardımcı kas 0,5 (kesirli set sayımı).
    public func involvement(of muscle: MuscleGroup) -> Double {
        if primary.contains(muscle) { return 1.0 }
        if secondary.contains(muscle) { return 0.5 }
        return 0
    }

    public func isAvailable(with available: Set<Equipment>) -> Bool {
        equipment.allSatisfy { available.contains($0) }
    }

    /// Ağırlık artışı adımı (kg).
    public func loadIncrement(gym: GymSettings) -> Double {
        if equipment.contains(.dumbbell) { return gym.dumbbellStepKg }
        if equipment.contains(.machine) || equipment.contains(.cable) { return gym.machineStepKg }
        if equipment.contains(.barbell) || equipment.contains(.smith) || equipment.contains(.ezBar) {
            return (isLowerBody && mechanic == .compound) ? 5 : 2.5
        }
        if equipment.contains(.kettlebell) { return 4 }
        return 2.5
    }

    public var usesBarbell: Bool { equipment.contains(.barbell) }
}

public enum ExerciseImages {
    public static let baseURL = URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/")!
    public static let datasetURL = URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json")!

    /// Veri setindeki her hareketin iki karesi var: başlangıç (0) ve bitiş (1) pozisyonu.
    public static func frameURLs(datasetID: String) -> [URL] {
        (0...1).map { baseURL.appendingPathComponent(datasetID).appendingPathComponent("\($0).jpg") }
    }
}
