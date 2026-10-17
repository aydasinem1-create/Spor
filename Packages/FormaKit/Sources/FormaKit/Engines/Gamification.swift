import Foundation

public enum StreakEngine {

    /// Bugünden (veya dünden) geriye doğru kesintisiz gün sayısı. Bugün henüz yapılmadıysa seri dünden sayılır.
    public static func dailyStreak(days: Set<String>, now: Date = Date(), calendar: Calendar = .forma) -> Int {
        var count = 0
        var day = calendar.startOfDay(for: now)
        if !days.contains(DayKey.key(day, calendar: calendar)) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        while days.contains(DayKey.key(day, calendar: calendar)) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    /// Haftalık antrenman hedefini tutturduğu ardışık hafta sayısı (bu hafta henüz bitmediyse sayılmaz ama seriyi bozmaz).
    public static func weeklyStreak(sessionDates: [Date], target: Int, now: Date = Date(), calendar: Calendar = .forma) -> Int {
        guard target > 0 else { return 0 }
        var perWeek: [Date: Int] = [:]
        for d in sessionDates { perWeek[calendar.startOfWeek(for: d), default: 0] += 1 }
        var week = calendar.startOfWeek(for: now)
        var count = 0
        if (perWeek[week] ?? 0) >= target { count += 1 }
        guard var prev = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { return count }
        while (perWeek[prev] ?? 0) >= target {
            count += 1
            week = prev
            guard let p = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            prev = p
        }
        return count
    }
}

public struct Achievement: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var symbol: String
    public var xp: Int
}

public struct GamificationStats: Sendable {
    public var totalWorkouts: Int
    public var totalSets: Int
    public var totalVolumeKg: Double
    public var creatineStreak: Int
    public var waterGoalStreak: Int
    public var proteinGoalStreak: Int
    public var weeklyStreak: Int
    public var prCount: Int
    public var bestSessionVolume: Double
    public var measurementCount: Int
    public var photoCount: Int
    public var earlyWorkouts: Int

    public init(totalWorkouts: Int = 0, totalSets: Int = 0, totalVolumeKg: Double = 0, creatineStreak: Int = 0,
                waterGoalStreak: Int = 0, proteinGoalStreak: Int = 0, weeklyStreak: Int = 0, prCount: Int = 0,
                bestSessionVolume: Double = 0, measurementCount: Int = 0, photoCount: Int = 0, earlyWorkouts: Int = 0) {
        self.totalWorkouts = totalWorkouts
        self.totalSets = totalSets
        self.totalVolumeKg = totalVolumeKg
        self.creatineStreak = creatineStreak
        self.waterGoalStreak = waterGoalStreak
        self.proteinGoalStreak = proteinGoalStreak
        self.weeklyStreak = weeklyStreak
        self.prCount = prCount
        self.bestSessionVolume = bestSessionVolume
        self.measurementCount = measurementCount
        self.photoCount = photoCount
        self.earlyWorkouts = earlyWorkouts
    }
}

public enum AchievementEngine {

    public static let all: [Achievement] = [
        Achievement(id: "first-workout", title: "İlk adım", detail: "İlk antrenmanını tamamla", symbol: "figure.walk", xp: 50),
        Achievement(id: "workouts-10", title: "Alışkanlık", detail: "10 antrenman tamamla", symbol: "10.circle.fill", xp: 150),
        Achievement(id: "workouts-25", title: "Kararlı", detail: "25 antrenman tamamla", symbol: "25.circle.fill", xp: 300),
        Achievement(id: "workouts-50", title: "Salonun demirbaşı", detail: "50 antrenman tamamla", symbol: "50.circle.fill", xp: 500),
        Achievement(id: "workouts-100", title: "Yüzler kulübü", detail: "100 antrenman tamamla", symbol: "crown.fill", xp: 1000),
        Achievement(id: "sets-500", title: "500 set", detail: "Toplam 500 çalışma seti", symbol: "square.stack.3d.up.fill", xp: 250),
        Achievement(id: "volume-10t", title: "10 ton", detail: "Toplamda 10.000 kg kaldır", symbol: "scalemass.fill", xp: 200),
        Achievement(id: "volume-100t", title: "100 ton", detail: "Toplamda 100.000 kg kaldır", symbol: "shippingbox.fill", xp: 600),
        Achievement(id: "creatine-7", title: "Kreatin haftası", detail: "7 gün üst üste kreatin", symbol: "bolt.fill", xp: 100),
        Achievement(id: "creatine-30", title: "Tam doygun", detail: "30 gün üst üste kreatin", symbol: "bolt.circle.fill", xp: 300),
        Achievement(id: "water-7", title: "Su gibi", detail: "7 gün üst üste su hedefi", symbol: "drop.fill", xp: 100),
        Achievement(id: "water-30", title: "Okyanus", detail: "30 gün üst üste su hedefi", symbol: "water.waves", xp: 300),
        Achievement(id: "protein-7", title: "Protein ustası", detail: "7 gün üst üste protein hedefi", symbol: "fork.knife", xp: 150),
        Achievement(id: "weekly-4", title: "Bir ay tam", detail: "4 hafta üst üste haftalık hedef", symbol: "calendar", xp: 250),
        Achievement(id: "weekly-12", title: "Üç ay tam", detail: "12 hafta üst üste haftalık hedef", symbol: "calendar.badge.checkmark", xp: 700),
        Achievement(id: "first-pr", title: "Rekor!", detail: "İlk kişisel rekorunu kır", symbol: "trophy.fill", xp: 75),
        Achievement(id: "pr-25", title: "Rekor avcısı", detail: "25 kişisel rekor", symbol: "medal.fill", xp: 400),
        Achievement(id: "session-5t", title: "Ağır gün", detail: "Tek antrenmanda 5.000 kg hacim", symbol: "flame.fill", xp: 150),
        Achievement(id: "measure-5", title: "Ölçen kazanır", detail: "5 kez vücut ölçüsü kaydet", symbol: "ruler.fill", xp: 100),
        Achievement(id: "photo-3", title: "Önce / sonra", detail: "3 ilerleme fotoğrafı", symbol: "camera.fill", xp: 100),
        Achievement(id: "early-bird", title: "Erkenci", detail: "Sabah 8'den önce 5 antrenman", symbol: "sunrise.fill", xp: 120)
    ]

