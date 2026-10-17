import Foundation

/// Dosya tabanlı depolama. Ana veri tek dosyada; dış olaylar (widget, Siri, saat) ayrı küçük dosyalarda.
public final class FormaStorage: @unchecked Sendable {

    public let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "forma.storage", qos: .utility)

    public var dataURL: URL { directory.appendingPathComponent("forma-data.json") }
    public var backupURL: URL { directory.appendingPathComponent("forma-data.backup.json") }
    public var inboxURL: URL { directory.appendingPathComponent("inbox", isDirectory: true) }
    public var snapshotURL: URL { directory.appendingPathComponent("widget-snapshot.json") }
    public var liveWorkoutURL: URL { directory.appendingPathComponent("live-workout.json") }

    public init(directory: URL) {
        self.directory = directory
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        self.encoder = e
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        self.decoder = d
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
    }

    /// App Group klasörü (yoksa uygulamanın Belgeler klasörü).
    public static func shared(appGroupID: String?) -> FormaStorage {
        if let id = appGroupID, !id.isEmpty,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return FormaStorage(directory: url.appendingPathComponent("Forma", isDirectory: true))
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return FormaStorage(directory: docs.appendingPathComponent("Forma", isDirectory: true))
    }

    // MARK: Ana veri

    public func load() -> FormaData {
        if let data = try? Data(contentsOf: dataURL), let decoded = try? decoder.decode(FormaData.self, from: data) {
            return decoded
        }
        // Ana dosya bozulduysa yedekten dön
        if let data = try? Data(contentsOf: backupURL), let decoded = try? decoder.decode(FormaData.self, from: data) {
            return decoded
        }
        return FormaData()
    }

    public func saveNow(_ value: FormaData) throws {
        let data = try encoder.encode(value)
        if FileManager.default.fileExists(atPath: dataURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try? FileManager.default.copyItem(at: dataURL, to: backupURL)
        }
        try data.write(to: dataURL, options: [.atomic])
    }

    private var pending: DispatchWorkItem?

    /// Sık değişikliklerde diski yormamak için kısa gecikmeli kayıt.
    public func save(_ value: FormaData, debounce: TimeInterval = 0.6) {
        pending?.cancel()
        let item = DispatchWorkItem { [weak self] in try? self?.saveNow(value) }
        pending = item
        queue.asyncAfter(deadline: .now() + debounce, execute: item)
    }

    /// Bekleyen kaydı hemen yaz (uygulama arka plana geçerken).
    public func flush(_ value: FormaData) {
        pending?.cancel()
        queue.sync { try? self.saveNow(value) }
    }

    // MARK: Olay kutusu

    public func append(_ event: InboxEvent) {
        guard let data = try? encoder.encode(event) else { return }
        let url = inboxURL.appendingPathComponent("\(event.eventID.uuidString).json")
        try? data.write(to: url, options: [.atomic])
    }

    public func pendingEvents() -> [(URL, InboxEvent)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url), let e = try? decoder.decode(InboxEvent.self, from: data) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return (url, e)
        }
    }

    public func removeEvents(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: Widget özeti

    public func writeSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: [.atomic])
    }

    public func readSnapshot() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    // MARK: Canlı antrenman (Live Activity düğmeleri için)

    public func writeLiveWorkout(_ state: LiveWorkoutState?) {
        guard let state else {
            try? FileManager.default.removeItem(at: liveWorkoutURL)
            return
        }
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: liveWorkoutURL, options: [.atomic])
    }

    public func readLiveWorkout() -> LiveWorkoutState? {
        guard let data = try? Data(contentsOf: liveWorkoutURL) else { return nil }
        return try? decoder.decode(LiveWorkoutState.self, from: data)
    }

    // MARK: Dışa aktarma

    public func exportData(_ value: FormaData) throws -> URL {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("forma-yedek-\(DayKey.key(Date())).json")
        try e.encode(value).write(to: url, options: .atomic)
        return url
    }

    public func importData(from url: URL) throws -> FormaData {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return try d.decode(FormaData.self, from: Data(contentsOf: url))
    }
}

// MARK: - Widget ve saat için özet

public struct WidgetSnapshot: Codable, Hashable, Sendable {
    public struct SupplementItem: Codable, Hashable, Sendable, Identifiable {
        public var id: UUID
        public var kind: SupplementKind
        public var name: String
        public var dose: String
        public var taken: Bool
        public init(id: UUID, kind: SupplementKind, name: String, dose: String, taken: Bool) {
            self.id = id
            self.kind = kind
            self.name = name
            self.dose = dose
            self.taken = taken
        }
    }

