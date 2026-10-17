import Foundation

/// Sıvı hedefi.
///
/// EFSA yetişkinler için toplam su (yiyeceklerden gelen dahil) erkekte 2,5 L, kadında 2,0 L öneriyor;
/// bunun yaklaşık %70–80'i içeceklerden gelir. Günlük hedef için 30 ml/kg kullanıyoruz (70 kg → 2,1 L)
/// ve EFSA içecek payının altına düşürmüyoruz. Antrenman sırasında ter kaybı tipik olarak saatte
/// 0,5–1,5 L olduğu için antrenman saati başına 500 ml eklenir (ACSM: vücut ağırlığının %2'sinden
/// fazla sıvı kaybetmemek hedeflenir).
public enum HydrationEngine {

    public static func dailyTarget(weightKg: Double, sex: Sex, trainingMinutes: Double, hotWeather: Bool) -> Double {
        let perKg = weightKg * 30
        let efsaBeverages: Double = sex == .male ? 2000 : 1600
        var target = max(perKg, efsaBeverages)
        target += trainingMinutes / 60 * 500
        if hotWeather { target += 500 }
        return target.clamped(1500...5000).rounded(toStep: 50)
    }

    /// Bugün antrenman varsa hedefi artır.
    public static func adjustedForTraining(base: Double, plannedMinutes: Double) -> Double {
        (base + plannedMinutes / 60 * 500).clamped(1500...5500).rounded(toStep: 50)
    }

    /// Ramazanda iftar ile imsak arasındaki pencereye yayılmış içme planı (Aspetar: ~30 dakikada bir küçük yudumlar).
    public static func ramadanSchedule(targetMl: Double, iftar: Date, imsak: Date, sleepStart: Date?, calendar: Calendar = .forma) -> [(Date, Double)] {
        var slots: [Date] = []
        var t = iftar
        let end = imsak.addingTimeInterval(-15 * 60)
        while t < end {
            if let sleep = sleepStart, let wake = calendar.date(byAdding: .minute, value: -60, to: imsak), t > sleep && t < wake {
                t = t.addingTimeInterval(30 * 60)
                continue
            }
            slots.append(t)
            t = t.addingTimeInterval(45 * 60)
        }
        guard !slots.isEmpty else { return [] }
        let each = (targetMl / Double(slots.count)).rounded(toStep: 50)
        return slots.map { ($0, max(each, 100)) }
    }
}

/// Kreatin ve kafein ile ilgili hesaplar.
public enum SupplementEngine {

    /// ISSN: günde 3–5 g. Kiloyla hafifçe ölçekliyoruz (~0,03 g/kg), 0,5 g'a yuvarlıyoruz.
    public static func creatineMaintenanceDose(weightKg: Double) -> Double {
        (weightKg * 0.03 + 2.75).rounded(toStep: 0.5).clamped(3...5)
    }

    /// İsteğe bağlı yükleme: ~0,3 g/kg/gün, 5–7 gün, 4 eşit doza bölünür.
    public static func creatineLoadingDose(weightKg: Double) -> (perDay: Double, perDose: Double, days: Int) {
        let perDay = (weightKg * 0.3).rounded(toStep: 1).clamped(15...25)
        return (perDay, (perDay / 4).rounded(toStep: 0.5), 6)
    }

    /// Kas kreatin doygunluğu tahmini (%). Kesin ölçüm değildir.
    ///
    /// Literatürdeki zaman çizelgesine göre ayarlanmış basit model:
    /// - 20 g/gün ile ~5–7 günde doygunluk,
    /// - 3–5 g/gün ile ~3–4 haftada doygunluk,
    /// - bırakıldıktan sonra ~4–6 haftada başlangıç düzeyine dönüş.
    public static func creatineSaturation(dailyGrams: [Date: Double], until now: Date = Date(), calendar: Calendar = .forma) -> Double {
        guard let firstDay = dailyGrams.keys.min() else { return 0 }
        var s = 0.0
        var day = calendar.startOfDay(for: firstDay)
        let end = calendar.startOfDay(for: now)
        while day <= end {
            let g = dailyGrams[day] ?? 0
            if g > 0 {
                // Doygunluğa yaklaştıkça alım verimi düşer
                s += (g / 65) * (1 - s * 0.7)
            } else {
                s -= 0.022
            }
            s = s.clamped(0...1)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return (s * 100).rounded()
    }

    /// ISSN: performans için 3–6 mg/kg, egzersizden ~60 dk önce.
    public static func caffeinePerformanceRange(weightKg: Double) -> ClosedRange<Double> {
        (weightKg * 3).rounded(toStep: 10)...(weightKg * 6).rounded(toStep: 10)
    }

    /// Sağlıklı yetişkinler için genel günlük üst sınır (EFSA): 400 mg.
    public static let dailyCaffeineLimitMg: Double = 400

    /// Uyumadan önce kafeinin kesilmesi önerilen saat (yarı ömür ~5 saat; 6 saat kural).
    public static func caffeineCutoff(bedtimeHour: Int) -> Int {
        (bedtimeHour - 6 + 24) % 24
    }
}
