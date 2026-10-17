import Foundation

/// "Bugün ne kadar hazırım?" skoru (0–100).
///
/// Apple Watch'un ölçtüğü verilerle, kişinin KENDİ ortalamasına göre değerlendirilir:
/// - Uyku süresi (son gece) – yetersiz uyku kuvvet performansını ve toparlanmayı düşürür.
/// - Kalp atış hızı değişkenliği (HRV, SDNN) – 30 günlük ortalamanın belirgin altındaysa sistem yorgun olabilir.
/// - Dinlenik nabız – ortalamanın belirgin üstündeyse yorgunluk, hastalık veya stres işareti olabilir.
/// - Kas toparlanma tahmini – bugünkü plana göre.
/// - İsteğe bağlı: kullanıcının kendi hissi (1–5).
/// Eksik veri olan bileşenler hesaba katılmaz; ağırlıklar kalanlara dağıtılır.
/// Skor bir öneridir; tıbbi bir değerlendirme değildir.
public enum ReadinessEngine {

    public struct Inputs: Sendable {
        public var sleepHours: Double?
        public var sleepGoalHours: Double
        public var hrvToday: Double?
        public var hrvBaseline: [Double]
        public var restingHRToday: Double?
        public var restingHRBaseline: [Double]
        public var muscleReadiness: Double?
        public var feeling: Int?

        public init(sleepHours: Double? = nil, sleepGoalHours: Double = 8, hrvToday: Double? = nil, hrvBaseline: [Double] = [],
                    restingHRToday: Double? = nil, restingHRBaseline: [Double] = [], muscleReadiness: Double? = nil, feeling: Int? = nil) {
            self.sleepHours = sleepHours
            self.sleepGoalHours = sleepGoalHours
            self.hrvToday = hrvToday
            self.hrvBaseline = hrvBaseline
            self.restingHRToday = restingHRToday
            self.restingHRBaseline = restingHRBaseline
            self.muscleReadiness = muscleReadiness
            self.feeling = feeling
        }
    }

    public struct Component: Identifiable, Sendable, Equatable {
        public var id: String { name }
        public var name: String
        public var score: Double
        public var detail: String
        public var weight: Double
    }

    public struct Result: Sendable, Equatable {
        public var score: Int
        public var components: [Component]
        public var level: Level
        public var advice: String

        public enum Level: String, Sendable {
            case high, normal, low
            public var displayName: String {
                switch self {
                case .high: return "Hazırsın"
                case .normal: return "Normal"
                case .low: return "Hafif gün"
                }
            }
        }
    }

    static func meanSD(_ values: [Double]) -> (mean: Double, sd: Double)? {
        guard values.count >= 5 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return (mean: mean, sd: max(sqrt(variance), mean * 0.04))
    }

    public static func evaluate(_ input: Inputs) -> Result? {
        var comps: [Component] = []

        if let sleep = input.sleepHours, sleep > 0 {
            let ratio = sleep / input.sleepGoalHours
            let score = (ratio >= 1 ? 100 : max(0, 100 - (1 - ratio) * 160)).clamped(0...100)
            let h = Int(sleep), m = Int((sleep - Double(h)) * 60)
            comps.append(Component(name: "Uyku", score: score, detail: "\(h) sa \(m) dk", weight: 0.35))
        }

        if let hrv = input.hrvToday, let stats = meanSD(input.hrvBaseline) {
            let mean = stats.mean, sd = stats.sd
            let z = (hrv - mean) / sd
            let score = (75 + z * 20).clamped(0...100)
            let diff = Int(((hrv - mean) / mean * 100).rounded())
            comps.append(Component(name: "HRV", score: score, detail: "\(Int(hrv)) ms (ortalamaya göre \(diff >= 0 ? "+" : "")\(diff)%)", weight: 0.25))
        }

        if let rhr = input.restingHRToday, let stats = meanSD(input.restingHRBaseline) {
            let mean = stats.mean, sd = stats.sd
            let z = (rhr - mean) / sd
            let score = (80 - z * 20).clamped(0...100)
            let diff = Int((rhr - mean).rounded())
            comps.append(Component(name: "Dinlenik nabız", score: score, detail: "\(Int(rhr)) bpm (\(diff >= 0 ? "+" : "")\(diff))", weight: 0.15))
        }

        if let muscle = input.muscleReadiness {
            comps.append(Component(name: "Kaslar", score: muscle.clamped(0...100), detail: "%\(Int(muscle)) toparlanmış", weight: 0.15))
        }

        if let feeling = input.feeling {
            let score = Double(feeling.clamped(1...5) - 1) * 25
            comps.append(Component(name: "Hissin", score: score, detail: ["Çok kötü", "Yorgun", "İdare eder", "İyi", "Harika"][feeling.clamped(1...5) - 1], weight: 0.2))
        }

        guard !comps.isEmpty else { return nil }
        let totalWeight = comps.reduce(0) { $0 + $1.weight }
        let score = Int((comps.reduce(0) { $0 + $1.score * $1.weight } / totalWeight).rounded())

        let level: Result.Level
        let advice: String
        switch score {
        case 75...:
            level = .high
            advice = "Planı olduğu gibi uygula; ağırlık artırma önerileri açık."
        case 50..<75:
            level = .normal
            advice = "Normal bir gün. Planı uygula, son setlerde 1–2 tekrar yedek bırak."
        default:
            level = .low
            advice = "Bugün hafif tut: her harekette 1 set eksik, ağırlık artırma yok. Uyku ve su öncelik."
        }
        return Result(score: score, components: comps, level: level, advice: advice)
    }
}
