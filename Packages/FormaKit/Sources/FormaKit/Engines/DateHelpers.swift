import Foundation

public extension Calendar {
    /// Türkiye için pazartesi başlangıçlı takvim.
    static var forma: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "tr_TR")
        cal.firstWeekday = 2
        cal.timeZone = .current
        return cal
    }

    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? startOfDay(for: date)
    }

    func days(from start: Date, to end: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: start), to: startOfDay(for: end)).day ?? 0
    }
}

public enum DayKey {
    /// "2026-10-16" biçiminde gün anahtarı (gruplama için).
    public static func key(_ date: Date, calendar: Calendar = .forma) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

public extension Double {
    /// Belirli bir adıma yuvarla (örn. 2.5 kg).
    func rounded(toStep step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }

    func roundedDown(toStep step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded(.down) * step
    }

    /// "32,5" gibi Türkçe gösterim; tam sayıysa ondalıksız.
    var formattedKg: String {
        if abs(self - self.rounded()) < 0.001 { return String(Int(self.rounded())) }
        let s = String(format: "%.2f", self)
        var trimmed = s
        while trimmed.hasSuffix("0") { trimmed.removeLast() }
        if trimmed.hasSuffix(".") { trimmed.removeLast() }
        return trimmed.replacingOccurrences(of: ".", with: ",")
    }

    func clamped(_ range: ClosedRange<Double>) -> Double { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}

public extension Int {
    func clamped(_ range: ClosedRange<Int>) -> Int { Swift.min(Swift.max(self, range.lowerBound), range.upperBound) }
}
