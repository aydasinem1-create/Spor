import Foundation

public struct Macros: Codable, Hashable, Sendable {
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public var fiber: Double

    public init(kcal: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0, fiber: Double = 0) {
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
    }

    public static let zero = Macros()

    public static func + (l: Macros, r: Macros) -> Macros {
        Macros(kcal: l.kcal + r.kcal, protein: l.protein + r.protein, carbs: l.carbs + r.carbs, fat: l.fat + r.fat, fiber: l.fiber + r.fiber)
    }

    public static func += (l: inout Macros, r: Macros) { l = l + r }

    public func scaled(_ factor: Double) -> Macros {
        Macros(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor, fiber: fiber * factor)
    }
}

public struct Serving: Codable, Hashable, Sendable {
    public var name: String
    public var grams: Double
    public init(_ name: String, _ grams: Double) {
        self.name = name
        self.grams = grams
    }
}

public enum FoodCategory: String, Codable, CaseIterable, Sendable {
    case protein, dairy, grains, legumes, dishes, soups, fruit, vegetables, nuts, fats, sweets, drinks, supplements, fastFood, custom
    public var displayName: String {
        switch self {
        case .protein: return "Et, tavuk, balık, yumurta"
        case .dairy: return "Süt ürünleri"
        case .grains: return "Ekmek, tahıl"
        case .legumes: return "Baklagiller"
        case .dishes: return "Yemekler"
        case .soups: return "Çorbalar"
        case .fruit: return "Meyve"
        case .vegetables: return "Sebze, salata"
        case .nuts: return "Kuruyemiş"
        case .fats: return "Yağlar"
        case .sweets: return "Tatlı, atıştırmalık"
        case .drinks: return "İçecek"
        case .supplements: return "Takviye"
        case .fastFood: return "Dışarıda yemek"
        case .custom: return "Benim yiyeceklerim"
        }
    }
}

public enum FoodSource: Codable, Hashable, Sendable {
    case builtIn
    case openFoodFacts(barcode: String)
    case custom
}

public struct Food: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var brand: String?
    public var category: FoodCategory
    /// 100 g başına değerler.
    public var per100g: Macros
    public var servings: [Serving]
    public var source: FoodSource
    /// Arama için ek kelimeler (eş anlamlılar).
    public var keywords: [String]

    public init(id: String, name: String, brand: String? = nil, category: FoodCategory, per100g: Macros,
                servings: [Serving] = [], source: FoodSource = .builtIn, keywords: [String] = []) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.per100g = per100g
        self.servings = servings
        self.source = source
        self.keywords = keywords
    }

    public func macros(grams: Double) -> Macros { per100g.scaled(grams / 100) }

    public var defaultServing: Serving { servings.first ?? Serving("100 g", 100) }
}

public struct FoodLog: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var meal: MealType
    public var foodID: String
    /// Yiyecek veritabanı değişse bile kayıt bozulmasın diye ad ve değerlerin kopyası.
    public var foodName: String
    public var per100g: Macros
    public var grams: Double
    public var servingLabel: String?

    public init(id: UUID = UUID(), date: Date = Date(), meal: MealType, food: Food, grams: Double, servingLabel: String? = nil) {
        self.id = id
        self.date = date
        self.meal = meal
        self.foodID = food.id
        self.foodName = food.name
        self.per100g = food.per100g
        self.grams = grams
        self.servingLabel = servingLabel
    }

    public var macros: Macros { per100g.scaled(grams / 100) }
}

// MARK: - Su ve içecekler

public enum Beverage: String, Codable, CaseIterable, Identifiable, Sendable {
    case water, mineralWater, tea, turkishCoffee, filterCoffee, espresso, ayran, milk, juice, cola, energyDrink, herbalTea

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .water: return "Su"
        case .mineralWater: return "Maden suyu"
        case .tea: return "Çay"
        case .turkishCoffee: return "Türk kahvesi"
        case .filterCoffee: return "Filtre kahve"
        case .espresso: return "Espresso"
        case .ayran: return "Ayran"
        case .milk: return "Süt"
        case .juice: return "Meyve suyu"
        case .cola: return "Kola"
        case .energyDrink: return "Enerji içeceği"
        case .herbalTea: return "Bitki çayı"
        }
    }

    public var symbol: String {
        switch self {
        case .water, .mineralWater: return "drop.fill"
        case .tea, .herbalTea: return "cup.and.saucer.fill"
        case .turkishCoffee, .filterCoffee, .espresso: return "mug.fill"
        case .ayran, .milk: return "waterbottle.fill"
        case .juice: return "carrot.fill"
        case .cola, .energyDrink: return "bubbles.and.sparkles.fill"
        }
    }

    /// Tipik tek porsiyon (ml).
    public var typicalML: Double {
        switch self {
        case .water, .mineralWater: return 250
        case .tea: return 100          // ince belli bardak
        case .herbalTea: return 200
        case .turkishCoffee: return 65
        case .filterCoffee: return 240
        case .espresso: return 30
        case .ayran: return 200
        case .milk: return 200
        case .juice: return 200
        case .cola: return 330
        case .energyDrink: return 250
        }
    }

    /// 100 ml'deki yaklaşık kafein (mg).
    public var caffeinePer100ml: Double {
        switch self {
        case .tea: return 20
        case .turkishCoffee: return 85
        case .filterCoffee: return 40
        case .espresso: return 210
        case .cola: return 10
        case .energyDrink: return 32
        default: return 0
        }
    }

    /// 100 ml'deki yaklaşık enerji (kcal).
    public var kcalPer100ml: Double {
        switch self {
        case .ayran: return 36
        case .milk: return 61
        case .juice: return 45
        case .cola: return 42
        case .energyDrink: return 45
        case .turkishCoffee: return 2
        default: return 0
        }
    }

    public var proteinPer100ml: Double {
        switch self {
        case .ayran: return 1.7
        case .milk: return 3.3
        default: return 0
        }
    }
}

