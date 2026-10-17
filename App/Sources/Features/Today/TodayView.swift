import SwiftUI
import FormaKit

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Binding var tab: AppTab
    @Binding var showWorkout: Bool
    @State private var showWater = false
    @State private var showSupplements = false
    @State private var showRecovery = false
    @State private var showCoach = false
    @State private var showReadiness = false
    @State private var showLevel = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if model.isRamadan { RamadanCard() }
                    DayTargetsCard(onWater: { showWater = true })
                    SupplementShelf(onManage: { showSupplements = true })
                    WaterQuickCard(onMore: { showWater = true })
                    workoutCard
                    if model.shouldSuggestAutoPlan { autoPlanBanner }
                    ReadinessCard(onTap: { showReadiness = true })
                    recoveryCard
                    CoachPreviewCard(onTap: { showCoach = true })
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(alignment: .top) {
                RadialGradient(colors: [Theme.lime.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
                    .frame(height: 420)
                    .ignoresSafeArea()
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWater) { WaterSheet().presentationDetents([.medium, .large]).presentationBackground(Theme.background) }
            .sheet(isPresented: $showSupplements) { NavigationStack { SupplementsView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showRecovery) { NavigationStack { RecoveryView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showCoach) { NavigationStack { CoachView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showReadiness) { ReadinessSheet().presentationDetents([.medium, .large]).presentationBackground(Theme.background) }
            .sheet(isPresented: $showLevel) { NavigationStack { AchievementsView() }.presentationBackground(Theme.background) }
        }
    }

    // MARK: Başlık

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Fmt.weekdayDayMonth.string(from: model.now)).eyebrow()
                Text(greeting).formaFont(.display).lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            Button { showLevel = true } label: {
                ZStack {
                    RingView(progress: model.level.progress, color: Theme.gold, lineWidth: 4)
                    VStack(spacing: -2) {
                        Text("SV").font(.forma(.micro)).foregroundStyle(Theme.textTertiary)
                        Text("\(model.level.level)").formaFont(.numberS)
                    }
                }
                .frame(width: 50, height: 50)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Seviye \(model.level.level), \(model.level.title)")
        }
        .padding(.top, 12)
    }

    private var greeting: String {
        let hour = Calendar.forma.component(.hour, from: model.now)
        let name = model.profile.name.split(separator: " ").first.map(String.init) ?? ""
        let hello: String
        switch hour {
        case 5..<11: hello = "Günaydın"
        case 11..<17: hello = "İyi günler"
        case 17..<22: hello = "İyi akşamlar"
        default: hello = "İyi geceler"
        }
        return name.isEmpty ? hello : "\(hello), \(name)"
    }

    // MARK: Antrenman kartı

    @ViewBuilder private var workoutCard: some View {
        if let active = model.activeWorkout {
            Button { showWorkout = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Antrenman sürüyor").eyebrow(Theme.onLime.opacity(0.7))
                        Text(active.title).font(.forma(.title)).foregroundStyle(Theme.onLime)
                        Text("\(active.completedSetCount) set tamamlandı").formaFont(.callout, Theme.onLime.opacity(0.75))
                    }
                    Spacer()
                    Image(systemName: "play.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.lime)
                        .frame(width: 56, height: 56).background(Theme.onLime, in: Circle())
                }
                .padding(18)
                .background(Theme.lime, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            }
            .buttonStyle(PressableStyle())
        } else if model.trainedToday, let s = model.todaySessions.first {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 30)).foregroundStyle(Theme.lime)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bugünün antrenmanı tamam").formaFont(.headline)
                    Text("\(s.title) · \(Fmt.minutes(s.duration)) · \(Fmt.int(s.totalVolume)) kg hacim")
                        .formaFont(.caption, Theme.textSecondary)
                    Text("Kaslar dinlenirken büyür. Proteinini ve uykunu ihmal etme.").formaFont(.caption, Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
        } else {
            let plan = model.nextPlan
            let isRestDay = !model.plannedTrainingToday
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isRestDay ? "Sıradaki antrenman" : "Bugünün antrenmanı").eyebrow(Theme.onLime.opacity(0.7))
                        Text(plan.title).font(.forma(.title)).foregroundStyle(Theme.onLime)
                        Text("\(plan.slots.count) hareket · yaklaşık \(plan.minutes) dk").formaFont(.callout, Theme.onLime.opacity(0.75))
                    }
                    Spacer()
                    if !plan.focus.isEmpty {
                        Text(model.settings.planMode.isAuto ? "Otomatik" : "Program")
                            .font(.forma(.micro)).tracking(1).textCase(.uppercase)
                            .foregroundStyle(Theme.lime)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Theme.onLime, in: Capsule())
                    }
                }
                if !plan.focus.isEmpty {
                    Text(plan.focus).formaFont(.bodyMedium, Theme.onLime)
                }
                if let reason = plan.rationale.first {
                    Text(reason).formaFont(.caption, Theme.onLime.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
                }
                if isRestDay {
                    Text("Bugün dinlenme günü olarak önerilir; istersen yine de başlayabilirsin.")
                        .formaFont(.caption, Theme.onLime.opacity(0.7))
                }
                HStack {
                    Button {
                        model.startWorkout(plan)
                        showWorkout = true
                    } label: {
                        Label("Başla", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Theme.onLime, foreground: Theme.lime, compact: true))
                    .accessibilityIdentifier("today.startWorkout")
                    Spacer()
                    Button("Detay") { tab = .workout }
                        .font(.forma(.callout))
                        .foregroundStyle(Theme.onLime)
                }
            }
            .padding(18)
            .background(Theme.lime, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
    }

    private var autoPlanBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars").foregroundStyle(Theme.supplement)
                Text("Otomatik plana geçmeye hazırsın").formaFont(.bodyMedium)
            }
            Text("Başlangıç programında iyi bir temel oluşturdun. Otomatik plan her gün toparlanmış kaslarına ve haftalık set hedeflerine göre antrenman kurar.")
                .formaFont(.caption, Theme.textSecondary)
            HStack {
                Button("Geç") { model.choosePlan(.auto) }.buttonStyle(PrimaryButtonStyle(compact: true))
                Button("Şimdilik kalsın") { model.updateSettings { $0.hasSeenAutoPlanSuggestion = true } }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
            }
        }
        .cardStyle(background: Theme.supplement.opacity(0.12))
    }

    // MARK: Toparlanma

    private var recoveryCard: some View {
        Button { showRecovery = true } label: {
            HStack(spacing: 16) {
                MuscleMapView(side: .front, mode: .recovery, compact: true)
                    .frame(width: 70, height: 140)
                MuscleMapView(side: .back, mode: .recovery, compact: true)
                    .frame(width: 70, height: 140)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kas toparlanması").formaFont(.headline)
                    let ready = model.recovery.filter { $0.muscle.isLarge && $0.status == .ready }.map(\.muscle.displayName)
                    let tired = model.recovery.filter { $0.status == .fatigued }.map(\.muscle.displayName)
                    if tired.isEmpty {
                        Text("Tüm kaslar hazır görünüyor.").formaFont(.caption, Theme.textSecondary)
                    } else {
                        Text("Dinleniyor: \(tired.prefix(3).joined(separator: ", "))").formaFont(.caption, Theme.energy)
                    }
                    if !ready.isEmpty {
                        Text("Hazır: \(ready.prefix(3).joined(separator: ", "))").formaFont(.caption, Theme.lime)
                    }
                    HStack(spacing: 4) {
                        Text("Haritayı aç").formaFont(.callout, Theme.textPrimary)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Günlük hedefler

struct DayTargetsCard: View {
    @Environment(AppModel.self) private var model
    var onWater: () -> Void

    var body: some View {
        let t = model.targets
        let m = model.todayMacros
        let water = model.todayWaterMl
        let parts = [min(1, m.protein / max(1, t.proteinG)), min(1, water / max(1, t.waterMl)), min(1, m.kcal / max(1, t.kcal))]
        let overall = parts.reduce(0, +) / Double(parts.count)

        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    RingView(progress: m.kcal / max(1, t.kcal), color: Theme.energy, lineWidth: 9)
                    RingView(progress: water / max(1, t.waterMl), color: Theme.water, lineWidth: 9)
                        .padding(13)
                    RingView(progress: m.protein / max(1, t.proteinG), color: Theme.lime, lineWidth: 9)
                        .padding(26)
                    Text("%\(Int((overall * 100).rounded()))").formaFont(.numberS)
                }
                .frame(width: 118, height: 118)
                .accessibilityElement()
                .accessibilityLabel("Günlük hedeflerin yüzde \(Int(overall * 100)) tamamlandı")

                VStack(alignment: .leading, spacing: 12) {
                    legendRow(color: Theme.lime, label: "Protein", value: "\(Fmt.int(m.protein))", target: "\(Fmt.int(t.proteinG)) g")
                    Button(action: onWater) {
                        legendRow(color: Theme.water, label: "Su", value: Fmt.liters(water), target: "\(Fmt.liters(t.waterMl)) L")
                    }
                    .buttonStyle(.plain)
                    legendRow(color: Theme.energy, label: "Kalori", value: Fmt.int(m.kcal), target: Fmt.int(t.kcal))
                }
            }
            HStack(spacing: 10) {
                miniMacro("Karb.", m.carbs, t.carbsG, Theme.energy)
                miniMacro("Yağ", m.fat, t.fatG, Theme.water)
                miniMacro("Lif", m.fiber, t.fiberG, Theme.supplement)
                if model.todayCaffeineMg > 0 {
                    miniMacro("Kafein", model.todayCaffeineMg, SupplementEngine.dailyCaffeineLimitMg, Theme.coral, unit: "mg")
                }
            }
        }
        .cardStyle(padding: 18)
    }

    private func legendRow(color: Color, label: String, value: String, target: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).eyebrow()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).formaFont(.numberM).monospacedDigit().contentTransition(.numericText())
                Text("/ \(target)").formaFont(.caption, Theme.textTertiary)
            }
        }
    }

    private func miniMacro(_ label: String, _ v: Double, _ target: Double, _ color: Color, unit: String = "g") -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(label).formaFont(.caption, Theme.textSecondary)
                Spacer(minLength: 2)
                Text("\(Fmt.int(v))").formaFont(.callout)
            }
            BarView(progress: target > 0 ? v / target : 0, color: color, height: 5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Takviye rafı

struct SupplementShelf: View {
    @Environment(AppModel.self) private var model
    var onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Takviye rafı").formaFont(.headline)
                if model.creatineStreak > 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").font(.system(size: 11))
                        Text("\(model.creatineStreak) gün").font(.forma(.label))
                    }
                    .foregroundStyle(Theme.energy)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.energy.opacity(0.14), in: Capsule())
                }
                Spacer()
                Button("Düzenle", action: onManage).font(.forma(.callout)).foregroundStyle(Theme.lime)
            }
            if model.todaysSupplements.isEmpty {
                Button(action: onManage) {
                    Label("Kreatin, protein tozu veya vitamin ekle", systemImage: "plus.circle.fill")
                        .formaFont(.callout, Theme.textSecondary)
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(model.todaysSupplements) { s in
                            SupplementBottle(supplement: s)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .cardStyle()
    }
}

struct SupplementBottle: View {
    @Environment(AppModel.self) private var model
    var supplement: Supplement

    var body: some View {
        let done = model.isDone(supplement)
        let due = !done && isDue
        Button {
            model.toggle(supplement)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: supplement.kind.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(done ? Theme.onLime : Theme.supplement)
                        .frame(width: 32, height: 32)
                        .background(done ? Theme.lime : Theme.supplement.opacity(0.16), in: Circle())
                    Spacer()
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(done ? Theme.lime : Theme.textTertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(supplement.name).formaFont(.bodyMedium).lineLimit(1)
                    Text(done ? "Alındı" : (due ? "Şimdi" : supplement.doseLabel))
                        .formaFont(.caption, done ? Theme.lime : (due ? Theme.supplement : Theme.textSecondary))
                }
            }
            .padding(12)
            .frame(width: 132)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(due ? Theme.supplement : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: due ? Theme.supplement.opacity(0.35) : .clear, radius: 10)
            .opacity(done ? 0.85 : 1)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: done)
        .accessibilityLabel("\(supplement.name), \(done ? "alındı" : "alınmadı")")
        .accessibilityIdentifier("supp.\(supplement.kind.rawValue)")
    }

    private var isDue: Bool {
        let cal = Calendar.forma
        let minutes = cal.component(.hour, from: model.now) * 60 + cal.component(.minute, from: model.now)
        return supplement.reminderTimes.contains { $0.minutesOfDay <= minutes }
    }
}

