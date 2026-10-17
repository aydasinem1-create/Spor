import Foundation

/// Aşamalı yüklenme: "çift ilerleme" yöntemi.
/// Önce tekrar aralığının üstüne çıkılır, tüm setlerde üst sınıra ulaşınca ağırlık bir adım artırılır ve
/// tekrar alt sınıra döner. ACSM: hedef tekrar art arda seanslarda 1–2 fazla yapılabiliyorsa yükü %2–10 artır.
public enum ProgressionEngine {

    public enum Kind: String, Codable, Sendable { case firstTime, increase, repsUp, hold, deload }

    public struct Suggestion: Equatable, Sendable {
        public var kind: Kind
        public var weightKg: Double?
        public var reps: [Int]
        public var seconds: [Int]
        public var message: String
        public var lastSummary: String?
    }

    /// En son yapılan seanslardaki çalışma setleri (yeniden eskiye).
    public static func history(for exerciseID: String, in sessions: [WorkoutSession], limit: Int = 3) -> [[SetLog]] {
        sessions
            .filter { $0.isFinished }
            .sorted { $0.startedAt > $1.startedAt }
            .compactMap { s -> [SetLog]? in
                let sets = s.exercises.filter { $0.exerciseID == exerciseID }.flatMap(\.completedWorkingSets)
                return sets.isEmpty ? nil : sets
            }
            .prefix(limit)
            .map { $0 }
    }

    public static func summary(of sets: [SetLog], tracking: TrackingType) -> String {
        switch tracking {
        case .duration:
            return sets.map { "\($0.seconds) sn" }.joined(separator: " · ")
        case .reps:
            return sets.map { $0.weightKg > 0 ? "+\($0.weightKg.formattedKg)×\($0.reps)" : "\($0.reps)" }.joined(separator: " · ")
        case .weightReps:
            let weights = Set(sets.map(\.weightKg))
            if weights.count == 1, let w = weights.first {
                return "\(w.formattedKg) kg × " + sets.map { String($0.reps) }.joined(separator: ", ")
            }
            return sets.map { "\($0.weightKg.formattedKg)×\($0.reps)" }.joined(separator: " · ")
        }
    }

