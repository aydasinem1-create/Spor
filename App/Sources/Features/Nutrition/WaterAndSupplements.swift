import SwiftUI
import FormaKit

// MARK: - Su

struct WaterSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var beverage: Beverage = .water
    @State private var amount: Double = 250

    var body: some View {
        let target = model.targets.waterMl
        let ml = model.todayWaterMl
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    ZStack {
                        WaterBottle(progress: ml / max(1, target))
                            .frame(width: 92, height: 150)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bugün").eyebrow()
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Fmt.liters(ml)).formaFont(.numberXL, Theme.water).contentTransition(.numericText())
                            Text("/ \(Fmt.liters(target)) L").formaFont(.body, Theme.textSecondary)
                        }
                        Text(ml >= target ? "Hedef tamam 🎉" : "\(Fmt.int(max(0, target - ml))) ml kaldı").formaFont(.callout, Theme.textSecondary)
                        if model.trainedToday || model.plannedTrainingToday {
                            Text("Antrenman günü: hedefe ekstra sıvı eklendi.").formaFont(.caption, Theme.lime)
                        }
                    }
                }
                .padding(.top, 20)

                Text("Ne içtin?").eyebrow()
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Beverage.allCases) { b in
                            Chip(title: b.displayName, systemImage: b.symbol, isOn: beverage == b) {
                                beverage = b
                                amount = b.typicalML
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)

                NumberStepper(title: "Miktar", value: $amount, step: beverage.typicalML < 100 ? 10 : 50, range: 10...2000, unit: "ml", format: { Fmt.int($0) })
                    .cardStyle()
                if beverage.caffeinePer100ml > 0 {
                    let mg = amount * beverage.caffeinePer100ml / 100
                    Label("~\(Fmt.int(mg)) mg kafein · bugün toplam \(Fmt.int(model.todayCaffeineMg + mg)) / 400 mg", systemImage: "bolt.heart.fill")
                        .formaFont(.caption, model.todayCaffeineMg + mg > 400 ? Theme.coral : Theme.textSecondary)
                }
                Button("Ekle") {
                    model.logWater(ml: amount, beverage: beverage)
                }
                .buttonStyle(PrimaryButtonStyle(color: Theme.water, foreground: Theme.background))
                .accessibilityIdentifier("water.addCustom")

                if !model.todayWaterLogs.isEmpty {
                    Text("Bugünkü kayıtlar").eyebrow().padding(.top, 6)
                    VStack(spacing: 0) {
                        ForEach(model.todayWaterLogs.reversed()) { log in
                            HStack {
                                Image(systemName: log.beverage.symbol).foregroundStyle(Theme.water).frame(width: 24)
                                Text(log.beverage.displayName).formaFont(.callout)
                                Spacer()
                                Text("\(Fmt.int(log.ml)) ml").formaFont(.callout, Theme.textSecondary)
                                Text(Fmt.time.string(from: log.date)).formaFont(.caption, Theme.textTertiary).frame(width: 46, alignment: .trailing)
                                Button { model.deleteWater(log.id) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 6)
                            }
                            .padding(.vertical, 10)
                            Divider().overlay(Theme.hairline)
                        }
                    }
                    .cardStyle(padding: 12)
                }
                Text("Çay ve kahve de sıvı ihtiyacına sayılır; ılımlı kafein vücudun su dengesini bozmaz. Antrenmanda vücut ağırlığının %2'sinden fazla sıvı kaybetmemeye çalış.")
                    .formaFont(.caption, Theme.textTertiary)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, Theme.gutter)
        }
    }
}

struct WaterBottle: View {
    var progress: Double

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.surface)
                TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    WaveShape(level: min(1, max(0, progress)), phase: t * 2.2, amplitude: progress > 0 && progress < 1 ? 4 : 0)
                        .fill(LinearGradient(colors: [Theme.water, Color(hex: 0x2F7FD0)], startPoint: .top, endPoint: .bottom))
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.water.opacity(0.35), lineWidth: 2)
                Text("%\(Int(min(999, progress * 100)))").formaFont(.numberS).padding(.bottom, h * 0.08)
            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress)
    }
}