// MARK: - Hızlı su

struct WaterQuickCard: View {
    @Environment(AppModel.self) private var model
    var onMore: () -> Void

    var body: some View {
        let target = model.targets.waterMl
        let ml = model.todayWaterMl
        let glasses = 8
        let filled = Int((ml / max(1, target) * Double(glasses)).rounded(.down))
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Su").formaFont(.headline)
                Spacer()
                Text(Fmt.liters(ml)).formaFont(.numberM, Theme.water).contentTransition(.numericText())
                Text("/ \(Fmt.liters(target)) L").formaFont(.caption, Theme.textTertiary)
            }
            HStack(spacing: 6) {
                ForEach(0..<glasses, id: \.self) { i in
                    GlassShape()
                        .fill(i < filled ? Theme.water : Theme.surfaceHigh)
                        .frame(height: 30)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(i) * 0.03), value: filled)
                }
            }
            HStack(spacing: 8) {
                ForEach([200, 330, 500], id: \.self) { amount in
                    Button {
                        model.logWater(ml: Double(amount))
                    } label: {
                        Text("+\(amount)")
                            .font(.forma(.callout))
                            .foregroundStyle(amount == 330 ? Theme.background : Theme.water)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(amount == 330 ? Theme.water : Theme.water.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityIdentifier("water.add\(amount)")
                }
                IconButton(systemName: "ellipsis", size: 40, tint: Theme.water, background: Theme.water.opacity(0.14), action: onMore)
            }
        }
        .cardStyle(background: Theme.surface)
    }
}

