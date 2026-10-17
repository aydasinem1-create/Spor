import Foundation

/// Konuma göre iftar (akşam) ve imsak vakti hesabı.
///
/// Güneşin konumu "Almanac for Computers" algoritmasıyla hesaplanır (dakika düzeyinde doğruluk).
/// - İftar: gün batımı (güneş merkezi ufkun 0,833° altı) + temkin.
/// - İmsak: güneş ufkun 18° altındayken (Diyanet'in kullandığı açı).
/// Diyanet takvimi küçük "temkin" farkları uyguladığı için kullanıcı birkaç dakikalık ince ayar yapabilir.
public enum RamadanCalculator {

    public static let sunsetZenith = 90.833
    public static let fajrZenith = 108.0
    /// Diyanet akşam temkini (dakika).
    public static let defaultIftarTemkin = 7

    /// Verilen tarihte güneşin belirtilen zenit açısına geldiği an. Kutup bölgelerinde nil.
    public static func sunEvent(on date: Date, latitude: Double, longitude: Double, zenith: Double, rising: Bool,
                                calendar: Calendar = .forma) -> Date? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let local = calendar.dateComponents([.year, .month, .day], from: date)
        guard let dayStartUTC = utc.date(from: local) else { return nil }
        let n = Double(utc.ordinality(of: .day, in: .year, for: dayStartUTC) ?? 1)

        let rad = Double.pi / 180
        let lngHour = longitude / 15
        let t = n + ((rising ? 6 : 18) - lngHour) / 24
        let m = 0.9856 * t - 3.289
        var l = m + 1.916 * sin(m * rad) + 0.020 * sin(2 * m * rad) + 282.634
        l = l.truncatingRemainder(dividingBy: 360); if l < 0 { l += 360 }
        var ra = atan(0.91764 * tan(l * rad)) / rad
        ra = ra.truncatingRemainder(dividingBy: 360); if ra < 0 { ra += 360 }
        let lQuadrant = floor(l / 90) * 90
        let raQuadrant = floor(ra / 90) * 90
        ra = (ra + lQuadrant - raQuadrant) / 15
        let sinDec = 0.39782 * sin(l * rad)
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(zenith * rad) - sinDec * sin(latitude * rad)) / (cosDec * cos(latitude * rad))
        guard cosH >= -1 && cosH <= 1 else { return nil }
        var h = rising ? 360 - acos(cosH) / rad : acos(cosH) / rad
        h /= 15
        let localMeanTime = h + ra - 0.06571 * t - 6.622
        var ut = (localMeanTime - lngHour).truncatingRemainder(dividingBy: 24)
        if ut < 0 { ut += 24 }
        return dayStartUTC.addingTimeInterval(ut * 3600)
    }

    public struct Times: Equatable, Sendable {
        public var imsak: Date
        public var iftar: Date
        public var fastingHours: Double { iftar.timeIntervalSince(imsak) / 3600 }
    }

    public static func times(on date: Date, settings: RamadanSettings, calendar: Calendar = .forma) -> Times? {
        let start = calendar.startOfDay(for: date)
        var imsak: Date?
        var iftar: Date?
        if let lat = settings.latitude, let lon = settings.longitude {
            imsak = sunEvent(on: date, latitude: lat, longitude: lon, zenith: fajrZenith, rising: true, calendar: calendar)
            iftar = sunEvent(on: date, latitude: lat, longitude: lon, zenith: sunsetZenith, rising: false, calendar: calendar)
                .map { $0.addingTimeInterval(Double(defaultIftarTemkin) * 60) }
        }
        if imsak == nil, let m = settings.manualImsakMinutes { imsak = start.addingTimeInterval(Double(m) * 60) }
        if iftar == nil, let m = settings.manualIftarMinutes { iftar = start.addingTimeInterval(Double(m) * 60) }
        guard var i = imsak, var f = iftar else { return nil }
        i = i.addingTimeInterval(Double(settings.imsakOffsetMinutes) * 60)
        f = f.addingTimeInterval(Double(settings.iftarOffsetMinutes) * 60)
        return Times(imsak: i, iftar: f)
    }

    /// Ramazan'da önerilen antrenman penceresi: iftardan 1,5 saat sonra başlayan 2 saatlik dilim.
    /// Ağır antrenman iftar sonrası daha iyi tolere edilir (sıvı ve enerji alınmış olur).
    public static func suggestedTrainingWindow(times: Times) -> (start: Date, end: Date) {
        let start = times.iftar.addingTimeInterval(90 * 60)
        return (start, start.addingTimeInterval(120 * 60))
    }
}