    public var day: String
    public var generatedAt: Date
    public var targets: DailyTargets
    public var kcal: Double
    public var protein: Double
    public var waterMl: Double
    public var supplements: [SupplementItem]
    public var nextWorkoutTitle: String?
    public var nextWorkoutFocus: String?
    public var nextWorkoutMinutes: Int?
    public var trainedToday: Bool
    public var creatineStreak: Int
    public var weekWorkouts: Int
    public var weekTarget: Int
    public var level: Int
    public var levelProgress: Double
    public var readiness: Int?

    public init(day: String, generatedAt: Date, targets: DailyTargets, kcal: Double, protein: Double, waterMl: Double,
                supplements: [SupplementItem], nextWorkoutTitle: String?, nextWorkoutFocus: String?, nextWorkoutMinutes: Int?,
                trainedToday: Bool, creatineStreak: Int, weekWorkouts: Int, weekTarget: Int, level: Int, levelProgress: Double,
                readiness: Int?) {
        self.day = day
        self.generatedAt = generatedAt
        self.targets = targets
        self.kcal = kcal
        self.protein = protein
        self.waterMl = waterMl
        self.supplements = supplements
        self.nextWorkoutTitle = nextWorkoutTitle
        self.nextWorkoutFocus = nextWorkoutFocus
        self.nextWorkoutMinutes = nextWorkoutMinutes
        self.trainedToday = trainedToday
        self.creatineStreak = creatineStreak
        self.weekWorkouts = weekWorkouts
        self.weekTarget = weekTarget
        self.level = level
        self.levelProgress = levelProgress
        self.readiness = readiness
    }

    public static let preview = WidgetSnapshot(
        day: DayKey.key(Date()), generatedAt: Date(), targets: .placeholder, kcal: 1650, protein: 92, waterMl: 1800,
        supplements: [SupplementItem(id: UUID(), kind: .creatine, name: "Kreatin", dose: "5 g", taken: true),
                      SupplementItem(id: UUID(), kind: .whey, name: "Whey protein", dose: "1 ölçek", taken: false)],
        nextWorkoutTitle: "Tam Vücut A", nextWorkoutFocus: "Bacak · Göğüs · Sırt", nextWorkoutMinutes: 50,
        trainedToday: false, creatineStreak: 12, weekWorkouts: 2, weekTarget: 3, level: 4, levelProgress: 0.6, readiness: 78)

    /// Bekleyen (henüz uygulamaya işlenmemiş) olayları özete ekler; widget anında güncel görünür.
    public func applying(_ events: [InboxEvent], calendar: Calendar = .forma) -> WidgetSnapshot {
        var s = self
        for e in events where DayKey.key(e.date, calendar: calendar) == day {
            switch e {
            case let .water(_, _, ml, beverage):
                s.waterMl += ml
                s.protein += ml * beverage.proteinPer100ml / 100
            case let .supplement(_, _, sid, kind, _):
                if let i = s.supplements.firstIndex(where: { $0.id == sid || (sid == nil && $0.kind == kind && !$0.taken) }) {
                    s.supplements[i].taken = true
                }
            default: break
            }
        }
        return s
    }
}

/// Live Activity ve saatin gösterdiği canlı antrenman durumu.
public struct LiveWorkoutState: Codable, Hashable, Sendable {
    public var sessionID: UUID
    public var title: String
    public var startedAt: Date
    public var exerciseIndex: Int
    public var exerciseName: String
    public var setIndex: Int
    public var setCount: Int
    public var targetWeight: Double
    public var targetReps: Int
    public var restEndsAt: Date?
    public var nextExerciseName: String?
    public var completedSets: Int
    public var totalSets: Int

    public init(sessionID: UUID, title: String, startedAt: Date, exerciseIndex: Int, exerciseName: String, setIndex: Int,
                setCount: Int, targetWeight: Double, targetReps: Int, restEndsAt: Date?, nextExerciseName: String?,
                completedSets: Int, totalSets: Int) {
        self.sessionID = sessionID
        self.title = title
        self.startedAt = startedAt
        self.exerciseIndex = exerciseIndex
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.setCount = setCount
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.restEndsAt = restEndsAt
        self.nextExerciseName = nextExerciseName
        self.completedSets = completedSets
        self.totalSets = totalSets
    }
}
