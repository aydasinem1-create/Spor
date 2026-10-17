import SwiftUI
import UniformTypeIdentifiers
import FormaKit

struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var showEdit = false
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var confirmReset = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "Profil", title: model.profile.name.isEmpty ? "Sen" : model.profile.name)
                    summaryCard
                    group("Antrenman") {
                        link("Salonum ve ekipman", "dumbbell.fill", Theme.lime) { GymSettingsView() }
                        link("Plan ve program", "list.bullet.rectangle.fill", Theme.lime) { ProgramPickerView() }
                        link("Odak bölgeleri", "scope", Theme.lime) { FocusMusclesView() }
                    }
                    group("Beslenme") {
                        link("Günlük hedefler", "target", Theme.energy) { TargetsView() }
                        link("Takviyeler", "pills.fill", Theme.supplement) { SupplementsView() }
                    }
                    group("Uygulama") {
                        link("Hatırlatmalar", "bell.badge.fill", Theme.coral) { RemindersView() }
                        link("Ramazan modu", "moon.stars.fill", Theme.gold) { RamadanSettingsView() }
                        link("Apple Sağlık", "heart.fill", Theme.coral) { HealthSettingsView() }
                        link("Bilgi köşesi", "book.fill", Theme.water) { LearnView() }
                    }
                    group("Veri") {
                        Button {
                            exportURL = try? model.storage.exportData(model.data)
                        } label: { rowLabel("Yedeği dışa aktar", "square.and.arrow.up", Theme.water) }
                        Button { showImporter = true } label: { rowLabel("Yedekten geri yükle", "square.and.arrow.down", Theme.water) }
                        Button { confirmReset = true } label: { rowLabel("Tüm verileri sil", "trash", Theme.coral) }
                    }
                    about
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEdit) { NavigationStack { EditProfileView() }.presentationBackground(Theme.background) }
            .sheet(item: Binding(get: { exportURL.map { ShareItem(url: $0) } }, set: { exportURL = $0?.url })) { item in
                ShareSheet(items: [item.url])
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try model.storage.importData(from: url)
                    model.replaceAllData(data)
                } catch {
                    importError = "Dosya okunamadı. Forma'dan alınmış bir yedek olduğundan emin ol."
                }
            }
            .alert("Geri yükleme başarısız", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("Tamam", role: .cancel) {}
            } message: { Text(importError ?? "") }
            .confirmationDialog("Tüm verilerin silinsin mi?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Her şeyi sil", role: .destructive) { model.resetAllData() }
            } message: {
                Text("Antrenmanlar, öğünler, ölçüler ve ayarlar kalıcı olarak silinir. Önce yedek almak isteyebilirsin.")
            }
        }
    }

    private var summaryCard: some View {
        let p = model.profile
        return Button { showEdit = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Text(String(p.name.prefix(1)).uppercased())
                        .font(.custom("SpaceGrotesk-Bold", size: 26))
                        .foregroundStyle(Theme.onLime)
                        .frame(width: 58, height: 58)
                        .background(Theme.lime, in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.goal.displayName).formaFont(.bodyMedium)
                        Text("\(p.experience.displayName) · haftada \(p.trainingDaysPerWeek) gün").formaFont(.caption, Theme.textSecondary)
                    }
                    Spacer()
                    Text("Düzenle").font(.forma(.callout)).foregroundStyle(Theme.lime)
                }
                HStack(spacing: 10) {
                    mini("Kilo", Fmt.oneDecimal(model.latestWeight), "kg")
                    mini("Boy", "\(Int(p.heightCm))", "cm")
                    mini("Yaş", "\(p.age())", "")
                    mini("Seri", "\(model.weeklyWorkoutStreak)", "hf")
                }
            }
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
    }

    private func mini(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).eyebrow()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).formaFont(.numberS)
                Text(unit).formaFont(.caption, Theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).eyebrow().padding(.leading, 4).padding(.bottom, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        }
        .padding(.top, 4)
    }

    private func link<Destination: View>(_ title: String, _ symbol: String, _ color: Color, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            rowLabel(title, symbol, color)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(_ title: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                .frame(width: 32, height: 32).background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title).formaFont(.body)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Forma 1.0").formaFont(.caption, Theme.textSecondary)
            Text("Verilerin yalnızca bu cihazda saklanır. Hareket görselleri free-exercise-db (Unlicense), barkod verisi Open Food Facts (ODbL), yazı tipleri Space Grotesk ve DM Sans (OFL).")
                .formaFont(.caption, Theme.textTertiary)
            Text("Forma tıbbi bir uygulama değildir; öneriler genel bilgilendirme amaçlıdır.")
                .formaFont(.caption, Theme.textTertiary)
        }
        .padding(.top, 10)
    }
}

