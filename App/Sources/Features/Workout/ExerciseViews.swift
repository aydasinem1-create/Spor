import SwiftUI
import Charts
import FormaKit

// MARK: - Hareket detayı (doğru form)

struct ExerciseDetailView: View {
    @Environment(AppModel.self) private var model
    var exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ExerciseAnimationView(exercise: exercise)
                    .frame(height: 240)
                Text("Fotoğraflar hareketin başlangıç ve bitiş pozisyonunu gösterir; dokunarak durdurabilirsin.")
                    .formaFont(.caption, Theme.textTertiary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.name).formaFont(.title)
                    Text(exercise.englishName).formaFont(.caption, Theme.textTertiary)
                    FlowLayout(spacing: 6) {
                        tag(exercise.mechanic == .compound ? "Çok eklemli" : "Tek eklemli", Theme.water)
                        tag(exercise.difficulty.displayName, Theme.supplement)
                        ForEach(exercise.equipment, id: \.self) { tag($0.displayName, Theme.textSecondary) }
                    }
                }

                HStack(spacing: 12) {
                    MuscleMapView(side: .front, mode: .highlight(primary: exercise.primary, secondary: exercise.secondary))
                    MuscleMapView(side: .back, mode: .highlight(primary: exercise.primary, secondary: exercise.secondary))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ana kaslar").eyebrow()
                        Text(exercise.primary.map(\.displayName).joined(separator: ", ")).formaFont(.callout, Theme.lime)
                        if !exercise.secondary.isEmpty {
                            Text("Yardımcı").eyebrow().padding(.top, 4)
                            Text(exercise.secondary.map(\.displayName).joined(separator: ", ")).formaFont(.callout, Theme.textSecondary)
                        }
                        Text("Öneri").eyebrow().padding(.top, 4)
                        Text("\(exercise.repLow)–\(exercise.repHigh)\(exercise.tracking == .duration ? " sn" : " tekrar") · \(exercise.restSeconds) sn dinlenme")
                            .formaFont(.caption, Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 190)
                .cardStyle()

                VStack(alignment: .leading, spacing: 12) {
                    Label("Doğru form", systemImage: "checkmark.seal.fill").formaFont(.headline, Theme.lime)
                    ForEach(Array(exercise.cues.enumerated()), id: \.offset) { i, cue in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)").formaFont(.callout, Theme.onLime)
                                .frame(width: 24, height: 24).background(Theme.lime, in: Circle())
                            Text(cue).formaFont(.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .cardStyle()

                if !exercise.mistakes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Sık yapılan hatalar", systemImage: "exclamationmark.triangle.fill").formaFont(.headline, Theme.energy)
                        ForEach(exercise.mistakes, id: \.self) { m in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.energy).padding(.top, 4)
                                Text(m).formaFont(.body, Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .cardStyle()
                }

                progressSection

                Text("Görseller: free-exercise-db (Unlicense / kamu malı).")
                    .formaFont(.caption, Theme.textTertiary)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .screenBackground()
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(.forma(.label)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }

    @ViewBuilder private var progressSection: some View {
        let history = model.history(of: exercise.id).reversed()
        if !history.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Gelişimin").formaFont(.headline)
                    Spacer()
                    if let best = model.bestE1RM(of: exercise.id), exercise.tracking == .weightReps {
                        Text("En iyi 1RM ~\(Fmt.kg(best.rounded(toStep: 0.5))) kg").formaFont(.caption, Theme.gold)
                    }
                }
                if exercise.tracking == .weightReps {
                    Chart {
                        ForEach(Array(history.enumerated()), id: \.offset) { _, h in
                            let best = h.sets.map { StrengthMath.estimated1RM(weight: $0.weightKg, reps: $0.reps) }.max() ?? 0
                            LineMark(x: .value("Tarih", h.date), y: .value("1RM", best))
                                .foregroundStyle(Theme.lime)
                                .interpolationMethod(.monotone)
                            PointMark(x: .value("Tarih", h.date), y: .value("1RM", best))
                                .foregroundStyle(Theme.lime)
                        }
                    }
                    .chartYAxis { AxisMarks(position: .leading) }
                    .frame(height: 180)
                }
                ForEach(Array(history.reversed().prefix(6).enumerated()), id: \.offset) { _, h in
                    HStack {
                        Text(Fmt.relativeDay(h.date)).formaFont(.caption, Theme.textSecondary).frame(width: 90, alignment: .leading)
                        Text(ProgressionEngine.summary(of: h.sets, tracking: exercise.tracking)).formaFont(.callout)
                        Spacer()
                    }
                }
            }
            .cardStyle()
        }
    }
}

// MARK: - Kütüphane

