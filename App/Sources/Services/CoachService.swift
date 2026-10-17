import Foundation
import FormaKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Haftalık koç özeti. Kurallarla üretilir; cihazda Apple Intelligence varsa metin daha doğal hale getirilir.
/// Hiçbir veri telefondan çıkmaz.
@MainActor
enum CoachService {

    struct Insight: Identifiable, Equatable {
        enum Tone { case good, neutral, attention }
        let id = UUID()
        var symbol: String
        var title: String
        var detail: String
        var tone: Tone
    }

    static func weeklyInsights(model: AppModel) -> [Insight] {
        var out: [Insight] = []
        let cal = Calendar.forma
        let now = model.now
        let weekStart = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let prevStart = cal.date(byAdding: .day, value: -14, to: now) ?? now
        let sessions = model.finishedSessions
        let thisWeek = sessions.filter { $0.startedAt >= weekStart }
        let lastWeek = sessions.filter { $0.startedAt >= prevStart && $0.startedAt < weekStart }
        let target = model.profile.trainingDaysPerWeek

        // Antrenman sayısı
        if thisWeek.count >= target {
            out.append(Insight(symbol: "checkmark.seal.fill", title: "\(thisWeek.count)/\(target) antrenman",
                               detail: "Haftalık hedefini tutturdun. Süreklilik, en iyi programdan daha önemli.", tone: .good))
        } else {
            out.append(Insight(symbol: "calendar.badge.exclamationmark", title: "\(thisWeek.count)/\(target) antrenman",
                               detail: "Son 7 günde hedefin altındasın. Kısa bir seans bile seriyi korur.", tone: .attention))
        }

        // Hacim değişimi
        let vNow = thisWeek.reduce(0) { $0 + $1.totalVolume }
        let vPrev = lastWeek.reduce(0) { $0 + $1.totalVolume }
        if vPrev > 0 && vNow > 0 {
            let change = (vNow - vPrev) / vPrev * 100
            out.append(Insight(symbol: change >= 0 ? "arrow.up.right" : "arrow.down.right",
                               title: "Toplam hacim \(change >= 0 ? "+" : "")\(Int(change.rounded()))%",
                               detail: "Bu hafta \(Fmt.int(vNow)) kg kaldırdın.", tone: change >= -10 ? .good : .neutral))
        }

        // Rekorlar
        let prs = model.data.records.filter { $0.date >= weekStart }
        if !prs.isEmpty {
            let names = Set(prs.compactMap { model.exercise($0.exerciseID)?.name }).prefix(3).joined(separator: ", ")
            out.append(Insight(symbol: "trophy.fill", title: "\(prs.count) yeni rekor", detail: names, tone: .good))
        }

        // Geride kalan kaslar
        let lagging = model.weeklyVolume.filter { $0.muscle.isLarge && $0.status == .below && $0.sets < $0.target.lowerBound * 0.5 }
        if !lagging.isEmpty {
            out.append(Insight(symbol: "figure.strengthtraining.traditional", title: "Az çalışılan bölgeler",
                               detail: lagging.prefix(3).map(\.muscle.displayName).joined(separator: ", ") + " bu hafta hedefin yarısının altında.",
                               tone: .attention))
        }

        // Beslenme
        var proteinDays = 0, waterDays = 0, loggedDays = 0
        let t = model.baseTargets
        for i in 1...7 {
            guard let day = cal.date(byAdding: .day, value: -i, to: now) else { continue }
            let m = model.macros(on: day)
            if m.kcal > 0 { loggedDays += 1 }
            if m.protein >= t.proteinG * 0.9 { proteinDays += 1 }
            if model.waterMl(on: day) >= t.waterMl * 0.9 { waterDays += 1 }
        }
        if loggedDays >= 3 {
            out.append(Insight(symbol: "fork.knife", title: "Protein hedefi: 7 günde \(proteinDays) gün",
                               detail: proteinDays >= 5 ? "Kas gelişimi için çok iyi gidiyorsun." : "Her öğüne bir protein kaynağı eklemek en kolay çözüm.",
                               tone: proteinDays >= 5 ? .good : .attention))
        } else {
            out.append(Insight(symbol: "square.and.pencil", title: "Beslenme kaydı az",
                               detail: "Hedeflerin doğru ayarlanması için haftada en az 4–5 gün kayıt önerilir.", tone: .neutral))
        }
        out.append(Insight(symbol: "drop.fill", title: "Su hedefi: 7 günde \(waterDays) gün",
                           detail: waterDays >= 5 ? "Sıvı dengen iyi." : "Antrenman günleri ekstra 500 ml'yi unutma.",
                           tone: waterDays >= 5 ? .good : .attention))

        // Kilo
        if let rate = WeightTrend.weeklyRate(model.weightPoints, now: now) {
            let pct = rate / model.latestWeight * 100
            let goal = model.profile.goal
            var detail = "Haftalık değişim \(rate >= 0 ? "+" : "")\(Fmt.oneDecimal(rate)) kg (%\(Fmt.oneDecimal(abs(pct))))."
            var tone: Insight.Tone = .neutral
            switch goal {
            case .loseFat:
                if pct <= -0.3 && pct >= -1.1 { detail += " Sağlıklı bir hızda yağ kaybediyorsun."; tone = .good }
                else if pct < -1.1 { detail += " Çok hızlı; kas kaybını önlemek için kaloriyi biraz artır."; tone = .attention }
                else { detail += " Kilo pek değişmiyor; kayıtlar doğruysa hedef kaloriyi ~150 kcal azalt."; tone = .attention }
            case .buildMuscle:
                if pct >= 0.1 && pct <= 0.5 { detail += " Kas kazanımı için ideal aralık."; tone = .good }
                else if pct > 0.5 { detail += " Biraz hızlı; gereksiz yağ artışı olabilir."; tone = .attention }
                else { detail += " Kilo artmıyor; günlük ~150 kcal ekle."; tone = .attention }
            default:
                break
            }
            out.append(Insight(symbol: "scalemass.fill", title: "Kilo trendi", detail: detail, tone: tone))
        }

        // Kreatin
        if let c = model.creatine {
            let days = (0..<7).filter { i in
                guard let d = cal.date(byAdding: .day, value: -i, to: now) else { return false }
                return model.data.supplementLogs.contains { $0.supplementID == c.id && cal.isDate($0.date, inSameDayAs: d) }
            }.count
            out.append(Insight(symbol: "bolt.fill", title: "Kreatin: 7 günde \(days) gün",
                               detail: "Tahmini kas doygunluğu %\(Int(model.creatineSaturation)).", tone: days >= 6 ? .good : .attention))
        }
        return out
    }

