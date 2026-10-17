import Foundation

/// Toparlanmaya ve haftalık hacme göre "bugünün antrenmanını" otomatik kurar.
///
/// Mantık:
/// 1. Toparlanmış (≥ %80) ve bu hafta hedef set sayısının altında kalan kaslar seçilir.
/// 2. Odak bölgeleri önceliklidir.
/// 3. Haftada 3 gün veya daha az çalışılıyorsa tam vücut, daha fazlaysa üst/alt ayrımı tercih edilir.
/// 4. Her kas için son haftalarda en çok yapılan uygun hareket seçilir (ilerleme takibi kopmasın),
///    süre bütçesi dolana kadar hareket eklenir.
public enum ProgramGenerator {

    public struct GeneratedWorkout: Equatable, Sendable {
        public var title: String
        public var focus: String
        public var slots: [ExerciseSlot]
        public var rationale: [String]
        public var estimatedMinutes: Int
    }

    /// Kas başına varsayılan hareket tercih sırası (kolaydan zora).
    static let preferences: [MuscleGroup: [String]] = [
        .chest: ["machine-chest-press", "dumbbell-bench-press", "incline-dumbbell-press", "barbell-bench-press", "push-up", "pec-deck", "cable-crossover"],
        .lats: ["lat-pulldown", "assisted-pull-up", "pull-up", "close-grip-pulldown", "one-arm-dumbbell-row", "straight-arm-pulldown"],
        .upperBack: ["seated-cable-row", "machine-row", "one-arm-dumbbell-row", "barbell-row"],
        .quads: ["leg-press", "goblet-squat", "hack-squat", "barbell-squat", "bulgarian-split-squat", "leg-extension", "walking-lunge"],
        .hamstrings: ["lying-leg-curl", "seated-leg-curl", "dumbbell-rdl", "romanian-deadlift"],
        .glutes: ["hip-thrust", "glute-bridge", "dumbbell-rdl", "hip-abduction", "walking-lunge"],
        .sideDelts: ["lateral-raise", "cable-lateral-raise", "machine-shoulder-press", "dumbbell-shoulder-press"],
        .frontDelts: ["machine-shoulder-press", "dumbbell-shoulder-press", "arnold-press"],
        .rearDelts: ["face-pull", "reverse-pec-deck", "rear-delt-raise"],
        .biceps: ["dumbbell-curl", "cable-curl", "hammer-curl", "barbell-curl", "incline-dumbbell-curl"],
        .triceps: ["triceps-pushdown", "rope-pushdown", "overhead-triceps-extension", "bench-dip", "skull-crusher"],
        .calves: ["standing-calf-raise", "leg-press-calf", "seated-calf-raise"],
        .abs: ["cable-crunch", "ab-crunch-machine", "plank", "dead-bug", "crunch", "hanging-leg-raise"],
        .obliques: ["side-plank", "russian-twist"],
        .lowerBack: ["back-extension"],
        .traps: ["dumbbell-shrug", "barbell-shrug"],
        .adductors: ["hip-adduction"],
        .forearms: ["hammer-curl", "farmer-walk"]
    ]

    static let priorityOrder: [MuscleGroup] = [.quads, .chest, .lats, .upperBack, .hamstrings, .glutes, .sideDelts,
                                                .rearDelts, .triceps, .biceps, .calves, .abs, .frontDelts, .obliques, .lowerBack, .traps, .adductors, .forearms]

    static func secondsPerSet(_ exercise: Exercise, rest: Int) -> Double {
        let work: Double = exercise.tracking == .duration ? Double(exercise.repHigh) : 45
        return work + Double(rest)
    }

