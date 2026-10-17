import SwiftUI
import FormaKit

struct OnboardingView: View {
    @Environment(AppModel.self) private var model

    @State private var step = 0
    @State private var profile = UserProfile(name: "", sex: .male, birthYear: 2000, heightCm: 175, weightKg: 75)
    @State private var gymPreset = 0
    @State private var useAutoPlan = false
    @State private var takesCreatine = true
    @State private var creatineHour = 9
    @State private var takesWhey = true
    @State private var settings = AppSettings()
    @State private var notificationsAsked = false
    @State private var healthAsked = false

    private let stepCount = 10

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 {
                header
            }
            ZStack {
                content
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            footer
        }
        .screenBackground()
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconButton(systemName: "chevron.left", size: 36) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { step -= 1 }
            }
            BarView(progress: Double(step) / Double(stepCount - 1), color: Theme.lime, height: 6)
            Text("\(step)/\(stepCount - 1)").formaFont(.caption, Theme.textTertiary).monospacedDigit()
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: welcome
        case 1: aboutYou
        case 2: body_
        case 3: goal
        case 4: experience
        case 5: activity
        case 6: equipment
        case 7: focus
        case 8: plan
        default: finish
        }
    }

    private var canContinue: Bool {
        switch step {
        case 1: return !profile.name.trimmingCharacters(in: .whitespaces).isEmpty
        case 6: return !profile.equipment.isEmpty
        default: return true
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                if step >= stepCount - 1 {
                    finishOnboarding()
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step += 1 }
                    Haptics.tap()
                }
            } label: {
                Text(step == 0 ? "Hadi başlayalım" : (step >= stepCount - 1 ? "Forma'ya gir" : "Devam"))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.4)
            .accessibilityIdentifier("onboarding.next")
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 12)
    }

    // MARK: Adımlar

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(RadialGradient(colors: [Theme.lime.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 220))
                    .frame(width: 440, height: 440)
                    .offset(x: 120, y: -40)
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.lime)
                            .frame(width: 44, height: 44)
                            .overlay(Text("F").font(.custom("SpaceGrotesk-Bold", size: 28)).foregroundStyle(Theme.onLime))
                        Text("forma").font(.custom("SpaceGrotesk-Bold", size: 30)).foregroundStyle(Theme.textPrimary)
                    }
                    Text("Antrenman, beslenme, su ve kreatin.\nHepsi tek yerde.")
                        .font(.custom("SpaceGrotesk-Bold", size: 38, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Birkaç soruyla hedeflerini, programını ve günlük planını senin için hazırlayalım.")
                        .formaFont(.body, Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 14) {
                featureRow("figure.strengthtraining.traditional", "Hangi hareket, kaç set, kaç kilo", Theme.lime)
                featureRow("flame.fill", "Kas toparlanma haritası", Theme.energy)
                featureRow("fork.knife", "Türk mutfağıyla protein ve kalori", Theme.lime)
                featureRow("drop.fill", "Su ve kreatin hatırlatmaları", Theme.water)
            }
            .padding(.top, 28)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func featureRow(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
                .frame(width: 34, height: 34).background(color.opacity(0.14), in: Circle())
            Text(text).formaFont(.bodyMedium)
        }
    }

    private func stepTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).formaFont(.display).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).formaFont(.body, Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private var aboutYou: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                stepTitle("Seni tanıyalım", "Hedeflerini hesaplamak için birkaç temel bilgi.")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adın").eyebrow()
                    TextField("", text: $profile.name, prompt: Text("Adın").foregroundStyle(Theme.textTertiary))
                        .font(.forma(.headline))
                        .foregroundStyle(Theme.textPrimary)
                        .textInputAutocapitalization(.words)
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityIdentifier("onboarding.name")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cinsiyet").eyebrow()
                    HStack(spacing: 10) {
                        ForEach(Sex.allCases) { s in
                            Chip(title: s.displayName, isOn: profile.sex == s) { profile.sex = s }
                        }
                    }
                    Text("Bazal metabolizma hesabı için gerekiyor.").formaFont(.caption, Theme.textTertiary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Doğum yılı").eyebrow()
                    Picker("Doğum yılı", selection: $profile.birthYear) {
                        ForEach((1950...2012).reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var body_: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle("Boy ve kilo", "Kilonu daha sonra tartıldıkça güncelleyeceğiz.")
            VStack(spacing: 16) {
                bigValue("Boy", value: "\(Int(profile.heightCm))", unit: "cm")
                Slider(value: $profile.heightCm, in: 140...215, step: 1).tint(Theme.lime)
            }
            .cardStyle()
            VStack(spacing: 16) {
                bigValue("Kilo", value: Fmt.oneDecimal(profile.weightKg), unit: "kg")
                Slider(value: $profile.weightKg, in: 40...180, step: 0.5).tint(Theme.lime)
                HStack {
                    IconButton(systemName: "minus") { profile.weightKg = max(40, profile.weightKg - 0.1) }
                    Spacer()
                    let h = profile.heightCm / 100
                    Text("VKİ \(Fmt.oneDecimal(profile.weightKg / (h * h)))").formaFont(.caption, Theme.textSecondary)
                    Spacer()
                    IconButton(systemName: "plus") { profile.weightKg = min(180, profile.weightKg + 0.1) }
                }
            }
            .cardStyle()
        }
        .padding(.horizontal, Theme.gutter)
    }

    private func bigValue(_ label: String, value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).eyebrow()
            Spacer()
            Text(value).formaFont(.numberL).monospacedDigit().contentTransition(.numericText())
            Text(unit).formaFont(.body, Theme.textSecondary)
        }
    }

    private func optionCard(title: String, subtitle: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onLime : Theme.lime)
                    .frame(width: 44, height: 44)
                    .background(selected ? Theme.lime : Theme.lime.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).formaFont(.bodyMedium)
                    Text(subtitle).formaFont(.caption, Theme.textSecondary).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Theme.lime : Theme.textTertiary)
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(selected ? Theme.lime : Color.white.opacity(0.04), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var goal: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                stepTitle("Hedefin ne?", "Kalori, protein ve antrenman ayarları buna göre şekillenir.")
                ForEach(Goal.allCases) { g in
                    optionCard(title: g.displayName, subtitle: g.subtitle, symbol: g.symbol, selected: profile.goal == g) { profile.goal = g }
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private var experience: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepTitle("Deneyim ve zaman", "Yeni başlayanlar için haftada 2–3 gün en verimli başlangıçtır.")
                VStack(spacing: 10) {
                    ForEach(Experience.allCases) { e in
                        optionCard(title: e.displayName, subtitle: experienceDetail(e), symbol: "chart.bar.fill", selected: profile.experience == e) {
                            profile.experience = e
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Haftada kaç gün?").eyebrow()
                    HStack(spacing: 8) {
                        ForEach(2...6, id: \.self) { d in
                            Button {
                                profile.trainingDaysPerWeek = d
                                Haptics.selection()
                            } label: {
                                Text("\(d)")
                                    .formaFont(.numberM, profile.trainingDaysPerWeek == d ? Theme.onLime : Theme.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 54)
                                    .background(profile.trainingDaysPerWeek == d ? Theme.lime : Theme.surface,
                                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    Text("Antrenman süresi").eyebrow().padding(.top, 6)
                    HStack(spacing: 8) {
                        ForEach([30, 45, 60, 75, 90], id: \.self) { m in
                            Chip(title: "\(m) dk", isOn: profile.sessionMinutes == m) { profile.sessionMinutes = m }
                        }
                    }
                }
                .cardStyle()
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private func experienceDetail(_ e: Experience) -> String {
        switch e {
        case .beginner: return "Makineler ve temel hareketlerle güvenli başlangıç"
        case .intermediate: return "Temel hareketleri biliyorum, düzenli çalışıyorum"
        case .advanced: return "Programlı çalışıyorum, daha fazla hacim istiyorum"
        }
    }

    private var activity: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                stepTitle("Gün içi hareketin", "Antrenman dışındaki hareketin günlük kalori ihtiyacını belirler.")
                ForEach(ActivityLevel.allCases) { a in
                    optionCard(title: a.displayName, subtitle: a.detail, symbol: "figure.walk", selected: profile.activityLevel == a) {
                        profile.activityLevel = a
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private var equipment: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                stepTitle("Nerede çalışıyorsun?", "Program sadece erişebildiğin ekipmanlarla kurulur.")
                optionCard(title: "Tam donanımlı salon", subtitle: "Makineler, kablolar, bar ve dambıllar", symbol: "building.2.fill",
                           selected: gymPreset == 0) { gymPreset = 0; profile.equipment = Equipment.fullGym }
                optionCard(title: "Evde dambılla", subtitle: "Dambıl, sehpa ve vücut ağırlığı", symbol: "house.fill",
                           selected: gymPreset == 1) { gymPreset = 1; profile.equipment = Equipment.homeDumbbells }
                optionCard(title: "Kendim seçeyim", subtitle: "Salonumdaki ekipmanları işaretlerim", symbol: "slider.horizontal.3",
                           selected: gymPreset == 2) { gymPreset = 2 }
                if gymPreset == 2 {
                    FlowLayout(spacing: 8) {
                        ForEach(Equipment.allCases) { e in
                            Chip(title: e.displayName, isOn: profile.equipment.contains(e)) {
                                if profile.equipment.contains(e) { profile.equipment.remove(e) } else { profile.equipment.insert(e) }
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private var focus: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepTitle("Öne çıkarmak istediğin bölgeler", "İsteğe bağlı. Seçtiğin kaslar haftada birkaç set fazla çalışılır.")
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundStyle(Theme.water)
                    Text("Bölgesel kas geliştirmek mümkündür, ama bölgesel yağ yakmak mümkün değildir: 13 çalışmayı inceleyen bir analizde belirli bir bölgeyi çalıştırmak o bölgedeki yağı azaltmadı. Yağ kaybı kalori açığıyla tüm vücutta olur.")
                        .formaFont(.caption, Theme.textSecondary)
                }
                .cardStyle(padding: 14, background: Theme.waterDeep.opacity(0.5))
                FlowLayout(spacing: 8) {
                    ForEach([MuscleGroup.chest, .lats, .upperBack, .sideDelts, .rearDelts, .biceps, .triceps, .abs, .glutes, .quads, .hamstrings, .calves]) { m in
                        Chip(title: m.displayName, isOn: profile.focusMuscles.contains(m)) {
                            if profile.focusMuscles.contains(m) { profile.focusMuscles.remove(m) } else if profile.focusMuscles.count < 3 { profile.focusMuscles.insert(m) }
                        }
                    }
                }
                Text("En fazla 3 bölge seçebilirsin.").formaFont(.caption, Theme.textTertiary)
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private var recommendedProgram: WorkoutProgram { ProgramLibrary.recommended(for: profile) }

    private var plan: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                stepTitle("Planın", "Önce hazır bir programla hareketleri öğren. Birkaç hafta sonra toparlanmana göre kendini ayarlayan otomatik plana geçebilirsin.")
                optionCard(title: recommendedProgram.name, subtitle: recommendedProgram.summary, symbol: "list.bullet.rectangle.fill",
                           selected: !useAutoPlan) { useAutoPlan = false }
                optionCard(title: "Otomatik plan", subtitle: "Her gün toparlanmış kaslarına ve haftalık set hedeflerine göre antrenman kurulur.",
                           symbol: "wand.and.stars", selected: useAutoPlan) { useAutoPlan = true }
                if !useAutoPlan {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(recommendedProgram.days) { day in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(day.name).formaFont(.bodyMedium)
                                Text(day.slots.compactMap { $0.resolvedExercise(equipment: profile.equipment)?.name }.joined(separator: " · "))
                                    .formaFont(.caption, Theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private var computedTargets: DailyTargets {
        NutritionEngine.targets(profile: profile, settings: settings)
    }

    private var finish: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepTitle("Günlük hedeflerin", "Bilimsel önerilere göre hesaplandı. İstediğin zaman değiştirebilirsin.")
                let t = computedTargets
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(label: "Kalori", value: Fmt.int(t.kcal), unit: "kcal", color: Theme.energy, symbol: "flame.fill")
                    StatTile(label: "Protein", value: Fmt.int(t.proteinG), unit: "g", color: Theme.lime, symbol: "fork.knife")
                    StatTile(label: "Su", value: Fmt.liters(t.waterMl), unit: "L", color: Theme.water, symbol: "drop.fill")
                    StatTile(label: "Kreatin", value: Fmt.kg(t.creatineG), unit: "g", color: Theme.supplement, symbol: "bolt.fill")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $takesCreatine) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kreatin kullanıyorum").formaFont(.bodyMedium)
                            Text("Günde \(Fmt.kg(t.creatineG)) g; saatinin önemi yok, her gün alman önemli.").formaFont(.caption, Theme.textSecondary)
                        }
                    }
                    if takesCreatine {
                        Picker("Hatırlatma", selection: $creatineHour) {
                            ForEach(6...23, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.lime)
                    }
                    Divider().overlay(Theme.hairline)
                    Toggle(isOn: $takesWhey) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Protein tozu kullanıyorum").formaFont(.bodyMedium)
                            Text("Antrenman günlerinde rafında görünür.").formaFont(.caption, Theme.textSecondary)
                        }
                    }
                }
                .tint(Theme.lime)
                .cardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    permissionRow(symbol: "bell.badge.fill", title: "Hatırlatmalar", detail: "Su, kreatin, antrenman ve dinlenme bitişi", done: notificationsAsked) {
                        Task { _ = await NotificationService.shared.requestAuthorization(); notificationsAsked = true }
                    }
                    if HealthService.shared.isAvailable {
                        permissionRow(symbol: "heart.fill", title: "Apple Sağlık", detail: "Kilo, uyku, nabız ve antrenman paylaşımı", done: healthAsked) {
                            Task {
                                let ok = await HealthService.shared.requestAuthorization()
                                settings.healthKitEnabled = ok
                                healthAsked = true
                            }
                        }
                    }
                }
                .cardStyle()

                Text("Forma tıbbi bir uygulama değildir. Sağlık sorunun varsa beslenme ve takviye kararlarını doktorunla konuş.")
                    .formaFont(.caption, Theme.textTertiary)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, Theme.gutter)
        }
    }

    private func permissionRow(symbol: String, title: String, detail: String, done: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.coral)
                .frame(width: 34, height: 34).background(Theme.coral.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).formaFont(.bodyMedium)
                Text(detail).formaFont(.caption, Theme.textSecondary)
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.lime).font(.system(size: 22))
            } else {
                Button("İzin ver", action: action).buttonStyle(PrimaryButtonStyle(compact: true))
            }
        }
    }

    private func finishOnboarding() {
        var p = profile
        p.name = p.name.trimmingCharacters(in: .whitespaces)
        p.createdAt = Date()
        var supplements: [Supplement] = []
        if takesCreatine {
            supplements.append(Supplement(kind: .creatine, dose: SupplementEngine.creatineMaintenanceDose(weightKg: p.weightKg),
                                          reminderTimes: [ReminderTime(creatineHour, 0)]))
        }
        if takesWhey {
            supplements.append(Supplement(kind: .whey, name: "Whey protein", dose: 1, unit: "ölçek", proteinPerDose: 24, onlyTrainingDays: true))
        }
        let mode: PlanMode = useAutoPlan ? .auto : .program(id: recommendedProgram.id)
        model.completeOnboarding(profile: p, planMode: mode, supplements: supplements, settings: settings)
        Haptics.success()
    }
}
