import SwiftUI
import Charts
import PhotosUI
import FormaKit

struct ProgressHubView: View {
    @Environment(AppModel.self) private var model
    @State private var showWeight = false
    @State private var showMeasure = false
    @State private var showPhotos = false
    @State private var showAchievements = false
    @State private var showStrength = false
    @State private var showCoach = false
    @State private var range = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "\(model.finishedSessions.count) antrenman", title: "İlerleme")
                    levelCard
                    weightCard
                    HStack(spacing: 10) {
                        tile("Ölçüler", model.data.measurements.last(where: { $0.waistCm != nil }).flatMap { $0.waistCm.map { "Bel \(Fmt.oneDecimal($0))" } } ?? "Ekle",
                             "ruler.fill", Theme.water) { showMeasure = true }
                        tile("Fotoğraflar", "\(model.data.photos.count) adet", "camera.fill", Theme.supplement) { showPhotos = true }
                    }
                    strengthCard
                    volumeCard
                    consistencyCard
                    Button { showCoach = true } label: {
                        HStack {
                            Image(systemName: "sparkles").foregroundStyle(Theme.gold)
                            Text("Haftalık koç raporu").formaFont(.bodyMedium)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textTertiary)
                        }
                        .cardStyle()
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showWeight) { WeightEntrySheet().presentationDetents([.medium]).presentationBackground(Theme.background) }
            .sheet(isPresented: $showMeasure) { NavigationStack { MeasurementsView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showPhotos) { NavigationStack { PhotosView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showAchievements) { NavigationStack { AchievementsView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showStrength) { NavigationStack { StrengthListView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showCoach) { NavigationStack { CoachView() }.presentationBackground(Theme.background) }
        }
    }

    private var levelCard: some View {
        let l = model.level
        let unlocked = model.data.unlockedAchievements.count
        return Button { showAchievements = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RingView(progress: l.progress, color: Theme.gold, lineWidth: 8)
                    VStack(spacing: -2) {
                        Text("SV").font(.forma(.micro)).foregroundStyle(Theme.textTertiary)
                        Text("\(l.level)").formaFont(.numberM)
                    }
                }
                .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(l.title).formaFont(.headline)
                    Text("\(l.currentXP - l.levelStartXP) / \(l.nextLevelXP - l.levelStartXP) XP").formaFont(.caption, Theme.textSecondary)
                    HStack(spacing: 12) {
                        Label("\(unlocked)/\(AchievementEngine.all.count)", systemImage: "medal.fill").formaFont(.caption, Theme.gold)
                        Label("\(model.weeklyWorkoutStreak) hafta", systemImage: "flame.fill").formaFont(.caption, Theme.energy)
                        Label("\(model.data.records.count) rekor", systemImage: "trophy.fill").formaFont(.caption, Theme.lime)
                    }
                }
                Spacer(minLength: 0)
            }
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
    }

    private var weightCard: some View {
        let pts = model.weightPoints
        let start = Calendar.forma.date(byAdding: .day, value: -range, to: model.now) ?? model.now
        let visible = pts.filter { $0.date >= start }
        let trend = WeightTrend.smoothed(pts).filter { $0.date >= start }
        let rate = WeightTrend.weeklyRate(pts, now: model.now)
        let minY = (visible.map(\.kg).min() ?? model.latestWeight) - 1
        let maxY = (visible.map(\.kg).max() ?? model.latestWeight) + 1
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kilo").eyebrow()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Fmt.oneDecimal(trend.last?.kg ?? model.latestWeight)).formaFont(.numberL)
                        Text("kg trend").formaFont(.caption, Theme.textSecondary)
                    }
                    if let rate {
                        Text("\(rate >= 0 ? "+" : "")\(Fmt.oneDecimal(rate)) kg / hafta")
                            .formaFont(.caption, rateColor(rate))
                    }
                }
                Spacer()
                Button("Tartıl") { showWeight = true }.buttonStyle(PrimaryButtonStyle(compact: true))
                    .accessibilityIdentifier("progress.addWeight")
            }
            if visible.count >= 2 {
                Chart {
                    ForEach(visible, id: \.date) { p in
                        PointMark(x: .value("Tarih", p.date), y: .value("Kilo", p.kg))
                            .foregroundStyle(Theme.textTertiary)
                            .symbolSize(18)
                    }
                    ForEach(trend, id: \.date) { p in
                        LineMark(x: .value("Tarih", p.date), y: .value("Trend", p.kg))
                            .foregroundStyle(Theme.lime)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: minY...maxY)
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 170)
                Picker("Aralık", selection: $range) {
                    Text("1 ay").tag(30)
                    Text("3 ay").tag(90)
                    Text("1 yıl").tag(365)
                }
                .pickerStyle(.segmented)
                Text("Çizgi, günlük su ve tuz dalgalanmalarını yumuşatan trenddir; tek tek tartılardan daha güvenilirdir.")
                    .formaFont(.caption, Theme.textTertiary)
            } else {
                Text("Haftada 3–4 kez, sabah tuvaletten sonra aç karnına tartılmak en tutarlı sonucu verir.")
                    .formaFont(.caption, Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    private func rateColor(_ rate: Double) -> Color {
        switch model.profile.goal {
        case .loseFat: return rate < 0 ? Theme.lime : Theme.energy
        case .buildMuscle: return rate > 0 ? Theme.lime : Theme.energy
        default: return Theme.textSecondary
        }
    }

    private func tile(_ title: String, _ value: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).foregroundStyle(color).frame(width: 34, height: 34).background(color.opacity(0.14), in: Circle())
                Text(title).eyebrow()
                Text(value).formaFont(.bodyMedium).lineLimit(1)
            }
            .cardStyle(padding: 14)
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder private var strengthCard: some View {
        let top = topLifts()
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Güç").formaFont(.headline)
                Spacer()
                Button("Tümü") { showStrength = true }.font(.forma(.callout)).foregroundStyle(Theme.lime)
            }
            if top.isEmpty {
                Text("Antrenman yaptıkça hareket başına tahmini 1 tekrar maksimumun burada görünecek.").formaFont(.caption, Theme.textSecondary)
            } else {
                ForEach(top) { lift in
                    let ex = lift.exercise, best = lift.best, change = lift.change
                    NavigationLink { ExerciseDetailView(exercise: ex) } label: {
                        HStack {
                            Text(ex.name).formaFont(.callout).lineLimit(1)
                            Spacer()
                            if let change, abs(change) >= 0.5 {
                                Text("\(change >= 0 ? "+" : "")\(Fmt.kg(change.rounded(toStep: 0.5)))")
                                    .formaFont(.caption, change >= 0 ? Theme.lime : Theme.energy)
                            }
                            Text("\(Fmt.kg(best.rounded(toStep: 0.5))) kg").formaFont(.numberS)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text("Tahmini 1RM · son 30 güne göre değişim").formaFont(.caption, Theme.textTertiary)
            }
        }
        .cardStyle()
    }

    struct LiftSummary: Identifiable {
        var exercise: Exercise
        var best: Double
        var change: Double?
        var id: String { exercise.id }
    }

    private func topLifts() -> [LiftSummary] {
        let cutoff = Calendar.forma.date(byAdding: .day, value: -30, to: model.now) ?? model.now
        var counts: [String: Int] = [:]
        for s in model.finishedSessions { for e in s.exercises where !e.completedWorkingSets.isEmpty { counts[e.exerciseID, default: 0] += 1 } }
        let ids = counts.sorted { $0.value > $1.value }.map(\.key)
        return ids.compactMap { id -> LiftSummary? in
            guard let ex = model.exercise(id), ex.tracking == .weightReps else { return nil }
            let h = model.history(of: id)
            let e1rm = { (sets: [SetLog]) in sets.map { StrengthMath.estimated1RM(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0 }
            guard let best = h.map({ e1rm($0.sets) }).max(), best > 0 else { return nil }
            let old = h.filter { $0.date < cutoff }.map { e1rm($0.sets) }.max()
            return LiftSummary(exercise: ex, best: best, change: old.map { best - $0 })
        }
        .prefix(5)
        .map { $0 }
    }

    private var volumeCard: some View {
        let vol = model.weeklyVolume.filter { $0.target.lowerBound >= 6 }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Bu haftaki set sayısı").formaFont(.headline)
            Chart {
                ForEach(vol) { v in
                    BarMark(x: .value("Set", v.sets), y: .value("Kas", v.muscle.displayName))
                        .foregroundStyle(v.status == .below ? Theme.amber : Theme.lime)
                        .cornerRadius(4)
                    RuleMark(xStart: .value("Hedef", v.target.lowerBound), xEnd: .value("Hedef", v.target.lowerBound + 0.15),
                             y: .value("Kas", v.muscle.displayName))
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .chartXAxis { AxisMarks(position: .bottom) }
            .frame(height: CGFloat(max(1, vol.count)) * 26 + 20)
            Text("Beyaz çizgi haftalık minimum hedef. Haftada kas başına ~10+ set kas gelişimi için etkili bulunmuştur; getiri giderek azalır.")
                .formaFont(.caption, Theme.textTertiary)
        }
        .cardStyle()
    }

    private var consistencyCard: some View {
        let cal = Calendar.forma
        let weeks = 12
        let start = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: cal.startOfWeek(for: model.now)) ?? model.now
        let trained = Set(model.finishedSessions.map { DayKey.key($0.startedAt) })
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Süreklilik").formaFont(.headline)
                Spacer()
                Text("Son 12 hafta").formaFont(.caption, Theme.textTertiary)
            }
            HStack(alignment: .top, spacing: 4) {
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { d in
                            let date = cal.date(byAdding: .day, value: w * 7 + d, to: start) ?? start
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(date > model.now ? Color.clear : (trained.contains(DayKey.key(date)) ? Theme.lime : Theme.surfaceHigh))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Kilo girişi

struct WeightEntrySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 75

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Bugünkü tartı").formaFont(.title).padding(.top, 20)
            HStack(alignment: .firstTextBaseline) {
                Spacer()
                Text(Fmt.oneDecimal(weight)).formaFont(.numberXL).monospacedDigit().contentTransition(.numericText())
                Text("kg").formaFont(.headline, Theme.textSecondary)
                Spacer()
            }
            HStack(spacing: 10) {
                ForEach([-1.0, -0.1, 0.1, 1.0], id: \.self) { d in
                    Button(d > 0 ? "+\(Fmt.oneDecimal(d))" : Fmt.oneDecimal(d)) { weight = max(30, min(250, weight + d)) }
                        .buttonStyle(SecondaryButtonStyle(compact: true))
                        .frame(maxWidth: .infinity)
                }
            }
            Button("Kaydet") {
                model.addMeasurement(BodyMeasurement(date: Date(), weightKg: (weight * 10).rounded() / 10))
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("weight.save")
        }
        .padding(.horizontal, Theme.gutter)
        .onAppear { weight = (model.latestWeight * 10).rounded() / 10 }
    }
}

// MARK: - Ölçüler

struct MeasurementsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var waist: Double = 0
    @State private var chest: Double = 0
    @State private var arm: Double = 0
    @State private var hip: Double = 0
    @State private var thigh: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 12) {
                    NumberStepper(title: "Bel", value: $waist, step: 0.5, range: 0...200, unit: "cm", format: Fmt.oneDecimal)
                    NumberStepper(title: "Göğüs", value: $chest, step: 0.5, range: 0...200, unit: "cm", format: Fmt.oneDecimal)
                    NumberStepper(title: "Kol", value: $arm, step: 0.5, range: 0...80, unit: "cm", format: Fmt.oneDecimal)
                    NumberStepper(title: "Kalça", value: $hip, step: 0.5, range: 0...200, unit: "cm", format: Fmt.oneDecimal)
                    NumberStepper(title: "Uyluk", value: $thigh, step: 0.5, range: 0...120, unit: "cm", format: Fmt.oneDecimal)
                }
                .cardStyle()
                Button("Kaydet") {
                    model.addMeasurement(BodyMeasurement(date: Date(), waistCm: waist > 0 ? waist : nil, chestCm: chest > 0 ? chest : nil,
                                                         armCm: arm > 0 ? arm : nil, hipCm: hip > 0 ? hip : nil, thighCm: thigh > 0 ? thigh : nil))
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("Bel çevresini göbek hizasından, nefes verdikten sonra ölç. Kilo değişmese bile bel incelip kol kalınlaşıyorsa vücut kompozisyonun iyileşiyordur.")
                    .formaFont(.caption, Theme.textTertiary)
                let history = model.data.measurements.filter { $0.waistCm != nil || $0.armCm != nil || $0.chestCm != nil }.reversed()
                if !history.isEmpty {
                    Text("Geçmiş").eyebrow().padding(.top, 8)
                    ForEach(Array(history)) { m in
                        HStack {
                            Text(Fmt.shortDate.string(from: m.date)).formaFont(.caption, Theme.textSecondary).frame(width: 60, alignment: .leading)
                            Text([m.waistCm.map { "Bel \(Fmt.oneDecimal($0))" }, m.chestCm.map { "Göğüs \(Fmt.oneDecimal($0))" },
                                  m.armCm.map { "Kol \(Fmt.oneDecimal($0))" }, m.hipCm.map { "Kalça \(Fmt.oneDecimal($0))" }]
                                .compactMap { $0 }.joined(separator: " · "))
                                .formaFont(.callout)
                            Spacer()
                        }
                        .cardStyle(padding: 12)
                        .contextMenu { Button("Sil", role: .destructive) { model.deleteMeasurement(m.id) } }
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Vücut ölçüleri")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
        .onAppear {
            let last = model.data.measurements.reversed()
            waist = last.first { $0.waistCm != nil }?.waistCm ?? 0
            chest = last.first { $0.chestCm != nil }?.chestCm ?? 0
            arm = last.first { $0.armCm != nil }?.armCm ?? 0
            hip = last.first { $0.hipCm != nil }?.hipCm ?? 0
            thigh = last.first { $0.thighCm != nil }?.thighCm ?? 0
        }
    }
}

// MARK: - Fotoğraflar

struct PhotosView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pose: PhotoPose = .front
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var compare = 0.5

    var body: some View {
        let photos = model.data.photos.filter { $0.pose == pose }.sorted { $0.date < $1.date }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Poz", selection: $pose) {
                    ForEach(PhotoPose.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                if let first = photos.first, let last = photos.last, first.id != last.id,
                   let a = PhotoStore.load(first.fileName), let b = PhotoStore.load(last.fileName) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Önce / sonra").formaFont(.headline)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Image(uiImage: b).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                                Image(uiImage: a).resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                                    .mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * compare) }
                                Rectangle().fill(Theme.lime).frame(width: 3).offset(x: geo.size.width * compare - 1.5)
                            }
                            .gesture(DragGesture(minimumDistance: 0).onChanged { v in compare = min(1, max(0, v.location.x / geo.size.width)) })
                        }
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        HStack {
                            Text(Fmt.shortDate.string(from: first.date) + (first.weightKg.map { " · \(Fmt.oneDecimal($0)) kg" } ?? ""))
                            Spacer()
                            Text(Fmt.shortDate.string(from: last.date) + (last.weightKg.map { " · \(Fmt.oneDecimal($0)) kg" } ?? ""))
                        }
                        .formaFont(.caption, Theme.textSecondary)
                    }
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Galeriden", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(SecondaryButtonStyle(compact: true))
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: { Label("Çek", systemImage: "camera.fill") }
                            .buttonStyle(PrimaryButtonStyle(compact: true))
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(photos.reversed()) { p in
                        if let img = PhotoStore.load(p.fileName) {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(height: 140).frame(maxWidth: .infinity).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(alignment: .bottomLeading) {
                                    Text(Fmt.shortDate.string(from: p.date)).font(.forma(.micro)).foregroundStyle(.white)
                                        .padding(4).background(.black.opacity(0.5), in: Capsule()).padding(6)
                                }
                                .contextMenu { Button("Sil", role: .destructive) { model.deletePhoto(p) } }
                        }
                    }
                }
                Text("Fotoğraflar sadece telefonunda saklanır. Her ay aynı ışıkta, aynı pozda çekmek karşılaştırmayı kolaylaştırır.")
                    .formaFont(.caption, Theme.textTertiary)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("İlerleme fotoğrafları")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    model.addPhoto(img, pose: pose)
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in
                if let img { model.addPhoto(img, pose: pose) }
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

// MARK: - Güç listesi

struct StrengthListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let ids = Array(Set(model.finishedSessions.flatMap { $0.exercises.filter { !$0.completedWorkingSets.isEmpty }.map(\.exerciseID) })).sorted()
        let exercises = ids.compactMap(model.exercise).sorted { $0.name < $1.name }
        List {
            ForEach(exercises) { ex in
                NavigationLink { ExerciseDetailView(exercise: ex) } label: {
                    HStack {
                        Text(ex.name).formaFont(.callout)
                        Spacer()
                        if let best = model.bestE1RM(of: ex.id), ex.tracking == .weightReps {
                            Text("~\(Fmt.kg(best.rounded(toStep: 0.5))) kg").formaFont(.callout, Theme.textSecondary)
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            let prs = model.data.records.sorted { $0.date > $1.date }.prefix(20)
            if !prs.isEmpty {
                Section("Son rekorlar") {
                    ForEach(Array(prs)) { r in
                        HStack {
                            Image(systemName: "trophy.fill").foregroundStyle(Theme.gold)
                            VStack(alignment: .leading) {
                                Text(model.exercise(r.exerciseID)?.name ?? "").formaFont(.callout)
                                Text("\(r.kind.displayName) · \(Fmt.relativeDay(r.date))").formaFont(.caption, Theme.textSecondary)
                            }
                            Spacer()
                            Text("\(Fmt.kg(r.weightKg)) × \(r.reps)").formaFont(.callout)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Güç ve rekorlar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
    }
}

// MARK: - Rozetler

struct AchievementsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let l = model.level
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 10) {
                    ZStack {
                        RingView(progress: l.progress, color: Theme.gold, lineWidth: 12)
                        VStack(spacing: 0) {
                            Text("SEVİYE").font(.forma(.micro)).tracking(1.4).foregroundStyle(Theme.textTertiary)
                            Text("\(l.level)").formaFont(.numberXL)
                        }
                    }
                    .frame(width: 150, height: 150)
                    Text(l.title).formaFont(.title)
                    Text("Sonraki seviyeye \(l.nextLevelXP - l.currentXP) XP").formaFont(.caption, Theme.textSecondary)
                    Text("XP: her set 2, her antrenman 25, rozetler ekstra.").formaFont(.caption, Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(AchievementEngine.all) { a in
                        let date = model.data.unlockedAchievements[a.id]
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: a.symbol).font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(date != nil ? Theme.onLime : Theme.textTertiary)
                                .frame(width: 42, height: 42)
                                .background(date != nil ? Theme.gold : Theme.surfaceRaised, in: Circle())
                            Text(a.title).formaFont(.bodyMedium, date != nil ? Theme.textPrimary : Theme.textSecondary)
                            Text(a.detail).formaFont(.caption, Theme.textTertiary).fixedSize(horizontal: false, vertical: true)
                            Text(date.map { Fmt.shortDate.string(from: $0) } ?? "+\(a.xp) XP")
                                .font(.forma(.label)).foregroundStyle(date != nil ? Theme.gold : Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
                        .cardStyle(padding: 14)
                        .opacity(date != nil ? 1 : 0.75)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Rozetler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
    }
}

// MARK: - Koç

struct CoachView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var summary: String?

    var body: some View {
        let insights = CoachService.weeklyInsights(model: model)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(Theme.gold)
                        Text("Son 7 gün").formaFont(.headline)
                    }
                    if let summary {
                        Text(summary).formaFont(.body).fixedSize(horizontal: false, vertical: true)
                    } else {
                        ProgressView().tint(Theme.lime)
                    }
                }
                .cardStyle(background: Theme.gold.opacity(0.08))
                ForEach(insights) { i in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: i.symbol).font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(color(i.tone))
                            .frame(width: 34, height: 34)
                            .background(color(i.tone).opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(i.title).formaFont(.bodyMedium)
                            Text(i.detail).formaFont(.caption, Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .cardStyle(padding: 14)
                }
                Text("Özet cihazında hazırlanır, verilerin hiçbir yere gönderilmez.").formaFont(.caption, Theme.textTertiary)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Haftalık koç")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
        .task {
            summary = await CoachService.summary(insights: insights)
        }
    }

    private func color(_ tone: CoachService.Insight.Tone) -> Color {
        switch tone {
        case .good: return Theme.lime
        case .neutral: return Theme.water
        case .attention: return Theme.energy
        }
    }
}