/// Aşağı doğru daralan bardak.
struct GlassShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset = rect.width * 0.14
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - 3))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - inset - 3, y: rect.maxY), control: CGPoint(x: rect.maxX - inset, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + inset + 3, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + inset, y: rect.maxY - 3), control: CGPoint(x: rect.minX + inset, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Hazır olma

struct ReadinessCard: View {
    @Environment(AppModel.self) private var model
    var onTap: () -> Void

    var body: some View {
        let feeling = model.data.feelings[model.todayKey]
        Button(action: onTap) {
            HStack(spacing: 14) {
                if let r = model.readiness {
                    ZStack {
                        RingView(progress: Double(r.score) / 100, color: color(for: r.level), lineWidth: 7)
                        Text("\(r.score)").formaFont(.numberS)
                    }
                    .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hazır olma · \(r.level.displayName)").formaFont(.bodyMedium)
                        Text(r.advice).formaFont(.caption, Theme.textSecondary).multilineTextAlignment(.leading)
                    }
                } else {
                    Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 26)).foregroundStyle(Theme.textTertiary)
                    Text("Bugün nasıl hissediyorsun?").formaFont(.bodyMedium)
                }
                Spacer(minLength: 0)
                if feeling == nil {
                    Text("Söyle").font(.forma(.callout)).foregroundStyle(Theme.lime)
                }
            }
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
    }

    private func color(for level: ReadinessEngine.Result.Level) -> Color {
        switch level {
        case .high: return Theme.lime
        case .normal: return Theme.amber
        case .low: return Theme.energy
        }
    }
}

