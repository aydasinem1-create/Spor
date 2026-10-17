import Foundation
import UserNotifications
import FormaKit

/// Yerel bildirimler: su, takviye, antrenman, dinlenme bitişi, antrenman sonrası protein, akşam özeti.
/// Tekrarlayan bildirimler yerine her açılışta önümüzdeki 3 günü yeniden planlarız; böylece
/// "zaten aldıysan hatırlatma" gibi akıllı kurallar uygulanabilir.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    weak var model: AppModel?

    enum Category {
        static let supplement = "SUPPLEMENT"
        static let water = "WATER"
        static let rest = "REST"
        static let workout = "WORKOUT"
    }

    enum Action {
        static let take = "TAKE"
        static let water250 = "WATER_250"
        static let water500 = "WATER_500"
        static let start = "START"
    }

    enum Prefix {
        static let water = "water."
        static let supplement = "supp."
        static let workout = "workout."
        static let summary = "summary."
        static let post = "post."
        static let rest = "rest.end"
    }

    func configure(model: AppModel) {
        self.model = model
        center.delegate = self
        let take = UNNotificationAction(identifier: Action.take, title: "Aldım ✓", options: [])
        let w250 = UNNotificationAction(identifier: Action.water250, title: "+250 ml", options: [])
        let w500 = UNNotificationAction(identifier: Action.water500, title: "+500 ml", options: [])
        let start = UNNotificationAction(identifier: Action.start, title: "Başla", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.supplement, actions: [take], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.water, actions: [w250, w500], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.workout, actions: [start], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.rest, actions: [], intentIdentifiers: [])
        ])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: Planlama

    func reschedule(model: AppModel) {
        rescheduleWater(model: model)
        rescheduleSupplements(model: model)
        rescheduleWorkout(model: model)
        rescheduleSummary(model: model)
    }

    private func removePending(prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func add(id: String, title: String, body: String, at date: Date, category: String? = nil,
                     userInfo: [String: String] = [:], timeSensitive: Bool = false) {
        guard date > Date().addingTimeInterval(5) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category { content.categoryIdentifier = category }
        content.userInfo = userInfo
        if timeSensitive { content.interruptionLevel = .timeSensitive }
        let comps = Calendar.forma.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func date(dayOffset: Int, minutes: Int) -> Date {
        let cal = Calendar.forma
        let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: Date()))!
        return day.addingTimeInterval(TimeInterval(minutes * 60))
    }

    func rescheduleWater(model: AppModel) {
        let settings = model.settings.reminders
        let target = model.targets.waterMl
        let drank = model.todayWaterMl
        let ramadan = model.settings.ramadan
        Task {
            await removePending(prefix: Prefix.water)
            guard settings.waterEnabled else { return }
            for offset in 0..<3 {
                var slots: [Int] = []
                if ramadan.enabled, let times = RamadanCalculator.times(on: date(dayOffset: offset, minutes: 720), settings: ramadan) {
                    // İftardan sonra 45 dk'da bir, imsaktan önce son hatırlatma
                    let cal = Calendar.forma
                    let iftarMin = cal.component(.hour, from: times.iftar) * 60 + cal.component(.minute, from: times.iftar)
                    var m = iftarMin + 30
                    while m < min(iftarMin + 300, 24 * 60 - 30) { slots.append(m); m += 60 }
                    let imsakMin = cal.component(.hour, from: times.imsak) * 60 + cal.component(.minute, from: times.imsak)
                    slots.append(max(0, imsakMin - 40))
                } else {
                    var m = settings.waterStartHour * 60
                    while m <= settings.waterEndHour * 60 {
                        slots.append(m)
                        m += max(30, settings.waterIntervalMinutes)
                    }
                }
                for (i, minutes) in slots.enumerated() {
                    let when = date(dayOffset: offset, minutes: minutes)
                    if offset == 0 {
                        // Bugün, o saate kadar beklenen miktarın gerisinde değilsen hatırlatma
                        let startM = Double(settings.waterStartHour * 60), endM = Double(settings.waterEndHour * 60)
                        let expected = target * ((Double(minutes) - startM) / max(60, endM - startM)).clamped(0...1)
                        if drank >= target || (!ramadan.enabled && drank >= expected + 250) { continue }
                    }
                    let remaining = offset == 0 ? max(0, target - drank) : target
                    add(id: "\(Prefix.water)\(offset).\(i)", title: "Su molası 💧",
                        body: offset == 0 ? "Hedefe \(Fmt.liters(remaining)) L kaldı. Bir bardak iç." : "Bir bardak su iç, günü hedefinde bitir.",
                        at: when, category: Category.water)
                }
            }
        }
    }

    func rescheduleSupplements(model: AppModel) {
        let enabled = model.settings.reminders.supplementsEnabled
        let ramadan = model.settings.ramadan
        let items: [(Supplement, Bool)] = model.activeSupplements.map { ($0, model.isDone($0)) }
        Task {
            await removePending(prefix: Prefix.supplement)
            guard enabled else { return }
            for (s, doneToday) in items {
                var times = s.reminderTimes
                if ramadan.enabled, s.kind == .creatine, let t = RamadanCalculator.times(on: Date(), settings: ramadan) {
                    let cal = Calendar.forma
                    times = [ReminderTime(cal.component(.hour, from: t.iftar), cal.component(.minute, from: t.iftar))]
                }
                for offset in 0..<3 {
                    if offset == 0 && doneToday { continue }
                    for (i, time) in times.enumerated() {
                        add(id: "\(Prefix.supplement)\(s.id.uuidString).\(offset).\(i)",
                            title: "\(s.name) zamanı",
                            body: s.kind == .creatine ? "\(s.doseLabel) kreatin. Her gün almak, ne zaman aldığından daha önemli."
                                                      : "\(s.doseLabel) \(s.name.lowercased(with: Locale(identifier: "tr_TR")))",
                            at: date(dayOffset: offset, minutes: time.minutesOfDay),
                            category: Category.supplement, userInfo: ["supplementID": s.id.uuidString])
                    }
                }
            }
        }
    }

    func rescheduleWorkout(model: AppModel) {
        let r = model.settings.reminders
        let planned = model.plannedTrainingToday
        let title = model.nextPlan.title
        let ramadan = model.settings.ramadan
        Task {
            await removePending(prefix: Prefix.workout)
            guard r.workoutDayEnabled else { return }
            var minutes = r.workoutReminderHour * 60 + r.workoutReminderMinute
            if ramadan.enabled, let t = RamadanCalculator.times(on: Date(), settings: ramadan) {
                let w = RamadanCalculator.suggestedTrainingWindow(times: t)
                let cal = Calendar.forma
                minutes = cal.component(.hour, from: w.start) * 60 + cal.component(.minute, from: w.start) - 15
            }
            if planned {
                add(id: "\(Prefix.workout)0", title: "Bugün antrenman günü 💪", body: "\(title) seni bekliyor.",
                    at: date(dayOffset: 0, minutes: minutes), category: Category.workout)
            }
        }
    }

    func rescheduleSummary(model: AppModel) {
        let r = model.settings.reminders
        let protein = model.todayMacros.protein, pTarget = model.targets.proteinG
        let water = model.todayWaterMl, wTarget = model.targets.waterMl
        let creatineOK = model.creatine == nil || model.creatineTakenToday
        Task {
            await removePending(prefix: Prefix.summary)
            guard r.eveningSummaryEnabled else { return }
            var missing: [String] = []
            if protein < pTarget * 0.85 { missing.append("\(Fmt.int(pTarget - protein)) g protein") }
            if water < wTarget * 0.85 { missing.append("\(Fmt.liters(wTarget - water)) L su") }
            if !creatineOK { missing.append("kreatin") }
            guard !missing.isEmpty else { return }
            add(id: "\(Prefix.summary)0", title: "Gün bitmeden",
                body: "Eksikler: " + missing.joined(separator: ", ") + ".",
                at: date(dayOffset: 0, minutes: r.eveningSummaryHour * 60))
        }
    }

    func schedulePostWorkout(model: AppModel) {
        guard model.settings.reminders.postWorkoutProteinEnabled else { return }
        let remaining = model.targets.proteinG - model.todayMacros.protein
        guard remaining > 15 else { return }
        let per = NutritionEngine.perMealProtein(weightKg: model.latestWeight)
        add(id: "\(Prefix.post)0", title: "Antrenman sonrası",
            body: "Protein hedefine \(Fmt.int(remaining)) g kaldı. \(Fmt.int(per)) g'lık bir öğün iyi gider.",
            at: Date().addingTimeInterval(30 * 60))
    }

    func scheduleRestEnd(at date: Date, enabled: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: [Prefix.rest])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Dinlenme bitti"
        content.body = "Sıradaki sete geç."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Category.rest
        let interval = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: Prefix.rest, content: content, trigger: trigger))
    }

    func cancelRestEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [Prefix.rest])
        center.removeDeliveredNotifications(withIdentifiers: [Prefix.rest])
    }

    // MARK: Delege

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Uygulama açıkken dinlenme bildirimi gösterme (ekrandaki sayaç yeterli)
        if notification.request.identifier == Prefix.rest { return [] }
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier
        let suppID = info["supplementID"] as? String
        await MainActor.run {
            guard let model = self.model else { return }
            switch action {
            case Action.take:
                if let id = suppID.flatMap(UUID.init(uuidString:)), let s = model.supplement(id), !model.isDone(s) { model.take(s) }
            case Action.water250:
                model.logWater(ml: 250)
            case Action.water500:
                model.logWater(ml: 500)
            case Action.start:
                model.pendingRoute = .startWorkout
            default:
                if category == Category.water { model.pendingRoute = .water }
                if category == Category.workout { model.pendingRoute = .startWorkout }
            }
        }
    }
}