struct ExerciseLibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var onPick: ((Exercise) -> Void)? = nil

    @State private var query = ""
    @State private var muscle: MuscleGroup?
    @State private var onlyAvailable = true
    @State private var showMap = true

    private var results: [Exercise] {
        let q = FoodDatabase.normalize(query)
        return model.allExercises.filter { ex in
            if let muscle, !ex.primary.contains(muscle) { return false }
            if onlyAvailable && !ex.isAvailable(with: model.profile.equipment) { return false }
            if q.isEmpty { return true }
            let hay = FoodDatabase.normalize(ex.name + " " + ex.englishName + " " + ex.primary.map(\.displayName).joined(separator: " "))
            return q.split(separator: " ").allSatisfy { hay.contains($0) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if showMap && query.isEmpty {
                    VStack(spacing: 8) {
                        Text("Çalışmak istediğin bölgeye dokun").formaFont(.caption, Theme.textSecondary)
                        HStack(spacing: 8) {
                            MuscleMapView(side: .front, mode: .selection(muscle.map { [$0] } ?? [])) { m in toggle(m) }
                            MuscleMapView(side: .back, mode: .selection(muscle.map { [$0] } ?? [])) { m in toggle(m) }
                        }
                        .frame(height: 260)
                    }
                    .cardStyle()
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        Chip(title: "Tümü", isOn: muscle == nil) { muscle = nil }
                        ForEach(MuscleGroup.allCases) { m in
                            Chip(title: m.displayName, isOn: muscle == m) { toggle(m) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Toggle("Sadece ekipmanıma uygun olanlar", isOn: $onlyAvailable)
                    .formaFont(.callout, Theme.textSecondary)
                    .tint(Theme.lime)
                LazyVStack(spacing: 10) {
                    ForEach(results) { ex in
                        if let onPick {
                            Button { onPick(ex) } label: { ExerciseListRow(exercise: ex, showAdd: true) }
                                .buttonStyle(PressableStyle())
                                .accessibilityIdentifier("exercise.row.\(ex.id)")
                        } else {
                            NavigationLink { ExerciseDetailView(exercise: ex) } label: { ExerciseListRow(exercise: ex, showAdd: false) }
                                .buttonStyle(PressableStyle())
                                .accessibilityIdentifier("exercise.row.\(ex.id)")
                        }
                    }
                    if results.isEmpty {
                        EmptyCard(symbol: "magnifyingglass", title: "Sonuç yok", message: "Farklı bir kelime dene ya da ekipman filtresini kapat.")
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Hareket ara")
        .screenBackground()
        .navigationTitle(onPick == nil ? "Hareketler" : "Hareket ekle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
    }

    private func toggle(_ m: MuscleGroup) {
        withAnimation(.easeOut(duration: 0.2)) { muscle = muscle == m ? nil : m }
    }
}

struct ExerciseListRow: View {
    @Environment(AppModel.self) private var model
    var exercise: Exercise
    var showAdd: Bool

    var body: some View {
        HStack(spacing: 12) {
            ExerciseAnimationView(exercise: exercise, cornerRadius: 12, animated: false)
                .frame(width: 76, height: 56)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name).formaFont(.bodyMedium).lineLimit(2).multilineTextAlignment(.leading)
                Text(exercise.primary.map(\.displayName).joined(separator: ", ") + " · " + (exercise.equipment.first?.displayName ?? ""))
                    .formaFont(.caption, Theme.textSecondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: showAdd ? "plus.circle.fill" : "chevron.right")
                .font(.system(size: showAdd ? 22 : 12, weight: .bold))
                .foregroundStyle(showAdd ? Theme.lime : Theme.textTertiary)
        }
        .cardStyle(padding: 10)
    }
}

// MARK: - Program seçimi

struct ProgramPickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    model.choosePlan(.auto)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "wand.and.stars").foregroundStyle(Theme.supplement)
                            Text("Otomatik plan").formaFont(.headline)
                            Spacer()
                            if model.settings.planMode.isAuto { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.lime) }
                        }
                        Text("Her gün kas toparlanmana, haftalık set hedeflerine, odak bölgelerine ve hazır olma skoruna göre antrenman kurar. Aynı hareketleri tekrar seçerek ilerlemeni takip eder.")
                            .formaFont(.caption, Theme.textSecondary)
                            .multilineTextAlignment(.leading)
                        if model.profile.experience == .beginner && model.finishedSessions.count < 12 {
                            Text("Öneri: önce hazır bir programla 4–6 hafta hareketleri öğren.").formaFont(.caption, Theme.amber)
                        }
                    }
                    .cardStyle(background: model.settings.planMode.isAuto ? Theme.supplement.opacity(0.12) : Theme.surface)
                }
                .buttonStyle(PressableStyle())

                SectionTitle(title: "Hazır programlar")
                ForEach(ProgramLibrary.all) { program in
                    let selected = model.settings.planMode.programID == program.id
                    let missing = program.requiredEquipment.subtracting(model.profile.equipment)
                    Button {
                        model.choosePlan(.program(id: program.id))
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(program.name).formaFont(.headline)
                                Spacer()
                                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.lime) }
                            }
                            Text(program.summary).formaFont(.caption, Theme.textSecondary).multilineTextAlignment(.leading)
                            HStack(spacing: 6) {
                                Text("\(program.daysPerWeek) gün/hafta").font(.forma(.label)).foregroundStyle(Theme.lime)
                                Text("·").foregroundStyle(Theme.textTertiary)
                                Text(program.level.displayName).font(.forma(.label)).foregroundStyle(Theme.textSecondary)
                                Text("·").foregroundStyle(Theme.textTertiary)
                                Text("\(program.weeks) hafta").font(.forma(.label)).foregroundStyle(Theme.textSecondary)
                            }
                            if !missing.isEmpty {
                                Text("Eksik ekipman yerine alternatif hareket kullanılır: \(missing.map(\.displayName).sorted().joined(separator: ", "))")
                                    .formaFont(.caption, Theme.amber)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .cardStyle(background: selected ? Theme.lime.opacity(0.08) : Theme.surface)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 20)
        }
        .screenBackground()
        .navigationTitle("Plan seç")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
    }
}
