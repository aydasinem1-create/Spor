import Foundation

/// Kalori ve makro hedefleri.
///
/// - Bazal metabolizma: Mifflin–St Jeor denklemi.
/// - Protein: ISSN'e göre egzersiz yapanlar için 1,4–2,0 g/kg; kalori açığında kası korumak için daha yüksek.
/// - Yağ kaybı hızı: haftada vücut ağırlığının yaklaşık %0,5–1'i (Helms ve ark., 2014).
/// - Kas kazanımı: küçük bir kalori fazlası (yaklaşık %5–10) gereksiz yağ artışını sınırlar.
public enum NutritionEngine {

    public static func bmr(profile: UserProfile, weightKg: Double? = nil, on date: Date = Date()) -> Double {
        let w = weightKg ?? profile.weightKg
        let base = 10 * w + 6.25 * profile.heightCm - 5 * Double(profile.age(on: date))
        return profile.sex == .male ? base + 5 : base - 161
    }

    /// Antrenmanın günlük ortalamaya eklediği enerji (kcal/gün).
    /// Direnç antrenmanı için kabaca dakikada ~5 kcal (orta yoğunluk); haftalık toplam 7'ye bölünür.
    public static func trainingKcalPerDay(profile: UserProfile) -> Double {
        let weeklyMinutes = Double(profile.trainingDaysPerWeek * profile.sessionMinutes)
        let perMinute = 0.07 * profile.weightKg   // 75 kg için ~5,3 kcal/dk
        return weeklyMinutes * perMinute / 7
    }

    /// Formülle tahmini günlük enerji harcaması (TDEE).
    public static func formulaTDEE(profile: UserProfile, weightKg: Double? = nil) -> Double {
        bmr(profile: profile, weightKg: weightKg) * profile.activityLevel.multiplier + trainingKcalPerDay(profile: profile)
    }

    public static func goalCalories(tdee: Double, profile: UserProfile, weightKg: Double? = nil) -> Double {
        let w = weightKg ?? profile.weightKg
        switch profile.goal {
        case .loseFat:
            // Haftada ~%0,75 kayıp hedefi; 1 kg yağ ≈ 7700 kcal. Açık TDEE'nin %25'ini geçmesin.
            let weeklyLossKg = w * 0.0075
            let dailyDeficit = min(weeklyLossKg * 7700 / 7, tdee * 0.25)
            return tdee - dailyDeficit
        case .buildMuscle:
            let surplus = profile.experience == .beginner ? 0.10 : 0.06
            return tdee * (1 + surplus)
        case .getStronger:
            return tdee * 1.05
        case .stayFit:
            return tdee
        }
    }

    public static func proteinPerKg(goal: Goal) -> Double {
        switch goal {
        case .loseFat: return 2.2
        case .buildMuscle: return 1.8
        case .getStronger: return 1.8
        case .stayFit: return 1.6
        }
    }

    /// Fazla kilolu kişilerde proteini toplam kilo yerine "referans kiloya" göre hesaplamak daha doğru.
    /// BMI 27'nin üstünde, boya göre BMI 25'teki kilo kullanılır.
    public static func proteinReferenceWeight(profile: UserProfile, weightKg: Double? = nil) -> Double {
        let w = weightKg ?? profile.weightKg
        let h = profile.heightCm / 100
        let bmi = w / (h * h)
        if bmi > 27 { return 25 * h * h }
        return w
    }

    public static func targets(profile: UserProfile, settings: AppSettings, adaptiveTDEE: Double? = nil, latestWeightKg: Double? = nil) -> DailyTargets {
        if settings.targetsAreManual, let manual = settings.manualTargets { return manual }
        let weight = latestWeightKg ?? profile.weightKg
        let tdee = adaptiveTDEE ?? formulaTDEE(profile: profile, weightKg: weight)
        var kcal = goalCalories(tdee: tdee, profile: profile, weightKg: weight)
        // Güvenli alt sınır
        let floor = profile.sex == .male ? 1500.0 : 1200.0
        kcal = max(kcal, floor)

        let protein = (proteinPerKg(goal: profile.goal) * proteinReferenceWeight(profile: profile, weightKg: weight)).rounded()
        // Yağ: en az kalorinin %25'i ya da 0,8 g/kg (hangisi büyükse), hormonal sağlık için.
        let fat = max(kcal * 0.25 / 9, 0.8 * weight).rounded()
        let carbKcal = max(kcal - protein * 4 - fat * 9, 0)
        let carbs = (carbKcal / 4).rounded()
        // Lif: 1000 kcal başına 14 g (yaygın öneri), 25–38 g arası.
        let fiber = (kcal / 1000 * 14).clamped(25...38).rounded()
        let water = HydrationEngine.dailyTarget(weightKg: weight, sex: profile.sex, trainingMinutes: 0, hotWeather: settings.hotWeather)
        let creatine = SupplementEngine.creatineMaintenanceDose(weightKg: weight)

        return DailyTargets(kcal: (kcal / 10).rounded() * 10, proteinG: protein, carbsG: carbs, fatG: fat,
                            fiberG: fiber, waterMl: water, creatineG: creatine)
    }

    /// Antrenman sonrası protein önerisi (g): 0,25 g/kg, 20–40 g arası.
    public static func perMealProtein(weightKg: Double) -> Double {
        (weightKg * 0.25).clamped(20...40).rounded()
    }
}

