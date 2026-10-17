import Foundation

// MARK: - Kas grupları

/// Uygulamanın takip ettiği kas grupları. Toparlanma ve haftalık hacim bu gruplar üzerinden hesaplanır.
public enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case chest, lats, upperBack, traps
    case frontDelts, sideDelts, rearDelts
    case biceps, triceps, forearms
    case abs, obliques, lowerBack
    case glutes, quads, hamstrings, calves, adductors

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chest: return "Göğüs"
        case .lats: return "Kanat"
        case .upperBack: return "Sırt"
        case .traps: return "Trapez"
        case .frontDelts: return "Ön omuz"
        case .sideDelts: return "Yan omuz"
        case .rearDelts: return "Arka omuz"
        case .biceps: return "Pazu"
        case .triceps: return "Arka kol"
        case .forearms: return "Ön kol"
        case .abs: return "Karın"
        case .obliques: return "Yan karın"
        case .lowerBack: return "Bel"
        case .glutes: return "Kalça"
        case .quads: return "Ön bacak"
        case .hamstrings: return "Arka bacak"
        case .calves: return "Baldır"
        case .adductors: return "İç bacak"
        }
    }

    /// Ağır bir antrenmandan sonra büyük ölçüde toparlanma için tipik süre (saat).
    /// Büyük ve çok eklemli hareketlerle yüklenen kaslar daha uzun sürer (genel öneri 48–72 saat).
    public var baseRecoveryHours: Double {
        switch self {
        case .quads, .hamstrings, .glutes, .lowerBack: return 72
        case .chest, .lats, .upperBack, .adductors: return 60
        case .traps, .frontDelts, .sideDelts, .rearDelts, .biceps, .triceps, .calves: return 48
        case .forearms, .abs, .obliques: return 36
        }
    }

    public var region: BodyRegion {
        switch self {
        case .chest, .lats, .upperBack, .traps, .frontDelts, .sideDelts, .rearDelts, .biceps, .triceps, .forearms:
            return .upper
        case .abs, .obliques, .lowerBack:
            return .core
        case .glutes, .quads, .hamstrings, .calves, .adductors:
            return .lower
        }
    }

    /// Kabaca "büyük kas" mı? Hacim hedefi ve dinlenme süresi önerisinde kullanılır.
    public var isLarge: Bool {
        switch self {
        case .chest, .lats, .upperBack, .quads, .hamstrings, .glutes: return true
        default: return false
        }
    }

    /// free-exercise-db veri setindeki kas adlarından eşleme.
    public static func fromDataset(_ name: String) -> [MuscleGroup] {
        switch name.lowercased() {
        case "abdominals": return [.abs]
        case "abductors": return [.glutes]
        case "adductors": return [.adductors]
        case "biceps": return [.biceps]
        case "calves": return [.calves]
        case "chest": return [.chest]
        case "forearms": return [.forearms]
        case "glutes": return [.glutes]
        case "hamstrings": return [.hamstrings]
        case "lats": return [.lats]
        case "lower back": return [.lowerBack]
        case "middle back": return [.upperBack]
        case "quadriceps": return [.quads]
        case "shoulders": return [.sideDelts, .frontDelts]
        case "traps": return [.traps]
        case "triceps": return [.triceps]
        default: return []
        }
    }
}

public enum BodyRegion: String, Codable, CaseIterable, Sendable {
    case upper, core, lower
    public var displayName: String {
        switch self {
        case .upper: return "Üst vücut"
        case .core: return "Gövde"
        case .lower: return "Alt vücut"
        }
    }
}

// MARK: - Ekipman

public enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, ezBar, smith, pullupBar, bench, band

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .barbell: return "Halter (bar)"
        case .dumbbell: return "Dambıl"
        case .machine: return "Makineler"
        case .cable: return "Kablo istasyonu"
        case .bodyweight: return "Vücut ağırlığı"
        case .kettlebell: return "Kettlebell"
        case .ezBar: return "EZ bar"
        case .smith: return "Smith makinesi"
        case .pullupBar: return "Barfiks barı"
        case .bench: return "Bench (sehpa)"
        case .band: return "Direnç bandı"
        }
    }

    public var symbol: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .machine: return "gearshape.2.fill"
        case .cable: return "cable.connector"
        case .bodyweight: return "figure.core.training"
        case .kettlebell: return "scalemass.fill"
        case .ezBar: return "line.3.horizontal"
        case .smith: return "square.split.1x2"
        case .pullupBar: return "figure.climbing"
        case .bench: return "rectangle.portrait.fill"
        case .band: return "lasso"
        }
    }

    /// Tam donanımlı salon varsayılanı.
    public static let fullGym: Set<Equipment> = Set(Equipment.allCases)
    public static let homeDumbbells: Set<Equipment> = [.dumbbell, .bodyweight, .bench, .band]
}

// MARK: - Profil seçenekleri