struct ReadinessSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let feelings: [(String, String)] = [("Çok kötü", "battery.0percent"), ("Yorgun", "battery.25percent"),
                                                ("İdare eder", "battery.50percent"), ("İyi", "battery.75percent"), ("Harika", "battery.100percent.bolt")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Bugün nasılsın?").formaFont(.title).padding(.top, 20)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { i in
                        let selected = model.data.feelings[model.todayKey] == i
                        Button {
                            model.setFeeling(i)
                            Haptics.selection()
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: feelings[i - 1].1).font(.system(size: 20))
                                Text(feelings[i - 1].0).font(.forma(.micro)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .foregroundStyle(selected ? Theme.onLime : Theme.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .background(selected ? Theme.lime : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                if let r = model.readiness {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Hazır olma skoru").formaFont(.headline)
                            Spacer()
                            Text("\(r.score)").formaFont(.numberL)
                        }
                        ForEach(r.components) { c in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(c.name).formaFont(.callout)
                                    Spacer()
                                    Text(c.detail).formaFont(.caption, Theme.textSecondary)
                                }
                                BarView(progress: c.score / 100, color: Theme.recoveryColor(c.score), height: 6)
                            }
                        }
                        Text(r.advice).formaFont(.caption, Theme.textSecondary)
                    }
                    .cardStyle()
                }
                Text("Apple Watch takıyorsan uyku, HRV ve dinlenik nabız kendi 30 günlük ortalamanla karşılaştırılır. Bu bir öneridir, tıbbi değerlendirme değildir.")
                    .formaFont(.caption, Theme.textTertiary)
            }
            .padding(.horizontal, Theme.gutter)
        }
    }
}