    public static func unlocked(by s: GamificationStats) -> Set<String> {
        var ids: Set<String> = []
        if s.totalWorkouts >= 1 { ids.insert("first-workout") }
        if s.totalWorkouts >= 10 { ids.insert("workouts-10") }
        if s.totalWorkouts >= 25 { ids.insert("workouts-25") }
        if s.totalWorkouts >= 50 { ids.insert("workouts-50") }
        if s.totalWorkouts >= 100 { ids.insert("workouts-100") }
        if s.totalSets >= 500 { ids.insert("sets-500") }
        if s.totalVolumeKg >= 10_000 { ids.insert("volume-10t") }
        if s.totalVolumeKg >= 100_000 { ids.insert("volume-100t") }
        if s.creatineStreak >= 7 { ids.insert("creatine-7") }
        if s.creatineStreak >= 30 { ids.insert("creatine-30") }
        if s.waterGoalStreak >= 7 { ids.insert("water-7") }
        if s.waterGoalStreak >= 30 { ids.insert("water-30") }
        if s.proteinGoalStreak >= 7 { ids.insert("protein-7") }
        if s.weeklyStreak >= 4 { ids.insert("weekly-4") }
        if s.weeklyStreak >= 12 { ids.insert("weekly-12") }
        if s.prCount >= 1 { ids.insert("first-pr") }
        if s.prCount >= 25 { ids.insert("pr-25") }
        if s.bestSessionVolume >= 5_000 { ids.insert("session-5t") }
        if s.measurementCount >= 5 { ids.insert("measure-5") }
        if s.photoCount >= 3 { ids.insert("photo-3") }
        if s.earlyWorkouts >= 5 { ids.insert("early-bird") }
        return ids
    }

    /// XP: her tamamlanan çalışma seti 2, her antrenman 25, açılan rozetlerin XP'si.
    public static func xp(stats: GamificationStats, unlocked: Set<String>) -> Int {
        let badgeXP = all.filter { unlocked.contains($0.id) }.reduce(0) { $0 + $1.xp }
        return stats.totalSets * 2 + stats.totalWorkouts * 25 + badgeXP
    }

    public struct Level: Equatable, Sendable {
        public var level: Int
        public var title: String
        public var currentXP: Int
        public var levelStartXP: Int
        public var nextLevelXP: Int
        public var progress: Double {
            let span = Double(nextLevelXP - levelStartXP)
            return span > 0 ? Double(currentXP - levelStartXP) / span : 1
        }
    }

    static let titles = ["Çaylak", "Acemi", "Düzenli", "Azimli", "Güçlü", "Sağlam", "Demir", "Çelik", "Usta", "Efsane"]

    /// Seviye eşikleri her seviyede büyür: 0, 200, 500, 900, 1400, ...
    public static func level(for xp: Int) -> Level {
        var level = 1
        var start = 0
        var next = 200
        while xp >= next {
            level += 1
            start = next
            next += 200 + (level - 1) * 100
        }
        let title = titles[min(titles.count - 1, (level - 1) / 2)]
        return Level(level: level, title: title, currentXP: xp, levelStartXP: start, nextLevelXP: next)
    }
}
