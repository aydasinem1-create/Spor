import Foundation

/// Kas toparlanması TAHMİNİ.
///
/// Bu bir ölçüm değil, antrenman kayıtlarından yapılan bir tahmindir (Fitbod benzeri yaklaşım):
/// 1. Her tamamlanan set, çalıştırdığı kasa "yük" ekler. Ana kas 1, yardımcı kas 0,5 set sayılır.
/// 2. Sete ne kadar yakın tükenişe gidildiyse (RIR düşükse) yük artar. Tükenişe kadar yapılan setler
///    toparlanmayı 24–48 saat uzatır (Morán-Navarro ve ark., 2017).
/// 3. Yük, kasa göre değişen bir hızla azalır: büyük kaslar ~72 saatte, küçük kaslar ~36–48 saatte
///    büyük ölçüde toparlanır (genel 48–72 saat önerisi).
/// 4. Kalan yük, kişinin bir seansta kaldırabileceği set kapasitesine bölünerek % toparlanmaya çevrilir.
/// Kullanıcı ağrı bildirirse tahmin buna göre düzeltilir.
public enum RecoveryEngine {

    public struct MuscleState: Identifiable, Hashable, Sendable {
        public var muscle: MuscleGroup
        public var percent: Double
        public var residualLoad: Double
        public var lastTrained: Date?
        public var hoursUntilReady: Double
        public var id: MuscleGroup { muscle }

        public var status: Status {
            if percent >= 80 { return .ready }
            if percent >= 50 { return .recovering }
            return .fatigued
        }

        public enum Status: String, Sendable {
            case ready, recovering, fatigued
            public var displayName: String {
                switch self {
                case .ready: return "Hazır"
                case .recovering: return "Toparlanıyor"
                case .fatigued: return "Yorgun"
                }
            }
        }
    }

    /// Sağlık'tan gelen koşu, bisiklet gibi aktiviteler.
    public struct ExternalActivity: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable { case running, cycling, walking, swimming, rowing, hiit, other }
        public var kind: Kind
        public var start: Date
        public var minutes: Double
        public init(kind: Kind, start: Date, minutes: Double) {
            self.kind = kind
            self.start = start
            self.minutes = minutes
        }

        func load() -> [MuscleGroup: Double] {
            switch kind {
            case .running: return [.quads: minutes / 20, .calves: minutes / 15, .hamstrings: minutes / 30, .glutes: minutes / 30]
            case .cycling: return [.quads: minutes / 20, .glutes: minutes / 40, .calves: minutes / 40]
            case .walking: return minutes >= 60 ? [.calves: minutes / 90] : [:]
            case .swimming: return [.lats: minutes / 25, .frontDelts: minutes / 30, .triceps: minutes / 40]
            case .rowing: return [.lats: minutes / 20, .upperBack: minutes / 20, .quads: minutes / 30, .biceps: minutes / 40]
            case .hiit: return [.quads: minutes / 15, .glutes: minutes / 20, .calves: minutes / 20, .abs: minutes / 25]
            case .other: return [:]
            }
        }
    }

    public struct Soreness: Codable, Hashable, Sendable {
        public var muscle: MuscleGroup
        public var date: Date
        /// 1 hafif … 3 çok ağrılı
        public var level: Int
        public init(muscle: MuscleGroup, date: Date, level: Int) {
            self.muscle = muscle
            self.date = date
            self.level = level
        }
    }

    /// Hazır sayılmak için toparlanma eşiği (%).
    public static let readyThreshold: Double = 80

    public static func effortFactor(kind: SetKind, rir: Int?) -> Double {
        switch kind {
        case .warmup: return 0
        case .failure: return 1.3
        case .drop: return 1.1
        case .working:
            guard let rir else { return 1.0 }
            switch rir {
            case ...0: return 1.25
            case 1: return 1.1
            case 2: return 1.0
            case 3: return 0.85
            default: return 0.65
            }
        }
    }

    /// Zaman sabiti: baseRecoveryHours sonunda yükün %15'i kalsın.
    public static func tau(for muscle: MuscleGroup) -> Double {
        muscle.baseRecoveryHours / log(1 / 0.15)
    }

    public static func states(sessions: [WorkoutSession],
                              external: [ExternalActivity] = [],
                              soreness: [Soreness] = [],
                              experience: Experience,
                              now: Date = Date()) -> [MuscleState] {
        let horizon = now.addingTimeInterval(-10 * 86_400)
        var load: [MuscleGroup: Double] = [:]
        var last: [MuscleGroup: Date] = [:]

        func add(_ muscle: MuscleGroup, amount: Double, at date: Date) {
            guard amount > 0, date <= now else { return }
            let hours = now.timeIntervalSince(date) / 3600
            load[muscle, default: 0] += amount * exp(-hours / tau(for: muscle))
            if last[muscle].map({ date > $0 }) ?? true { last[muscle] = date }
        }

        for session in sessions where session.startedAt >= horizon {
            for se in session.exercises {
                guard let ex = se.exercise else { continue }
                for set in se.sets where set.isCompleted {
                    let effort = effortFactor(kind: set.kind, rir: set.rir)
                    guard effort > 0 else { continue }
                    let when = set.completedAt ?? session.endedAt ?? session.startedAt
                    for m in ex.primary { add(m, amount: effort, at: when) }
                    for m in ex.secondary { add(m, amount: 0.5 * effort, at: when) }
                }
            }
        }

        for activity in external where activity.start >= horizon {
            for (m, amount) in activity.load() { add(m, amount: amount, at: activity.start) }
        }

        let capacity = experience.sessionCapacity
        // Ağrı bildirimi: o andaki yükü en az belirtilen düzeye çek
        for s in soreness where s.date >= horizon {
            let hours = now.timeIntervalSince(s.date) / 3600
            let reported = capacity * [0.0, 0.4, 0.65, 0.9][s.level.clamped(0...3)] * exp(-hours / tau(for: s.muscle))
            load[s.muscle] = max(load[s.muscle] ?? 0, reported)
        }

        return MuscleGroup.allCases.map { m in
            let residual = load[m] ?? 0
            let percent = (100 * (1 - min(1, residual / capacity))).rounded()
            let readyLoad = capacity * (1 - readyThreshold / 100)
            let hours = residual > readyLoad ? tau(for: m) * log(residual / readyLoad) : 0
            return MuscleState(muscle: m, percent: percent, residualLoad: residual, lastTrained: last[m], hoursUntilReady: hours)
        }
    }
}