struct ShareItem: Identifiable {
    var url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Profil düzenleme

struct EditProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var p = UserProfile()

    var body: some View {
        Form {
            Section("Kişisel") {
                TextField("Ad", text: $p.name)
                Picker("Cinsiyet", selection: $p.sex) { ForEach(Sex.allCases) { Text($0.displayName).tag($0) } }
                Stepper("Doğum yılı: \(String(p.birthYear))", value: $p.birthYear, in: 1940...2014)
                Stepper("Boy: \(Int(p.heightCm)) cm", value: $p.heightCm, in: 130...220, step: 1)
                Stepper("Kilo: \(Fmt.oneDecimal(p.weightKg)) kg", value: $p.weightKg, in: 35...250, step: 0.5)
            }
            Section("Hedef") {
                Picker("Hedef", selection: $p.goal) { ForEach(Goal.allCases) { Text($0.displayName).tag($0) } }
                Picker("Deneyim", selection: $p.experience) { ForEach(Experience.allCases) { Text($0.displayName).tag($0) } }
                Picker("Gün içi hareket", selection: $p.activityLevel) { ForEach(ActivityLevel.allCases) { Text($0.displayName).tag($0) } }
            }
            Section("Antrenman") {
                Stepper("Haftada \(p.trainingDaysPerWeek) gün", value: $p.trainingDaysPerWeek, in: 1...7)
                Stepper("Seans \(p.sessionMinutes) dk", value: $p.sessionMinutes, in: 20...150, step: 5)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Vazgeç") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Kaydet") {
                    let old = model.profile.weightKg
                    let edited = p
                    model.updateProfile { $0 = edited }
                    if abs(old - edited.weightKg) > 0.05 { model.addMeasurement(BodyMeasurement(date: Date(), weightKg: edited.weightKg)) }
                    dismiss()
                }
                .foregroundStyle(Theme.lime)
            }
        }
        .onAppear { p = model.profile; p.weightKg = (model.latestWeight * 2).rounded() / 2 }
    }
}

// MARK: - Salon

struct GymSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var equipment: Set<Equipment> = []
    @State private var gym = GymSettings()

    var body: some View {
        Form {
            Section {
                ForEach(Equipment.allCases) { e in
                    Toggle(isOn: Binding(get: { equipment.contains(e) }, set: { on in if on { equipment.insert(e) } else { equipment.remove(e) } })) {
                        Label(e.displayName, systemImage: e.symbol)
                    }
                }
            } header: {
                Text("Erişebildiğin ekipman")
            } footer: {
                Text("Programdaki hareketler bu listeye göre seçilir; olmayan ekipman için alternatif hareket kullanılır.")
            }
            Section("Ağırlıklar") {
                Stepper("Bar: \(Fmt.kg(gym.barWeightKg)) kg", value: $gym.barWeightKg, in: 5...25, step: 2.5)
                Stepper("Dambıl artışı: \(Fmt.kg(gym.dumbbellStepKg)) kg", value: $gym.dumbbellStepKg, in: 0.5...5, step: 0.5)
                Stepper("Makine artışı: \(Fmt.kg(gym.machineStepKg)) kg", value: $gym.machineStepKg, in: 1...10, step: 0.5)
            }
            Section("Plakalar (her taraf)") {
                ForEach([25.0, 20, 15, 10, 5, 2.5, 1.25, 0.5], id: \.self) { plate in
                    Toggle("\(Fmt.kg(plate)) kg", isOn: Binding(get: { gym.plates.contains(plate) },
                                                                set: { on in
                                                                    if on { gym.plates.append(plate) } else { gym.plates.removeAll { $0 == plate } }
                                                                    gym.plates.sort(by: >)
                                                                }))
                }
            }
            Section("Antrenman sırasında") {
                Stepper("Varsayılan dinlenme: \(gym.defaultRestSeconds) sn", value: $gym.defaultRestSeconds, in: 30...300, step: 15)
                Toggle("Isınma setlerini öner", isOn: $gym.showWarmups)
                Toggle("Dinlenme bitince bildirim", isOn: $gym.restTimerSound)
                Toggle("Dinlenme bitince titreşim", isOn: $gym.restTimerHaptics)
            }
        }
        .tint(Theme.lime)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Salonum")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            equipment = model.profile.equipment
            gym = model.settings.gym
        }
        .onDisappear {
            let eq = equipment, g = gym
            model.updateProfile { $0.equipment = eq }
            model.updateSettings { $0.gym = g }
        }
    }
}