// MARK: - Kilo trendi

public struct WeightPoint: Codable, Hashable, Sendable {
    public var date: Date
    public var kg: Double
    public init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

/// Günlük tartı dalgalanmalarını (su, tuz, sindirim) yumuşatan üstel hareketli ortalama.
public enum WeightTrend {
    /// alpha ≈ 0,1 → yaklaşık 10 günlük yumuşatma.
    public static func smoothed(_ points: [WeightPoint], alpha: Double = 0.1, calendar: Calendar = .forma) -> [WeightPoint] {
        // Aynı gün birden fazla tartı varsa ortalamasını al
        let grouped = Dictionary(grouping: points) { calendar.startOfDay(for: $0.date) }
        let daily = grouped.map { WeightPoint(date: $0.key, kg: $0.value.map(\.kg).reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
        guard let first = daily.first else { return [] }
        var result: [WeightPoint] = [first]
        var trend = first.kg
        for i in 1..<daily.count {
            let gapDays = max(1, calendar.days(from: daily[i - 1].date, to: daily[i].date))
            // Boşluklu günlerde etkiyi gün sayısına göre büyüt
            let a = 1 - pow(1 - alpha, Double(gapDays))
            trend += a * (daily[i].kg - trend)
            result.append(WeightPoint(date: daily[i].date, kg: trend))
        }
        return result
    }

    /// Ham tartılara en küçük kareler doğrusu: kg/gün eğim. Trend ortalamasının gecikmesi olmadan hız verir.
    public static func slopePerDay(_ points: [WeightPoint], calendar: Calendar = .forma) -> Double? {
        guard let first = points.map(\.date).min() else { return nil }
        let xs = points.map { Double(calendar.days(from: first, to: $0.date)) }
        let ys = points.map(\.kg)
        let n = Double(points.count)
        guard n >= 3 else { return nil }
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        let sxx = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx > 0 else { return nil }
        let sxy = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        return sxy / sxx
    }

    /// Son N gündeki haftalık değişim (kg/hafta).
    public static func weeklyRate(_ points: [WeightPoint], days: Int = 21, now: Date = Date(), calendar: Calendar = .forma) -> Double? {
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) ?? now
        let recent = points.filter { $0.date >= start && $0.date <= now }
        guard let minD = recent.map(\.date).min(), let maxD = recent.map(\.date).max(),
              calendar.days(from: minD, to: maxD) >= 7 else { return nil }
        return slopePerDay(recent, calendar: calendar).map { $0 * 7 }
    }
}

// MARK: - Uyarlanabilir harcama (MacroFactor yaklaşımı)

/// Yediklerin ve tartı trendin birlikte gerçek harcamanı ortaya çıkarır:
/// harcama ≈ ortalama alım − (trend değişimi × 7700 / gün).
public enum AdaptiveExpenditure {

    public struct Estimate: Sendable, Equatable {
        public var tdee: Double
        /// 0–1 arası güven (kayıtlı gün oranı ve süreye göre).
        public var confidence: Double
        public var daysUsed: Int
        public var loggedDays: Int
    }

    /// - Parameters:
    ///   - dailyIntake: gün başlangıcı → o gün kaydedilen kalori. Hiç kayıt olmayan günler dahil edilmez.
    ///   - weights: tartı kayıtları.
    ///   - formulaTDEE: veri azken harmanlanacak formül değeri.
    public static func estimate(dailyIntake: [Date: Double], weights: [WeightPoint], formulaTDEE: Double,
                                window: Int = 28, now: Date = Date(), calendar: Calendar = .forma) -> Estimate? {
        let end = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -window, to: end) else { return nil }
        let inWindow = weights.filter { $0.date >= start && $0.date <= now }
        guard inWindow.count >= 4,
              let firstDate = inWindow.map(\.date).min(), let lastDate = inWindow.map(\.date).max() else { return nil }
        let span = calendar.days(from: firstDate, to: lastDate)
        guard span >= 10, let slope = WeightTrend.slopePerDay(inWindow, calendar: calendar) else { return nil }

        // Yalnızca ciddi kayıt yapılan günler (çok düşük değerler eksik kayıt sayılır)
        let minimumPlausible = formulaTDEE * 0.35
        let from = calendar.startOfDay(for: firstDate), to = calendar.startOfDay(for: lastDate)
        let intakes = dailyIntake.filter { $0.key >= from && $0.key <= to && $0.value >= minimumPlausible }
        guard intakes.count >= 7 else { return nil }
        let avgIntake = intakes.values.reduce(0, +) / Double(intakes.count)
        // 1 kg vücut dokusu değişimi ≈ 7700 kcal
        let raw = avgIntake - slope * 7700

        let coverage = Double(intakes.count) / Double(span + 1)
        let lengthFactor = min(1, Double(span) / 21)
        let confidence = (coverage * lengthFactor).clamped(0...1)
        // Güven düşükken formüle yakın kal
        let blended = formulaTDEE + (raw - formulaTDEE) * confidence
        // Mantık dışı değerleri sınırla
        let bounded = blended.clamped((formulaTDEE * 0.7)...(formulaTDEE * 1.4))
        return Estimate(tdee: bounded, confidence: confidence, daysUsed: span, loggedDays: intakes.count)
    }
}