public enum Goal: String, Codable, CaseIterable, Identifiable, Sendable {
    case buildMuscle, loseFat, getStronger, stayFit
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .buildMuscle: return "Kas kazanmak"
        case .loseFat: return "Yağ yakmak"
        case .getStronger: return "Güçlenmek"
        case .stayFit: return "Formda kalmak"
        }
    }
    public var subtitle: String {
        switch self {
        case .buildMuscle: return "Hafif kalori fazlası, yüksek protein"
        case .loseFat: return "Kontrollü kalori açığı, kası korumak"
        case .getStronger: return "Daha düşük tekrar, ağırlık artışı"
        case .stayFit: return "Dengeli, sürdürülebilir rutin"
        }
    }
    public var symbol: String {
        switch self {
        case .buildMuscle: return "figure.strengthtraining.functional"
        case .loseFat: return "flame.fill"
        case .getStronger: return "bolt.fill"
        case .stayFit: return "heart.fill"
        }
    }
}

public enum Experience: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner, intermediate, advanced
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .beginner: return "Yeni başlıyorum"
        case .intermediate: return "6 ay – 2 yıl"
        case .advanced: return "2 yıldan fazla"
        }
    }
    /// Haftalık kas başına "kesirli set" hedef aralığı. Hacim arttıkça kazanım artar ama azalan getiriyle.
    public var weeklySetRange: ClosedRange<Double> {
        switch self {
        case .beginner: return 8...12
        case .intermediate: return 10...16
        case .advanced: return 12...20
        }
    }
    /// Bir kasın tek seansta kaldırabileceği "etkili set" kapasitesi (toparlanma modeli ölçeği).
    public var sessionCapacity: Double {
        switch self {
        case .beginner: return 6
        case .intermediate: return 8
        case .advanced: return 10
        }
    }
    /// Yeni başlayanlar için önerilen yedek tekrar (RIR).
    public var targetRIR: Int {
        switch self {
        case .beginner: return 2
        case .intermediate: return 1
        case .advanced: return 1
        }
    }
}

public enum Sex: String, Codable, CaseIterable, Identifiable, Sendable {
    case female, male
    public var id: String { rawValue }
    public var displayName: String { self == .female ? "Kadın" : "Erkek" }
}

public enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary, light, moderate, high, veryHigh
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .sedentary: return "Masa başı"
        case .light: return "Az hareketli"
        case .moderate: return "Orta hareketli"
        case .high: return "Çok hareketli"
        case .veryHigh: return "Ağır fiziksel iş"
        }
    }
    public var detail: String {
        switch self {
        case .sedentary: return "Günün çoğu oturarak, < 5.000 adım"
        case .light: return "5.000–7.500 adım"
        case .moderate: return "7.500–10.000 adım"
        case .high: return "10.000+ adım veya ayakta iş"
        case .veryHigh: return "İnşaat, kurye gibi yoğun iş"
        }
    }
    /// Antrenman HARİÇ günlük aktivite çarpanı (BMR × çarpan). Antrenman ayrıca eklenir.
    public var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.3
        case .moderate: return 1.4
        case .high: return 1.5
        case .veryHigh: return 1.7
        }
    }
}

public enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast, lunch, dinner, snack, suhoor, iftar
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .breakfast: return "Kahvaltı"
        case .lunch: return "Öğle"
        case .dinner: return "Akşam"
        case .snack: return "Ara öğün"
        case .suhoor: return "Sahur"
        case .iftar: return "İftar"
        }
    }
    public var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "takeoutbag.and.cup.and.straw.fill"
        case .suhoor: return "moon.stars.fill"
        case .iftar: return "sunset.fill"
        }
    }
    public static let normalDay: [MealType] = [.breakfast, .lunch, .dinner, .snack]
    public static let ramadanDay: [MealType] = [.iftar, .snack, .suhoor]

    /// Saate göre en olası öğün.
    public static func suggested(for date: Date, ramadan: Bool, calendar: Calendar = .current) -> MealType {
        let hour = calendar.component(.hour, from: date)
        if ramadan {
            if hour < 6 { return .suhoor }
            if hour >= 17 && hour < 22 { return .iftar }
            return .snack
        }
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 17..<23: return .dinner
        default: return .snack
        }
    }
}

public enum SetKind: String, Codable, CaseIterable, Sendable {
    case warmup, working, drop, failure
    public var displayName: String {
        switch self {
        case .warmup: return "Isınma"
        case .working: return "Normal"
        case .drop: return "Drop set"
        case .failure: return "Tükeniş"
        }
    }
    public var shortLabel: String {
        switch self {
        case .warmup: return "I"
        case .working: return ""
        case .drop: return "D"
        case .failure: return "T"
        }
    }
    public var countsTowardVolume: Bool { self != .warmup }
}

public enum Mechanic: String, Codable, Sendable {
    case compound, isolation
}

public enum MovementPattern: String, Codable, CaseIterable, Sendable {
    case horizontalPush, verticalPush, horizontalPull, verticalPull, squat, hinge, lunge, isolationUpper, isolationLower, core, carry
}

public enum TrackingType: String, Codable, Sendable {
    /// Ağırlık + tekrar
    case weightReps
    /// Sadece tekrar (vücut ağırlığı); isteğe bağlı ek ağırlık
    case reps
    /// Süre (saniye), örn. plank
    case duration
}

public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case beginner, intermediate, advanced
    public var displayName: String {
        switch self {
        case .beginner: return "Başlangıç"
        case .intermediate: return "Orta"
        case .advanced: return "İleri"
        }
    }
}