struct FocusMusclesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Seçtiğin kaslara haftada ~4 set fazla verilir (en fazla 3 bölge). Bölgesel yağ yakmak mümkün değildir; bu seçim kas gelişimi içindir.")
                    .formaFont(.caption, Theme.textSecondary)
                HStack(spacing: 8) {
                    MuscleMapView(side: .front, mode: .selection(model.profile.focusMuscles)) { toggle($0) }
                    MuscleMapView(side: .back, mode: .selection(model.profile.focusMuscles)) { toggle($0) }
                }
                .frame(height: 340)
                .cardStyle()
                FlowLayout(spacing: 8) {
                    ForEach(MuscleGroup.allCases) { m in
                        Chip(title: m.displayName, isOn: model.profile.focusMuscles.contains(m)) { toggle(m) }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Odak bölgeleri")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ m: MuscleGroup) {
        model.updateProfile { p in
            if p.focusMuscles.contains(m) { p.focusMuscles.remove(m) } else if p.focusMuscles.count < 3 { p.focusMuscles.insert(m) }
        }
    }
}

// MARK: - Hatırlatmalar

struct RemindersView: View {
    @Environment(AppModel.self) private var model
    @State private var r = ReminderSettings()
    @State private var bedtime = 23
    @State private var hot = false

    var body: some View {
        Form {
            Section("Su") {
                Toggle("Su hatırlatmaları", isOn: $r.waterEnabled)
                if r.waterEnabled {
                    Stepper("Başlangıç \(String(format: "%02d:00", r.waterStartHour))", value: $r.waterStartHour, in: 5...14)
                    Stepper("Bitiş \(String(format: "%02d:00", r.waterEndHour))", value: $r.waterEndHour, in: 15...23)
                    Stepper("Her \(r.waterIntervalMinutes) dk", value: $r.waterIntervalMinutes, in: 45...240, step: 15)
                    Toggle("Sıcak hava (hedefe +500 ml)", isOn: $hot)
                }
            }
            Section {
                Toggle("Takviye hatırlatmaları", isOn: $r.supplementsEnabled)
                Toggle("Antrenman sonrası protein", isOn: $r.postWorkoutProteinEnabled)
            } header: { Text("Takviye ve beslenme") } footer: { Text("Takviyeyi aldıysan o günün hatırlatması kendiliğinden iptal olur.") }
            Section("Antrenman") {
                Toggle("Antrenman günü hatırlatması", isOn: $r.workoutDayEnabled)
                if r.workoutDayEnabled {
                    Stepper("Saat \(String(format: "%02d:%02d", r.workoutReminderHour, r.workoutReminderMinute))",
                            value: Binding(get: { r.workoutReminderHour * 60 + r.workoutReminderMinute },
                                           set: { r.workoutReminderHour = $0 / 60; r.workoutReminderMinute = $0 % 60 }),
                            in: 300...1380, step: 30)
                }
            }
            Section {
                Toggle("Akşam eksikler özeti", isOn: $r.eveningSummaryEnabled)
                if r.eveningSummaryEnabled {
                    Stepper("Saat \(String(format: "%02d:00", r.eveningSummaryHour))", value: $r.eveningSummaryHour, in: 17...23)
                }
                Stepper("Yatış saati \(String(format: "%02d:00", bedtime))", value: $bedtime, in: 20...26)
            } header: { Text("Gün sonu") } footer: { Text("Yatış saati, kafein uyarısı için kullanılır.") }
        }
        .tint(Theme.lime)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Hatırlatmalar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            r = model.settings.reminders
            bedtime = model.settings.bedtimeHour
            hot = model.settings.hotWeather
            Task { _ = await NotificationService.shared.requestAuthorization() }
        }
        .onDisappear {
            let rr = r, b = bedtime % 24, h = hot
            model.updateSettings { s in
                s.reminders = rr
                s.bedtimeHour = b
                s.hotWeather = h
            }
        }
    }
}

// MARK: - Ramazan