    static func ruleBasedSummary(_ insights: [Insight]) -> String {
        let good = insights.filter { $0.tone == .good }.map(\.title)
        let attention = insights.filter { $0.tone == .attention }
        var parts: [String] = []
        if !good.isEmpty { parts.append("Bu hafta iyi gidenler: \(good.joined(separator: ", ").lowercased(with: Locale(identifier: "tr_TR"))).") }
        if let first = attention.first { parts.append("Öncelik: \(first.detail)") }
        if parts.isEmpty { parts.append("Kayıt ekledikçe sana özel öneriler burada görünecek.") }
        return parts.joined(separator: " ")
    }

    /// Apple Intelligence varsa özeti doğal bir dille yeniden yazar; yoksa kural tabanlı metni döndürür.
    static func summary(insights: [Insight]) async -> String {
        let base = ruleBasedSummary(insights)
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let polished = await polish(insights: insights) { return polished }
        }
        #endif
        return base
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func polish(insights: [Insight]) async -> String? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let facts = insights.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n")
        let session = LanguageModelSession(instructions: """
            Sen bir spor koçusun. Kullanıcıya Türkçe, samimi ve kısa yazıyorsun. \
            Sadece verilen bilgileri kullan, sayı uydurma, tıbbi tavsiye verme. En fazla 3 cümle.
            """)
        do {
            let response = try await session.respond(to: "Bu haftanın özeti:\n\(facts)\nKullanıcıya kısa bir haftalık değerlendirme yaz.")
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
    #endif
}