// MARK: - Koç önizleme

struct CoachPreviewCard: View {
    @Environment(AppModel.self) private var model
    var onTap: () -> Void

    var body: some View {
        let insights = CoachService.weeklyInsights(model: model).filter { $0.tone != .neutral }.prefix(2)
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(Theme.gold)
                    Text("Haftalık koç").formaFont(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textTertiary)
                }
                ForEach(Array(insights)) { i in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: i.symbol).font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(i.tone == .good ? Theme.lime : Theme.energy)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(i.title).formaFont(.callout)
                            Text(i.detail).formaFont(.caption, Theme.textSecondary).multilineTextAlignment(.leading).lineLimit(2)
                        }
                    }
                }
            }
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Ramazan

struct RamadanCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let times = RamadanCalculator.times(on: model.now, settings: model.settings.ramadan) {
            let beforeIftar = model.now < times.iftar && model.now > times.imsak
            let target = beforeIftar ? times.iftar : (model.now < times.imsak ? times.imsak : (RamadanCalculator.times(on: model.now.addingTimeInterval(86_400), settings: model.settings.ramadan)?.imsak ?? times.imsak))
            HStack(spacing: 14) {
                Image(systemName: beforeIftar ? "sunset.fill" : "moon.stars.fill").font(.system(size: 24)).foregroundStyle(Theme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text(beforeIftar ? "İftara" : "İmsaka").eyebrow()
                    Text(target, style: .timer).formaFont(.numberM).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("İmsak \(Fmt.time.string(from: times.imsak))").formaFont(.caption, Theme.textSecondary)
                    Text("İftar \(Fmt.time.string(from: times.iftar))").formaFont(.caption, Theme.textSecondary)
                    let w = RamadanCalculator.suggestedTrainingWindow(times: times)
                    Text("Antrenman \(Fmt.time.string(from: w.start))").formaFont(.caption, Theme.lime)
                }
            }
            .cardStyle(background: Theme.gold.opacity(0.10))
        }
    }
}