struct RamadanSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var s = RamadanSettings()
    @State private var locating = false
    @State private var iftar = Date()
    @State private var imsak = Date()

    var body: some View {
        Form {
            Section {
                Toggle("Ramazan modu", isOn: $s.enabled)
            } footer: {
                Text("Öğünler sahur/iftar olur; su ve kreatin hatırlatmaları iftar–imsak arasına taşınır; ağır antrenman iftardan sonraya önerilir.")
            }
            if s.enabled {
                Section {
                    Button {
                        locating = true
                        LocationOnce.shared.request { coordinate in
                            locating = false
                            if let c = coordinate {
                                s.latitude = c.latitude
                                s.longitude = c.longitude
                            }
                        }
                    } label: {
                        HStack {
                            Label(s.latitude == nil ? "Konumuma göre hesapla" : "Konumu güncelle", systemImage: "location.fill")
                            if locating { Spacer(); ProgressView() }
                        }
                    }
                    if let t = RamadanCalculator.times(on: Date(), settings: s) {
                        LabeledContent("Bugün imsak", value: Fmt.time.string(from: t.imsak))
                        LabeledContent("Bugün iftar", value: Fmt.time.string(from: t.iftar))
                    }
                } header: { Text("Vakitler") } footer: {
                    Text("Vakitler güneşin konumuna göre hesaplanır (imsak: güneş ufkun 18° altında). Diyanet takvimiyle birkaç dakika fark olursa aşağıdan düzelt.")
                }
                Section("İnce ayar") {
                    Stepper("İftar \(s.iftarOffsetMinutes >= 0 ? "+" : "")\(s.iftarOffsetMinutes) dk", value: $s.iftarOffsetMinutes, in: -20...20)
                    Stepper("İmsak \(s.imsakOffsetMinutes >= 0 ? "+" : "")\(s.imsakOffsetMinutes) dk", value: $s.imsakOffsetMinutes, in: -20...20)
                }
                if s.latitude == nil {
                    Section("Konum yoksa elle gir") {
                        DatePicker("İmsak", selection: $imsak, displayedComponents: .hourAndMinute)
                        DatePicker("İftar", selection: $iftar, displayedComponents: .hourAndMinute)
                    }
                }
                Section {
                    NavigationLink("Ramazan'da spor rehberi") { ArticleView(article: LearnLibrary.article("ramadan")!) }
                }
            }
        }
        .tint(Theme.lime)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Ramazan modu")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            s = model.settings.ramadan
            let start = Calendar.forma.startOfDay(for: Date())
            imsak = start.addingTimeInterval(Double(s.manualImsakMinutes ?? 330) * 60)
            iftar = start.addingTimeInterval(Double(s.manualIftarMinutes ?? 1110) * 60)
        }
        .onChange(of: imsak) { _, d in s.manualImsakMinutes = minutes(d) }
        .onChange(of: iftar) { _, d in s.manualIftarMinutes = minutes(d) }
        .onDisappear {
            let value = s
            model.updateSettings { $0.ramadan = value }
        }
    }

    private func minutes(_ d: Date) -> Int {
        let c = Calendar.forma.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

// MARK: - Sağlık

struct HealthSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                if HealthService.shared.isAvailable {
                    Toggle("Apple Sağlık bağlantısı", isOn: Binding(get: { model.settings.healthKitEnabled }, set: { on in
                        if on {
                            busy = true
                            Task {
                                let ok = await HealthService.shared.requestAuthorization()
                                model.updateSettings { $0.healthKitEnabled = ok }
                                await HealthService.shared.refresh(into: model)
                                busy = false
                            }
                        } else {
                            model.updateSettings { $0.healthKitEnabled = false }
                        }
                    }))
                    .disabled(busy)
                } else {
                    Text("Bu cihazda Apple Sağlık kullanılamıyor.")
                }
            } footer: {
                Text("Okunanlar: kilo, uyku, HRV, dinlenik nabız, adım, diğer antrenmanlar. Yazılanlar: su, besin, kilo ve antrenmanlar. İzinleri Ayarlar > Sağlık > Veri Erişimi'nden değiştirebilirsin.")
            }
            if model.settings.healthKitEnabled {
                Section("Son okunan") {
                    LabeledContent("Uyku", value: model.health.sleepHours.map { "\(Fmt.oneDecimal($0)) sa" } ?? "–")
                    LabeledContent("HRV", value: model.health.hrv.map { "\(Int($0)) ms" } ?? "–")
                    LabeledContent("Dinlenik nabız", value: model.health.restingHR.map { "\(Int($0)) bpm" } ?? "–")
                    LabeledContent("Adım", value: model.health.steps.map { Fmt.int($0) } ?? "–")
                    Button("Şimdi yenile") { Task { await HealthService.shared.refresh(into: model) } }
                }
            }
            Section {
                Toggle("Kayıtlarımdan harcamamı hesapla", isOn: Binding(get: { model.settings.useAdaptiveExpenditure },
                                                                         set: { v in model.updateSettings { $0.useAdaptiveExpenditure = v } }))
            } footer: {
                Text("En az 2 hafta düzenli kilo ve beslenme kaydı olduğunda kalori hedefin gerçek harcamana göre ayarlanır.")
            }
        }
        .tint(Theme.lime)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Apple Sağlık")
        .navigationBarTitleDisplayMode(.inline)
    }
}
