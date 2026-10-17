import Foundation
import FormaKit

/// Uygulama ile widget'ların ortak ayarları.
enum AppConfig {
    /// Info.plist'teki "FormaAppGroup" anahtarından okunur (Config.xcconfig → APP_GROUP_ID).
    static var appGroupID: String? {
        Bundle.main.object(forInfoDictionaryKey: "FormaAppGroup") as? String
    }

    static let storage: FormaStorage = FormaStorage.shared(appGroupID: appGroupID)

    static let urlScheme = "forma"

    enum WidgetKind {
        static let today = "FormaTodayWidget"
        static let next = "FormaNextWorkoutWidget"
        static let rings = "FormaRingsWidget"
    }
}

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

/// Canlı antrenman: kilit ekranı ve Dynamic Island.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setIndex: Int
        var setCount: Int
        var targetWeight: Double
        var targetReps: Int
        var isTimed: Bool
        var restEndsAt: Date?
        var restTotalSeconds: Int
        var nextExerciseName: String?
        var completedSets: Int
        var totalSets: Int
        var isFinished: Bool
    }

    var sessionID: String
    var title: String
    var startedAt: Date
}
#endif