/// Haftalık kas başına set sayısı.
///
/// Haftalık set sayısı ile kas büyümesi arasında doz–yanıt ilişkisi vardır; getiri azalarak artar
/// (Schoenfeld ve ark., 2017; Pelland ve ark., 2024). Yardımcı kaslar yarım set sayılır.
public enum VolumeEngine {

    public struct MuscleVolume: Identifiable, Hashable, Sendable {
        public var muscle: MuscleGroup
        public var sets: Double
        public var target: ClosedRange<Double>
        public var id: MuscleGroup { muscle }
        public var remaining: Double { max(0, target.lowerBound - sets) }
        public var status: Status {
            if sets < target.lowerBound { return .below }
            if sets > target.upperBound + 2 { return .above }
            return .onTarget
        }
        public enum Status: Sendable { case below, onTarget, above }
        public var progress: Double { target.lowerBound > 0 ? min(1.2, sets / target.lowerBound) : 1 }
    }

    /// Küçük kasların hedefi biraz daha düşük, çünkü bileşik hareketlerden de dolaylı set alırlar.
    public static func target(for muscle: MuscleGroup, experience: Experience, focus: Set<MuscleGroup>) -> ClosedRange<Double> {
        var range = experience.weeklySetRange
        switch muscle {
        case .forearms, .traps, .obliques, .adductors, .frontDelts, .lowerBack:
            range = (range.lowerBound * 0.5)...(range.upperBound * 0.6)
        case .abs, .calves, .rearDelts:
            range = (range.lowerBound * 0.7)...(range.upperBound * 0.8)
        default: break
        }
        if focus.contains(muscle) {
            range = (range.lowerBound + 4)...(range.upperBound + 4)
        }
        return range.lowerBound.rounded()...range.upperBound.rounded()
    }

    public static func weekly(sessions: [WorkoutSession], experience: Experience, focus: Set<MuscleGroup>,
                              weekContaining date: Date = Date(), calendar: Calendar = .forma) -> [MuscleVolume] {
        let start = calendar.startOfWeek(for: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? date
        var totals: [MuscleGroup: Double] = [:]
        for s in sessions where s.startedAt >= start && s.startedAt < end {
            for (m, v) in s.fractionalSets() { totals[m, default: 0] += v }
        }
        return MuscleGroup.allCases.map {
            MuscleVolume(muscle: $0, sets: totals[$0] ?? 0, target: target(for: $0, experience: experience, focus: focus))
        }
    }
}