    public static func generate(profile: UserProfile,
                                recovery: [RecoveryEngine.MuscleState],
                                volume: [VolumeEngine.MuscleVolume],
                                sessions: [WorkoutSession],
                                lowReadiness: Bool,
                                now: Date = Date()) -> GeneratedWorkout {
        let rec = Dictionary(uniqueKeysWithValues: recovery.map { ($0.muscle, $0) })
        let vol = Dictionary(uniqueKeysWithValues: volume.map { ($0.muscle, $0) })
        var rationale: [String] = []

        func need(_ m: MuscleGroup) -> Double { vol[m]?.remaining ?? 0 }
        func ready(_ m: MuscleGroup) -> Bool { (rec[m]?.percent ?? 100) >= RecoveryEngine.readyThreshold }

        // 1) Gün tipi
        let upperBig: [MuscleGroup] = [.chest, .lats, .upperBack]
        let lowerBig: [MuscleGroup] = [.quads, .hamstrings, .glutes]
        let upperScore = upperBig.filter(ready).reduce(0) { $0 + need($1) + 1 }
        let lowerScore = lowerBig.filter(ready).reduce(0) { $0 + need($1) + 1 }
        let upperReady = upperBig.filter(ready).count >= 2
        let lowerReady = lowerBig.filter(ready).count >= 2

        enum DayType { case full, upper, lower, recovery }
        let dayType: DayType
        if !upperReady && !lowerReady {
            dayType = .recovery
        } else if profile.trainingDaysPerWeek <= 3 && upperReady && lowerReady {
            dayType = .full
        } else if upperReady && (!lowerReady || upperScore >= lowerScore) {
            dayType = .upper
        } else {
            dayType = .lower
        }

        var candidates: [MuscleGroup]
        let title: String
        switch dayType {
        case .full:
            title = "Tam Vücut"
            candidates = priorityOrder
        case .upper:
            title = "Üst Vücut"
            candidates = priorityOrder.filter { $0.region == .upper || $0 == .abs }
        case .lower:
            title = "Alt Vücut"
            candidates = priorityOrder.filter { $0.region == .lower || $0.region == .core }
        case .recovery:
            title = "Toparlanma Günü"
            candidates = [.abs, .obliques, .calves, .rearDelts].filter(ready)
            rationale.append("Büyük kas gruplarının çoğu henüz toparlanmadı. Hafif gövde çalışması veya yürüyüş iyi bir seçim.")
        }

        // Odak kaslarını öne al, sonra ihtiyaca göre sırala (öncelik sırası eşitliği bozar)
        candidates = candidates.filter(ready)
        func sortKey(_ m: MuscleGroup) -> (Int, Int, Int) {
            let focus = profile.focusMuscles.contains(m) ? 0 : 1
            let needBucket = -Int(need(m) / 3)          // ihtiyaç büyükse önce
            let priority = priorityOrder.firstIndex(of: m) ?? 99
            return (focus, needBucket, priority)
        }
        candidates.sort { sortKey($0) < sortKey($1) }

        // 2) Hareket seçimi
        let recentCutoff = now.addingTimeInterval(-35 * 86_400)
        var usage: [String: Int] = [:]
        for s in sessions where s.startedAt >= recentCutoff {
            for e in s.exercises where !e.completedWorkingSets.isEmpty { usage[e.exerciseID, default: 0] += 1 }
        }

        func allowed(_ ex: Exercise) -> Bool {
            guard ex.isAvailable(with: profile.equipment) else { return false }
            if profile.experience == .beginner && ex.difficulty != .beginner && usage[ex.id] == nil { return false }
            return true
        }

        func pick(for muscle: MuscleGroup, excluding used: Set<String>) -> Exercise? {
            let pool = (preferences[muscle] ?? []).compactMap(ExerciseCatalog.exercise).filter { allowed($0) && !used.contains($0.id) }
            guard var best = pool.first else { return nil }
            // En çok kullanılan hareket seçilir (ilerleme takibi kopmasın); eşitlikte tercih sırası korunur.
            var bestUsage = usage[best.id] ?? 0
            for ex in pool.dropFirst() {
                let u = usage[ex.id] ?? 0
                if u > bestUsage {
                    best = ex
                    bestUsage = u
                }
            }
            return best
        }

        let budgetSeconds = Double(profile.sessionMinutes) * 60 - 6 * 60   // ısınma payı
        var spent: Double = 0
        var slots: [ExerciseSlot] = []
        var used: Set<String> = []
        var coveredThisSession: [MuscleGroup: Double] = [:]
        let perSessionCap: Double = profile.experience == .beginner ? 6 : 8

        for muscle in candidates {
            if (coveredThisSession[muscle] ?? 0) >= min(perSessionCap, max(2, need(muscle))) { continue }
            guard let ex = pick(for: muscle, excluding: used) else { continue }
            let isMainMuscle = muscle.isLarge
            var sets = ex.mechanic == .compound ? 3 : (isMainMuscle ? 3 : 2)
            if need(muscle) < 2 && !profile.focusMuscles.contains(muscle) { sets = 2 }
            if lowReadiness { sets = max(1, sets - 1) }
            let rest = ex.restSeconds
            let cost = Double(sets) * secondsPerSet(ex, rest: rest) + 60
            if spent + cost > budgetSeconds && !slots.isEmpty { continue }
            spent += cost
            used.insert(ex.id)
            let reps: ClosedRange<Int>
            if profile.goal == .getStronger && ex.mechanic == .compound {
                let low = max(4, ex.repLow - 2)
                reps = low...max(low + 2, ex.repHigh - 4)
            } else {
                reps = ex.repRange
            }
            slots.append(ExerciseSlot(ex.id, sets: sets, reps: reps, rest: rest))
            for m in ex.primary { coveredThisSession[m, default: 0] += Double(sets) }
            for m in ex.secondary { coveredThisSession[m, default: 0] += Double(sets) * 0.5 }
            if slots.count >= 8 { break }
        }

        // Bileşik hareketler önce, gövde en sonda
        slots.sort { a, b in
            guard let ea = ExerciseCatalog.exercise(a.exerciseID), let eb = ExerciseCatalog.exercise(b.exerciseID) else { return false }
            let ra = (ea.pattern == .core ? 2 : (ea.mechanic == .compound ? 0 : 1))
            let rb = (eb.pattern == .core ? 2 : (eb.mechanic == .compound ? 0 : 1))
            return ra < rb
        }

        let fatigued = recovery.filter { $0.status == .fatigued }.map(\.muscle.displayName)
        if !fatigued.isEmpty { rationale.append("Dinlenen kaslar: \(fatigued.prefix(4).joined(separator: ", ")).") }
        let lagging = volume.filter { $0.status == .below && profile.focusMuscles.contains($0.muscle) }.map(\.muscle.displayName)
        if !lagging.isEmpty { rationale.append("Odak bölgelerine ekstra set: \(lagging.joined(separator: ", ")).") }
        if lowReadiness { rationale.append("Hazır olma skorun düşük olduğu için set sayıları azaltıldı.") }

        var focusNames: [String] = []
        for slot in slots {
            if let name = ExerciseCatalog.exercise(slot.exerciseID)?.primary.first?.displayName, !focusNames.contains(name) {
                focusNames.append(name)
            }
        }
        return GeneratedWorkout(title: title, focus: focusNames.prefix(4).joined(separator: " · "), slots: slots,
                                rationale: rationale, estimatedMinutes: Int((spent + 6 * 60) / 60))
    }
}