struct WaveShape: Shape {
    var level: Double
    var phase: Double
    var amplitude: CGFloat

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.height * (1 - level)
        p.move(to: CGPoint(x: 0, y: y))
        let steps = 24
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let dy = sin(Double(i) / Double(steps) * .pi * 2 + phase) * amplitude
            p.addLine(to: CGPoint(x: x, y: y + dy))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Takviyeler

struct SupplementsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var editing: Supplement?
    @State private var showCreatineInfo = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let c = model.creatine {
                    creatineCard(c)
                }
                Text("Bugün").eyebrow()
                ForEach(model.activeSupplements) { s in
                    HStack(spacing: 12) {
                        Image(systemName: s.kind.symbol).foregroundStyle(Theme.supplement)
                            .frame(width: 38, height: 38).background(Theme.supplement.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).formaFont(.bodyMedium)
                            Text(subtitle(s)).formaFont(.caption, Theme.textSecondary)
                        }
                        Spacer()
                        Button { model.toggle(s) } label: {
                            Image(systemName: model.isDone(s) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 26))
                                .foregroundStyle(model.isDone(s) ? Theme.lime : Theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .cardStyle(padding: 12)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = s }
                }
                Button {
                    editing = Supplement(kind: .other, dose: 1)
                } label: {
                    Label("Takviye ekle", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())

                let inactive = model.data.supplements.filter { !$0.isActive }
                if !inactive.isEmpty {
                    Text("Kullanmadıkların").eyebrow().padding(.top, 8)
                    ForEach(inactive) { s in
                        Button { editing = s } label: {
                            HStack { Text(s.name).formaFont(.callout, Theme.textSecondary); Spacer() }
                                .cardStyle(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Takviyeler dengeli beslenmenin yerini tutmaz. Kronik hastalığın varsa, ilaç kullanıyorsan veya hamileysen doktoruna danış.")
                    .formaFont(.caption, Theme.textTertiary)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Takviyeler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
        .sheet(item: $editing) { s in
            NavigationStack { SupplementEditor(supplement: s) }.presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showCreatineInfo) {
            NavigationStack { ArticleView(article: LearnLibrary.article("creatine")!) }.presentationBackground(Theme.background)
        }
    }

    private func subtitle(_ s: Supplement) -> String {
        var parts = [s.doseLabel]
        if !s.reminderTimes.isEmpty { parts.append(s.reminderTimes.map(\.label).joined(separator: ", ")) }
        if s.onlyTrainingDays { parts.append("antrenman günleri") }
        if s.proteinPerDose > 0 { parts.append("\(Fmt.int(s.proteinPerDose)) g protein") }
        return parts.joined(separator: " · ")
    }

    private func creatineCard(_ c: Supplement) -> some View {
        let saturation = model.creatineSaturation
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Kreatin").formaFont(.headline)
                Spacer()
                Button { showCreatineInfo = true } label: { Image(systemName: "info.circle").foregroundStyle(Theme.textSecondary) }
            }
            HStack(spacing: 18) {
                ZStack {
                    RingView(progress: saturation / 100, color: Theme.supplement, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text("%\(Int(saturation))").formaFont(.numberM)
                        Text("doygunluk").font(.forma(.micro)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundStyle(Theme.energy)
                        Text("\(model.creatineStreak) gün seri").formaFont(.bodyMedium)
                    }
                    Text(saturationText(saturation)).formaFont(.caption, Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            CreatineCalendar(supplementID: c.id)
            Text("Doygunluk tahmini, kayıtlarına dayanan basit bir modeldir; kas ölçümü değildir.").formaFont(.caption, Theme.textTertiary)
        }
        .cardStyle()
    }

    private func saturationText(_ s: Double) -> String {
        switch s {
        case 90...: return "Kasların büyük ihtimalle doygun. Günlük dozla koru."
        case 50..<90: return "Doluyor. Günde 3–5 g ile 3–4 haftada tam doygunluğa ulaşılır."
        default: return "Başlangıç aşaması. Etkisi düzenli kullanımla birkaç hafta içinde ortaya çıkar."
        }
    }
}

struct CreatineCalendar: View {
    @Environment(AppModel.self) private var model
    var supplementID: UUID

    var body: some View {
        let cal = Calendar.forma
        let days = (0..<28).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: model.now) }
        let taken = Set(model.data.supplementLogs.filter { $0.supplementID == supplementID }.map { DayKey.key($0.date) })
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 14), spacing: 5) {
            ForEach(days, id: \.self) { d in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(taken.contains(DayKey.key(d)) ? Theme.supplement : Theme.surfaceHigh)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(cal.isDateInToday(d) ? RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.textPrimary, lineWidth: 1) : nil)
            }
        }
    }
}

struct SupplementEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var supplement: Supplement
    @State private var newTime = Date()

