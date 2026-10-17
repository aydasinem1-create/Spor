import Foundation

public enum StrengthMath {

    /// Tahmini 1 tekrar maksimum. Epley ve Brzycki formüllerinin ortalaması; 1–12 tekrarda makul.
    public static func estimated1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        let r = Double(min(reps, 12))
        let epley = weight * (1 + r / 30)
        let brzycki = weight * 36 / (37 - r)
        return (epley + brzycki) / 2
    }

    /// Hedef tekrar için 1RM'den ağırlık tahmini (Epley tersine).
    public static func weightFor(reps: Int, oneRM: Double) -> Double {
        guard reps > 0 else { return oneRM }
        return oneRM / (1 + Double(reps) / 30)
    }

    // MARK: Plaka hesaplayıcı

    public struct PlateResult: Equatable, Sendable {
        /// Bir tarafa takılacak plakalar (büyükten küçüğe).
        public var perSide: [Double]
        public var achievable: Double
        public var remainder: Double
    }

    public static func plates(target: Double, bar: Double, available: [Double]) -> PlateResult {
        guard target > bar else { return PlateResult(perSide: [], achievable: bar, remainder: max(0, target - bar)) }
        var perSideRemaining = (target - bar) / 2
        var result: [Double] = []
        for plate in available.sorted(by: >) where plate > 0 {
            while perSideRemaining + 0.0001 >= plate {
                result.append(plate)
                perSideRemaining -= plate
            }
        }
        let achieved = bar + result.reduce(0, +) * 2
        return PlateResult(perSide: result, achievable: achieved, remainder: max(0, target - achieved))
    }

    // MARK: Isınma setleri

    public struct WarmupSet: Equatable, Sendable {
        public var weight: Double
        public var reps: Int
    }

    /// İlk bileşik hareket için ısınma: boş bar, sonra çalışma ağırlığının %50, %70, %85'i.
    public static func warmups(workingWeight: Double, exercise: Exercise, gym: GymSettings) -> [WarmupSet] {
        guard exercise.mechanic == .compound, exercise.tracking == .weightReps else { return [] }
        let step = exercise.loadIncrement(gym: gym)
        if exercise.usesBarbell {
            let bar = gym.barWeightKg
            guard workingWeight >= bar + 10 else { return [] }
            var sets: [WarmupSet] = [WarmupSet(weight: bar, reps: 10)]
            for (pct, reps) in [(0.5, 8), (0.7, 5), (0.85, 3)] {
                let w = max(bar, (workingWeight * pct).rounded(toStep: 2.5))
                if w > (sets.last?.weight ?? 0) && w < workingWeight { sets.append(WarmupSet(weight: w, reps: reps)) }
            }
            return sets
        }
        guard workingWeight >= step * 4 else { return [] }
        var sets: [WarmupSet] = []
        for (pct, reps) in [(0.5, 10), (0.75, 5)] {
            let w = (workingWeight * pct).rounded(toStep: step)
            if w > 0 && w < workingWeight && w > (sets.last?.weight ?? 0) { sets.append(WarmupSet(weight: w, reps: reps)) }
        }
        return sets
    }

    // MARK: Rekorlar

    /// Bir seanstaki yeni rekorları, geçmiş seanslarla kıyaslayarak bulur.
    public static func newRecords(in session: WorkoutSession, history: [WorkoutSession]) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        let previous = history.filter { $0.id != session.id && $0.startedAt < session.startedAt }
        for se in session.exercises {
            let sets = se.completedWorkingSets.filter { $0.reps > 0 }
            guard !sets.isEmpty, let ex = se.exercise else { continue }
            let past = previous.flatMap { $0.exercises.filter { $0.exerciseID == se.exerciseID }.flatMap(\.completedWorkingSets) }
            let date = session.endedAt ?? session.startedAt

            if ex.tracking == .weightReps {
                let bestPastWeight = past.map(\.weightKg).max() ?? 0
                let bestPast1RM = past.map { estimated1RM(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0
                if let heaviest = sets.max(by: { $0.weightKg < $1.weightKg }), heaviest.weightKg > bestPastWeight, !past.isEmpty {
                    records.append(PersonalRecord(exerciseID: se.exerciseID, kind: .heaviestWeight, value: heaviest.weightKg,
                                                  weightKg: heaviest.weightKg, reps: heaviest.reps, date: date))
                }
                if let best = sets.max(by: { estimated1RM(weight: $0.weightKg, reps: $0.reps) < estimated1RM(weight: $1.weightKg, reps: $1.reps) }) {
                    let e = estimated1RM(weight: best.weightKg, reps: best.reps)
                    if e > bestPast1RM * 1.005, !past.isEmpty {
                        records.append(PersonalRecord(exerciseID: se.exerciseID, kind: .bestEstimated1RM, value: e.rounded(toStep: 0.5),
                                                      weightKg: best.weightKg, reps: best.reps, date: date))
                    }
                }
            } else if ex.tracking == .reps {
                let bestPastReps = past.map(\.reps).max() ?? 0
                if let most = sets.max(by: { $0.reps < $1.reps }), most.reps > bestPastReps, !past.isEmpty {
                    records.append(PersonalRecord(exerciseID: se.exerciseID, kind: .mostReps, value: Double(most.reps),
                                                  weightKg: most.weightKg, reps: most.reps, date: date))
                }
            }
        }
        return records
    }
}