    public static func suggest(exercise: Exercise, setCount: Int, repRange: ClosedRange<Int>,
                               sessions: [WorkoutSession], gym: GymSettings, lowReadiness: Bool = false) -> Suggestion {
        let n = max(1, setCount)
        let past = history(for: exercise.id, in: sessions)
        guard let last = past.first else {
            switch exercise.tracking {
            case .duration:
                return Suggestion(kind: .firstTime, weightKg: nil, reps: Array(repeating: 0, count: n),
                                  seconds: Array(repeating: repRange.lowerBound, count: n),
                                  message: "İlk kez: \(repRange.lowerBound) saniyeyle başla, formu bozmadan tut.", lastSummary: nil)
            case .reps:
                return Suggestion(kind: .firstTime, weightKg: nil, reps: Array(repeating: repRange.lowerBound, count: n), seconds: [],
                                  message: "İlk kez: temiz formla yapabildiğin kadar; 2 tekrar yedekte bırak.", lastSummary: nil)
            case .weightReps:
                return Suggestion(kind: .firstTime, weightKg: nil, reps: Array(repeating: repRange.upperBound, count: n), seconds: [],
                                  message: "İlk kez: \(repRange.upperBound) tekrarı 2–3 tekrar yedekle bitirebileceğin bir ağırlık seç.",
                                  lastSummary: nil)
            }
        }

        let lastSummary = summary(of: last, tracking: exercise.tracking)

        switch exercise.tracking {
        case .duration:
            let lastSecs = last.map(\.seconds)
            let hitTop = lastSecs.allSatisfy { $0 >= repRange.upperBound }
            let base = lastSecs.max() ?? repRange.lowerBound
            let next = hitTop ? base : min(repRange.upperBound, base + 5)
            return Suggestion(kind: hitTop ? .hold : .repsUp, weightKg: nil, reps: Array(repeating: 0, count: n),
                              seconds: Array(repeating: next, count: n),
                              message: hitTop ? "Üst sınıra ulaştın; daha zor bir varyasyon deneyebilirsin." : "Geçen seferden 5 sn fazla dene.",
                              lastSummary: lastSummary)

        case .reps:
            let reps = last.map(\.reps)
            let addedWeight = last.map(\.weightKg).max() ?? 0
            if reps.allSatisfy({ $0 >= repRange.upperBound }) && !lowReadiness {
                return Suggestion(kind: .increase, weightKg: addedWeight + 2.5, reps: Array(repeating: repRange.lowerBound, count: n), seconds: [],
                                  message: "Tüm setlerde \(repRange.upperBound)+ tekrar: ek ağırlık (yelek/dambıl) ekle ya da daha zor bir varyasyona geç.",
                                  lastSummary: lastSummary)
            }
            let targets = (0..<n).map { i in min(repRange.upperBound, (i < reps.count ? reps[i] : reps.last ?? repRange.lowerBound) + (lowReadiness ? 0 : 1)) }
            return Suggestion(kind: lowReadiness ? .hold : .repsUp, weightKg: addedWeight > 0 ? addedWeight : nil, reps: targets, seconds: [],
                              message: lowReadiness ? "Bugün hafif gün: geçen seferki tekrarlar yeterli." : "Her sette 1 tekrar fazla dene.",
                              lastSummary: lastSummary)

        case .weightReps:
            let weights = last.map(\.weightKg)
            let topWeight = weights.max() ?? 0
            // Ağırlığı en yüksek olan setler esas alınır
            let topSets = last.filter { $0.weightKg >= topWeight - 0.01 }
            let step = exercise.loadIncrement(gym: gym)
            let allHitTop = topSets.count >= min(n, last.count) && topSets.allSatisfy { $0.reps >= repRange.upperBound }
            let anyBelow = topSets.contains { $0.reps < repRange.lowerBound }

            if allHitTop && !lowReadiness {
                let newWeight = topWeight + step
                return Suggestion(kind: .increase, weightKg: newWeight, reps: Array(repeating: repRange.lowerBound, count: n), seconds: [],
                                  message: "Geçen sefer tüm setlerde \(repRange.upperBound) tekrar yaptın: +\(step.formattedKg) kg zamanı!",
                                  lastSummary: lastSummary)
            }

            if anyBelow {
                // Üst üste iki seans alt sınırın altında kaldıysa %10 azalt
                let previousAlsoBelow: Bool = {
                    guard past.count > 1 else { return false }
                    let prev = past[1]
                    let prevTop = prev.map(\.weightKg).max() ?? 0
                    return abs(prevTop - topWeight) < 0.01 && prev.contains { $0.reps < repRange.lowerBound }
                }()
                if previousAlsoBelow {
                    let deload = max(step, (topWeight * 0.9).rounded(toStep: step))
                    return Suggestion(kind: .deload, weightKg: deload, reps: Array(repeating: repRange.upperBound, count: n), seconds: [],
                                      message: "İki seanstır hedefin altında kaldın. %10 hafifletip formu sağlamlaştıralım.",
                                      lastSummary: lastSummary)
                }
                return Suggestion(kind: .hold, weightKg: topWeight, reps: Array(repeating: repRange.lowerBound, count: n), seconds: [],
                                  message: "Aynı ağırlıkla en az \(repRange.lowerBound) tekrarı hedefle.", lastSummary: lastSummary)
            }

            let lastReps = topSets.map(\.reps)
            let targets = (0..<n).map { i -> Int in
                let previous = i < lastReps.count ? lastReps[i] : (lastReps.last ?? repRange.lowerBound)
                return min(repRange.upperBound, previous + (lowReadiness ? 0 : 1))
            }
            return Suggestion(kind: lowReadiness ? .hold : .repsUp, weightKg: topWeight, reps: targets, seconds: [],
                              message: lowReadiness ? "Bugün enerjin düşük görünüyor: geçen seferi tekrar etmek yeterli."
                                                    : "Aynı ağırlıkla setlere 1 tekrar ekle.",
                              lastSummary: lastSummary)
        }
    }

    /// Öneriden boş (tamamlanmamış) set satırları üretir; gerekirse ısınma setleri ekler.
    public static func makeSets(for exercise: Exercise, suggestion: Suggestion, gym: GymSettings, includeWarmups: Bool) -> [SetLog] {
        var sets: [SetLog] = []
        if includeWarmups, gym.showWarmups, let w = suggestion.weightKg {
            for wu in StrengthMath.warmups(workingWeight: w, exercise: exercise, gym: gym) {
                sets.append(SetLog(kind: .warmup, weightKg: wu.weight, reps: wu.reps))
            }
        }
        let count = max(suggestion.reps.count, suggestion.seconds.count)
        for i in 0..<count {
            sets.append(SetLog(kind: .working,
                               weightKg: suggestion.weightKg ?? 0,
                               reps: i < suggestion.reps.count ? suggestion.reps[i] : 0,
                               seconds: i < suggestion.seconds.count ? suggestion.seconds[i] : 0))
        }
        return sets
    }
}