    var body: some View {
        Form {
            Section("Takviye") {
                Picker("Tür", selection: $supplement.kind) {
                    ForEach(SupplementKind.allCases) { k in Label(k.displayName, systemImage: k.symbol).tag(k) }
                }
                .onChange(of: supplement.kind) { _, k in
                    if supplement.name.isEmpty || SupplementKind.allCases.map(\.displayName).contains(supplement.name) { supplement.name = k.displayName }
                    supplement.unit = k.defaultUnit
                    if k == .creatine { supplement.dose = SupplementEngine.creatineMaintenanceDose(weightKg: model.latestWeight) }
                }
                TextField("Ad", text: $supplement.name)
                HStack {
                    Text("Doz")
                    Spacer()
                    TextField("Doz", value: $supplement.dose, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    TextField("birim", text: $supplement.unit).frame(width: 60)
                }
                Stepper("Günde \(supplement.timesPerDay) kez", value: $supplement.timesPerDay, in: 1...4)
                Toggle("Sadece antrenman günleri", isOn: $supplement.onlyTrainingDays)
                Toggle("Kullanıyorum", isOn: $supplement.isActive)
            }
            if supplement.kind == .whey || supplement.kind == .casein {
                Section("Doz başına protein") {
                    Stepper("\(Int(supplement.proteinPerDose)) g", value: $supplement.proteinPerDose, in: 0...80, step: 1)
                }
            }
            if supplement.kind == .caffeine {
                Section {
                    Stepper("\(Int(supplement.caffeinePerDose)) mg", value: $supplement.caffeinePerDose, in: 0...400, step: 10)
                } header: {
                    Text("Doz başına kafein")
                } footer: {
                    let r = SupplementEngine.caffeinePerformanceRange(weightKg: model.latestWeight)
                    Text("Performans için genellikle \(Int(r.lowerBound))–\(Int(r.upperBound)) mg (3–6 mg/kg), antrenmandan ~60 dk önce. Uykunu bozmaması için \(String(format: "%02d:00", SupplementEngine.caffeineCutoff(bedtimeHour: model.settings.bedtimeHour)))'dan sonra alma.")
                }
            }
            Section("Hatırlatma saatleri") {
                ForEach(Array(supplement.reminderTimes.enumerated()), id: \.offset) { i, t in
                    HStack {
                        Text(t.label)
                        Spacer()
                        Button(role: .destructive) { supplement.reminderTimes.remove(at: i) } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(Theme.coral)
                    }
                }
                HStack {
                    DatePicker("Yeni", selection: $newTime, displayedComponents: .hourAndMinute)
                    Button("Ekle") {
                        let c = Calendar.forma.dateComponents([.hour, .minute], from: newTime)
                        supplement.reminderTimes.append(ReminderTime(c.hour ?? 9, c.minute ?? 0))
                        supplement.reminderTimes.sort { $0.minutesOfDay < $1.minutesOfDay }
                    }
                }
            }
            if model.data.supplements.contains(where: { $0.id == supplement.id }) {
                Section {
                    Button("Takviyeyi sil", role: .destructive) {
                        model.deleteSupplement(supplement)
                        dismiss()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(supplement.name.isEmpty ? "Takviye" : supplement.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Kaydet") {
                    model.saveSupplement(supplement)
                    dismiss()
                }
                .foregroundStyle(Theme.lime)
                .disabled(supplement.name.trimmingCharacters(in: .whitespaces).isEmpty || supplement.dose <= 0)
            }
        }
    }
}
