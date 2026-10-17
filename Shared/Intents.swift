import AppIntents
import Foundation
import FormaKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Widget, Siri, Kısayollar ve Live Activity düğmelerinden gelen işlemleri uygulamaya iletir.
/// Uygulama çalışıyorsa doğrudan uygular; widget sürecindeyse olay kutusuna yazar.
enum IntentBridge {
    @MainActor static var handler: ((InboxEvent) -> Void)?
    @MainActor static var routeHandler: ((String) -> Void)?

    @MainActor static func send(_ event: InboxEvent) {
        if let handler {
            handler(event)
        } else {
            AppConfig.storage.append(event)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Su ekle"
    static let description = IntentDescription("Bugünkü su takibine ekler.")

    @Parameter(title: "Miktar (ml)", default: 250)
    var ml: Int

    init() {}
    init(ml: Int) { self.ml = ml }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let amount = max(50, min(ml, 2000))
        IntentBridge.send(.water(id: UUID(), date: Date(), ml: Double(amount), beverage: .water))
        return .result(dialog: "\(amount) ml su eklendi.")
    }
}

struct TakeCreatineIntent: AppIntent {
    static let title: LocalizedStringResource = "Kreatinimi aldım"
    static let description = IntentDescription("Bugünkü kreatin dozunu alındı olarak işaretler.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentBridge.send(.supplement(id: UUID(), date: Date(), supplementID: nil, kind: .creatine, amount: 0))
        return .result(dialog: "Kreatin işaretlendi. Seriye devam!")
    }
}

struct TakeSupplementIntent: AppIntent {
    static let title: LocalizedStringResource = "Takviye alındı"
    static let isDiscoverable = false

    @Parameter(title: "Takviye")
    var supplementID: String

    @Parameter(title: "Tür")
    var kindRaw: String

    init() {}
    init(supplementID: UUID, kind: SupplementKind) {
        self.supplementID = supplementID.uuidString
        self.kindRaw = kind.rawValue
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let kind = SupplementKind(rawValue: kindRaw) ?? .other
        IntentBridge.send(.supplement(id: UUID(), date: Date(), supplementID: UUID(uuidString: supplementID), kind: kind, amount: 0))
        return .result()
    }
}

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Antrenmana başla"
    static let description = IntentDescription("Forma'yı açar ve bugünün antrenmanını başlatır.")
    static let openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.routeHandler?("workout/start")
        return .result()
    }
}

#if os(iOS)
/// Live Activity: sıradaki seti tamamla. Uygulama sürecinde çalışır.
struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Seti tamamla"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.send(.setCompleted(id: UUID(), date: Date(), exerciseIndex: -1, setIndex: -1, weightKg: 0, reps: 0))
        return .result()
    }
}

struct AdjustRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Dinlenmeyi değiştir"
    static let isDiscoverable = false

    @Parameter(title: "Saniye")
    var seconds: Int

    init() {}
    init(seconds: Int) { self.seconds = seconds }

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.send(.restAdjust(id: UUID(), date: Date(), seconds: seconds))
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Dinlenmeyi atla"
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.send(.skipRest(id: UUID(), date: Date()))
        return .result()
    }
}
#endif