public struct WaterLog: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var ml: Double
    public var beverage: Beverage

    public init(id: UUID = UUID(), date: Date = Date(), ml: Double, beverage: Beverage = .water) {
        self.id = id
        self.date = date
        self.ml = ml
        self.beverage = beverage
    }

    public var caffeineMg: Double { ml * beverage.caffeinePer100ml / 100 }
    public var kcal: Double { ml * beverage.kcalPer100ml / 100 }
    public var protein: Double { ml * beverage.proteinPer100ml / 100 }
}

// MARK: - Takviyeler

public enum SupplementKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case creatine, whey, casein, caffeine, omega3, vitaminD, magnesium, multivitamin, electrolyte, other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .creatine: return "Kreatin"
        case .whey: return "Whey protein"
        case .casein: return "Kazein"
        case .caffeine: return "Kafein / pre-workout"
        case .omega3: return "Omega-3"
        case .vitaminD: return "D vitamini"
        case .magnesium: return "Magnezyum"
        case .multivitamin: return "Multivitamin"
        case .electrolyte: return "Elektrolit"
        case .other: return "Diğer"
        }
    }

    public var symbol: String {
        switch self {
        case .creatine: return "bolt.fill"
        case .whey, .casein: return "takeoutbag.and.cup.and.straw.fill"
        case .caffeine: return "flame.fill"
        case .omega3: return "fish.fill"
        case .vitaminD: return "sun.max.fill"
        case .magnesium: return "moon.zzz.fill"
        case .multivitamin: return "pills.fill"
        case .electrolyte: return "drop.triangle.fill"
        case .other: return "capsule.fill"
        }
    }

    public var defaultUnit: String {
        switch self {
        case .creatine, .whey, .casein, .electrolyte: return "g"
        case .caffeine: return "mg"
        case .vitaminD: return "IU"
        case .omega3, .magnesium, .multivitamin, .other: return "adet"
        }
    }
}

public struct ReminderTime: Codable, Hashable, Sendable {
    public var hour: Int
    public var minute: Int
    public init(_ hour: Int, _ minute: Int = 0) {
        self.hour = hour
        self.minute = minute
    }
    public var minutesOfDay: Int { hour * 60 + minute }
    public var label: String { String(format: "%02d:%02d", hour, minute) }
}

public struct Supplement: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: SupplementKind
    public var name: String
    public var dose: Double
    public var unit: String
    public var timesPerDay: Int
    public var reminderTimes: [ReminderTime]
    /// Doz başına protein (whey/kazein için).
    public var proteinPerDose: Double
    /// Doz başına kafein (mg).
    public var caffeinePerDose: Double
    public var isActive: Bool
    public var onlyTrainingDays: Bool

    public init(id: UUID = UUID(), kind: SupplementKind, name: String? = nil, dose: Double, unit: String? = nil,
                timesPerDay: Int = 1, reminderTimes: [ReminderTime] = [], proteinPerDose: Double = 0,
                caffeinePerDose: Double = 0, isActive: Bool = true, onlyTrainingDays: Bool = false) {
        self.id = id
        self.kind = kind
        self.name = name ?? kind.displayName
        self.dose = dose
        self.unit = unit ?? kind.defaultUnit
        self.timesPerDay = timesPerDay
        self.reminderTimes = reminderTimes
        self.proteinPerDose = proteinPerDose
        self.caffeinePerDose = caffeinePerDose
        self.isActive = isActive
        self.onlyTrainingDays = onlyTrainingDays
    }

    public var doseLabel: String {
        let value = dose.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(dose)) : String(format: "%.1f", dose)
        return "\(value) \(unit)"
    }
}

public struct SupplementLog: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var supplementID: UUID
    public var date: Date
    public var amount: Double

    public init(id: UUID = UUID(), supplementID: UUID, date: Date = Date(), amount: Double) {
        self.id = id
        self.supplementID = supplementID
        self.date = date
        self.amount = amount
    }
}

// MARK: - Vücut

public struct BodyMeasurement: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var weightKg: Double?
    public var waistCm: Double?
    public var chestCm: Double?
    public var armCm: Double?
    public var hipCm: Double?
    public var thighCm: Double?
    public var bodyFatPercent: Double?

    public init(id: UUID = UUID(), date: Date = Date(), weightKg: Double? = nil, waistCm: Double? = nil, chestCm: Double? = nil,
                armCm: Double? = nil, hipCm: Double? = nil, thighCm: Double? = nil, bodyFatPercent: Double? = nil) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.waistCm = waistCm
        self.chestCm = chestCm
        self.armCm = armCm
        self.hipCm = hipCm
        self.thighCm = thighCm
        self.bodyFatPercent = bodyFatPercent
    }
}

public enum PhotoPose: String, Codable, CaseIterable, Sendable {
    case front, side, back
    public var displayName: String {
        switch self {
        case .front: return "Önden"
        case .side: return "Yandan"
        case .back: return "Arkadan"
        }
    }
}

public struct ProgressPhoto: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var pose: PhotoPose
    public var fileName: String
    public var weightKg: Double?

    public init(id: UUID = UUID(), date: Date = Date(), pose: PhotoPose, fileName: String, weightKg: Double? = nil) {
        self.id = id
        self.date = date
        self.pose = pose
        self.fileName = fileName
        self.weightKg = weightKg
    }
}
