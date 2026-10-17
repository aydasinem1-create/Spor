import SwiftUI
import FormaKit

struct ActiveWorkoutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showFinish = false
    @State private var showAddExercise = false
    @State private var replaceIndex: Int?
    @State private var detailExercise: Exercise?
    @State private var plateWeight: Double?
    @State private var noteExercise: (index: Int, id: String)?
    @State private var noteText = ""
    @State private var result: AppModel.WorkoutResult?
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            Group {
                if let w = model.activeWorkout {
                    content(w)
                } else if let result {
                    WorkoutSummaryView(result: result) { dismiss() }
                } else {
                    Color.clear.onAppear { dismiss() }
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showFinish) {
            FinishWorkoutSheet { rpe, note in
                showFinish = false
                result = model.finishWorkout(rpe: rpe, note: note)
                if result == nil { dismiss() }
            }
            .presentationDetents([.medium])
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showAddExercise) {
            NavigationStack {
                ExerciseLibraryView { ex in
                    model.addExercise(ex)
                    showAddExercise = false
                }
            }
            .presentationBackground(Theme.background)
        }
        .sheet(item: Binding(get: { replaceIndex.map { IndexBox(value: $0) } }, set: { replaceIndex = $0?.value })) { box in
            NavigationStack {
                AlternativesView(index: box.value) { replaceIndex = nil }
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Theme.background)
        }
        .sheet(item: $detailExercise) { ex in
            NavigationStack { ExerciseDetailView(exercise: ex) }.presentationBackground(Theme.background)
        }
        .sheet(item: Binding(get: { plateWeight.map { WeightBox(value: $0) } }, set: { plateWeight = $0?.value })) { box in
            PlateCalculatorView(initialWeight: box.value)
                .presentationDetents([.medium])
                .presentationBackground(Theme.background)
        }
        .alert("Hareket notu", isPresented: Binding(get: { noteExercise != nil }, set: { if !$0 { noteExercise = nil } })) {
            TextField("Örn. koltuk 4. kademe", text: $noteText)
            Button("Kaydet") {
                if let n = noteExercise { model.setExerciseNote(noteText, exerciseID: n.id) }
                noteExercise = nil
            }
            Button("Vazgeç", role: .cancel) { noteExercise = nil }
        } message: {
            Text("Makine ayarı, tutuş gibi bir sonraki sefere hatırlatmak istediğin şeyler.")
        }
        .confirmationDialog("Antrenman silinsin mi?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Sil ve çık", role: .destructive) {
                model.discardWorkout()
                dismiss()
            }
        } message: {
            Text("Tamamlanan setler kaydedilmeyecek.")
        }
    }

    // MARK: İçerik

    private func content(_ w: WorkoutSession) -> some View {
        VStack(spacing: 0) {
            topBar(w)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if model.lowReadiness {
                            Label("Hazır olma skorun düşük: setler azaltıldı, ağırlık artırma önerisi kapalı.", systemImage: "battery.25percent")
                                .formaFont(.caption, Theme.energy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle(padding: 12, background: Theme.energy.opacity(0.12))
                        }
                        ForEach(Array(w.exercises.enumerated()), id: \.element.id) { index, se in
                            ExerciseCard(index: index, sessionExercise: se,
                                         onDetail: { detailExercise = model.exercise(se.exerciseID) },
                                         onReplace: { replaceIndex = index },
                                         onNote: {
                                             noteText = se.note
                                             noteExercise = (index, se.exerciseID)
                                         },
                                         onPlates: { weight in plateWeight = weight })
                                .id(se.id)
                        }
                        Button { showAddExercise = true } label: {
                            Label("Hareket ekle", systemImage: "plus")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.top, 4)

                        Button("Antrenmanı sil", role: .destructive) { confirmDiscard = true }
                            .formaFont(.callout, Theme.coral)
                            .padding(.vertical, 18)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 140)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: w.completedSetCount) { _, _ in
                    // Bir hareket bitince bir sonrakine kaydır
                    guard let next = model.nextIncompleteSet(in: w), next.1 == firstWorkingIndex(w.exercises[next.0]) else { return }
                    withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(w.exercises[next.0].id, anchor: .top) }
                }
            }
            .overlay(alignment: .bottom) { RestTimerPanel() }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Bitti") { KeyboardHelper.dismiss() }.foregroundStyle(Theme.lime)
            }
        }
    }

    private func firstWorkingIndex(_ se: SessionExercise) -> Int {
        se.sets.firstIndex { $0.kind != .warmup } ?? 0
    }

    private func topBar(_ w: WorkoutSession) -> some View {
        let total = w.exercises.reduce(0) { $0 + $1.sets.filter { $0.kind != .warmup }.count }
        let done = w.exercises.reduce(0) { $0 + $1.sets.filter { $0.kind != .warmup && $0.isCompleted }.count }
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                IconButton(systemName: "chevron.down") { dismiss() }
                    .accessibilityLabel("Küçült")
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.title).formaFont(.headline).lineLimit(1)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(Fmt.duration(ctx.date.timeIntervalSince(w.startedAt)))
                            .formaFont(.caption, Theme.textSecondary).monospacedDigit()
                    }
                }
                Spacer()
                Button("Bitir") { showFinish = true }
                    .buttonStyle(PrimaryButtonStyle(compact: true))
                    .accessibilityIdentifier("workout.finish")
            }
            HStack(spacing: 10) {
                BarView(progress: total > 0 ? Double(done) / Double(total) : 0, color: Theme.lime, height: 6)
                Text("\(done)/\(total) set").formaFont(.caption, Theme.textSecondary).monospacedDigit()
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background)
    }
}

struct IndexBox: Identifiable { var value: Int; var id: Int { value } }
struct WeightBox: Identifiable { var value: Double; var id: Double { value } }

enum KeyboardHelper {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct SetRowItem: Identifiable {
    var index: Int
    var set: SetLog
    var number: Int?
    var id: UUID { set.id }
}

// MARK: - Hareket kartı

struct ExerciseCard: View {
    @Environment(AppModel.self) private var model
    var index: Int
    var sessionExercise: SessionExercise
    var onDetail: () -> Void
    var onReplace: () -> Void
    var onNote: () -> Void
    var onPlates: (Double) -> Void
    @State private var showImage = true

    private var exercise: Exercise? { model.exercise(sessionExercise.exerciseID) }

    var body: some View {
        let se = sessionExercise
        let allDone = !se.sets.isEmpty && se.sets.allSatisfy(\.isCompleted)
        VStack(alignment: .leading, spacing: 12) {
            if let ex = exercise {
                header(ex, allDone: allDone)
                if showImage && !allDone {
                    ExerciseAnimationView(exercise: ex)
                        .frame(height: 190)
                    if let cue = ex.cues.first {
                        Label(cue, systemImage: "lightbulb.fill")
                            .formaFont(.caption, Theme.textSecondary)
                            .labelStyle(CueLabelStyle())
                    }
                }
                suggestionLine(ex)
                setTable(ex)
                HStack {
                    Button { model.addSet(exerciseIndex: index) } label: {
                        Label("Set ekle", systemImage: "plus").formaFont(.callout, Theme.lime)
                    }
                    Spacer()
                    if !se.note.isEmpty {
                        Label(se.note, systemImage: "note.text").formaFont(.caption, Theme.textSecondary).lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            .strokeBorder(allDone ? Theme.lime.opacity(0.35) : Color.white.opacity(0.04), lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: allDone)
    }

    private func header(_ ex: Exercise, allDone: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(ex.name).formaFont(.headline).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(ex.primary.prefix(2), id: \.self) { m in
                        Text(m.displayName).font(.forma(.label)).foregroundStyle(Theme.lime)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.lime.opacity(0.12), in: Capsule())
                    }
                    Text("\(sessionExercise.targetRepLow)–\(sessionExercise.targetRepHigh)\(ex.tracking == .duration ? " sn" : " tekrar") · \(sessionExercise.restSeconds) sn dinlenme")
                        .formaFont(.caption, Theme.textTertiary)
                }
            }
            Spacer()
            if allDone {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.lime)
            }
            Menu {
                Button { onDetail() } label: { Label("Doğru form", systemImage: "figure.strengthtraining.traditional") }
                Button { showImage.toggle() } label: { Label(showImage ? "Görseli gizle" : "Görseli göster", systemImage: "photo") }
                Button { onReplace() } label: { Label("Başka hareketle değiştir", systemImage: "arrow.triangle.2.circlepath") }
                Button { onNote() } label: { Label("Not ekle", systemImage: "note.text") }
                if ex.usesBarbell {
                    Button { onPlates(sessionExercise.sets.first { !$0.isCompleted }?.weightKg ?? sessionExercise.sets.last?.weightKg ?? 60) } label: {
                        Label("Plaka hesapla", systemImage: "circle.grid.2x1.fill")
                    }
                }
                Divider()
                Button(role: .destructive) { model.removeExercise(at: index) } label: { Label("Hareketi kaldır", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.surfaceRaised, in: Circle())
            }
        }
    }

    @ViewBuilder private func suggestionLine(_ ex: Exercise) -> some View {
        let history = ProgressionEngine.history(for: ex.id, in: model.finishedSessions, limit: 1)
        if let last = history.first {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Theme.textTertiary).font(.system(size: 12))
                Text("Geçen sefer: \(ProgressionEngine.summary(of: last, tracking: ex.tracking))").formaFont(.caption, Theme.textSecondary)
            }
        }
        let suggestion = ProgressionEngine.suggest(exercise: ex, setCount: max(1, sessionExercise.sets.filter { $0.kind != .warmup }.count),
                                                   repRange: sessionExercise.targetReps, sessions: model.finishedSessions,
                                                   gym: model.settings.gym, lowReadiness: model.lowReadiness)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: suggestion.kind == .increase ? "arrow.up.circle.fill" : (suggestion.kind == .deload ? "arrow.down.circle.fill" : "target"))
                .foregroundStyle(suggestion.kind == .increase ? Theme.lime : (suggestion.kind == .deload ? Theme.energy : Theme.water))
                .font(.system(size: 14))
            Text(suggestion.message).formaFont(.caption, Theme.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func setTable(_ ex: Exercise) -> some View {
        let previous = ProgressionEngine.history(for: ex.id, in: model.finishedSessions, limit: 1).first ?? []
        var workingCounter = 0
        var rows: [SetRowItem] = []
        for (i, s) in sessionExercise.sets.enumerated() {
            if s.kind == .warmup {
                rows.append(SetRowItem(index: i, set: s, number: nil))
            } else {
                workingCounter += 1
                rows.append(SetRowItem(index: i, set: s, number: workingCounter))
            }
        }
        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("SET").frame(width: 34, alignment: .leading)
                Text("ÖNCEKİ").frame(maxWidth: .infinity, alignment: .leading)
                if ex.tracking == .weightReps || ex.tracking == .reps {
                    Text(ex.tracking == .reps ? "+KG" : "KG").frame(width: 70)
                }
                Text(ex.tracking == .duration ? "SN" : "TEKRAR").frame(width: 62)
                Color.clear.frame(width: 40)
            }
            .font(.forma(.micro)).tracking(1).foregroundStyle(Theme.textTertiary)

            ForEach(rows) { row in
                let prev: SetLog? = row.number.flatMap { n in previous.indices.contains(n - 1) ? previous[n - 1] : nil }
                SetRow(exerciseIndex: index, setIndex: row.index, set: row.set, number: row.number, exercise: ex, previous: prev)
            }
        }
    }
}

struct CueLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon.foregroundStyle(Theme.gold).font(.system(size: 12))
            configuration.title
        }
    }
}

// MARK: - Set satırı

struct SetRow: View {
    @Environment(AppModel.self) private var model
    var exerciseIndex: Int
    var setIndex: Int
    var set: SetLog
    var number: Int?
    var exercise: Exercise
    var previous: SetLog?

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SetKind.allCases, id: \.self) { kind in
                    Button { model.setValue(exerciseIndex: exerciseIndex, setIndex: setIndex, kind: kind) } label: {
                        if set.kind == kind { Label(kind.displayName, systemImage: "checkmark") } else { Text(kind.displayName) }
                    }
                }
                Menu("Yedek tekrar (RIR)") {
                    ForEach(0...4, id: \.self) { r in
                        Button(r == 4 ? "4+" : "\(r)") { model.setValue(exerciseIndex: exerciseIndex, setIndex: setIndex, rir: .some(r)) }
                    }
                    Button("Temizle") { model.setValue(exerciseIndex: exerciseIndex, setIndex: setIndex, rir: .some(nil)) }
                }
                Divider()
                Button(role: .destructive) { model.removeSet(exerciseIndex: exerciseIndex, setIndex: setIndex) } label: { Label("Seti sil", systemImage: "trash") }
            } label: {
                Text(label)
                    .formaFont(.numberS, kindColor)
                    .frame(width: 34, height: 36)
                    .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(previousText)
                .formaFont(.caption, Theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .onTapGesture { copyPrevious() }

            if exercise.tracking != .duration {
                DecimalField(value: Binding(get: { set.weightKg }, set: { model.setValue(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: $0) }),
                             placeholder: "0")
                    .frame(width: 70)
            }
            IntField(value: Binding(get: { exercise.tracking == .duration ? set.seconds : set.reps },
                                    set: { v in
                                        if exercise.tracking == .duration {
                                            model.setValue(exerciseIndex: exerciseIndex, setIndex: setIndex, seconds: v)
                                        } else {
                                            model.setValue(exerciseIndex: exerciseIndex, setIndex: setIndex, reps: v)
                                        }
                                    }))
                .frame(width: 62)

            Button {
                KeyboardHelper.dismiss()
                model.completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(set.isCompleted ? Theme.onLime : Theme.textTertiary)
                    .frame(width: 40, height: 36)
                    .background(set.isCompleted ? Theme.lime : Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(set.isCompleted ? "Set tamamlandı" : "Seti tamamla")
            .accessibilityIdentifier("set.complete.\(exerciseIndex).\(setIndex)")
        }
        .padding(.vertical, 2)
        .background(set.isCompleted ? Theme.lime.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: set.isCompleted)
    }

    private var label: String {
        switch set.kind {
        case .warmup: return "I"
        case .drop: return "D"
        case .failure: return "T"
        case .working: return number.map(String.init) ?? "–"
        }
    }

    private var kindColor: Color {
        switch set.kind {
        case .warmup: return Theme.amber
        case .drop: return Theme.supplement
        case .failure: return Theme.coral
        case .working: return Theme.textPrimary
        }
    }

    private var previousText: String {
        guard let p = previous else { return set.kind == .warmup ? "ısınma" : "–" }
        switch exercise.tracking {
        case .duration: return "\(p.seconds) sn"
        case .reps: return p.weightKg > 0 ? "+\(Fmt.kg(p.weightKg)) × \(p.reps)" : "\(p.reps) tekrar"
        case .weightReps: return "\(Fmt.kg(p.weightKg)) × \(p.reps)"
        }
    }

    private func copyPrevious() {
        guard let p = previous, !set.isCompleted else { return }
        model.setValue(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: p.weightKg, reps: p.reps, seconds: p.seconds)
        Haptics.tap()
    }
}

// MARK: - Sayı alanları

struct DecimalField: View {
    @Binding var value: Double
    var placeholder: String
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.forma(.numberS))
            .foregroundStyle(Theme.textPrimary)
            .frame(height: 36)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused($focused)
            .onAppear { text = value > 0 ? value.formattedKg : "" }
            .onChange(of: value) { _, v in if !focused { text = v > 0 ? v.formattedKg : "" } }
            .onChange(of: focused) { _, f in
                if !f { commit() } else { text = value > 0 ? value.formattedKg : "" }
            }
            .onSubmit { commit() }
    }

    private func commit() {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if let v = Double(normalized) { value = min(1000, max(0, v)) } else if text.isEmpty { value = 0 }
        text = value > 0 ? value.formattedKg : ""
    }
}

struct IntField: View {
    @Binding var value: Int
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.forma(.numberS))
            .foregroundStyle(Theme.textPrimary)
            .frame(height: 36)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .focused($focused)
            .onAppear { text = value > 0 ? "\(value)" : "" }
            .onChange(of: value) { _, v in if !focused { text = v > 0 ? "\(v)" : "" } }
            .onChange(of: focused) { _, f in if !f { commit() } }
            .onSubmit { commit() }
    }

    private func commit() {
        if let v = Int(text) { value = min(999, max(0, v)) } else if text.isEmpty { value = 0 }
        text = value > 0 ? "\(value)" : ""
    }
}

// MARK: - Dinlenme paneli

struct RestTimerPanel: View {
    @Environment(AppModel.self) private var model
    @State private var notifiedEnd: Date?

    var body: some View {
        if let end = model.restTimer.endsAt {
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                let remaining = max(0, end.timeIntervalSince(ctx.date))
                let total = Double(max(1, model.restTimer.total))
                HStack(spacing: 14) {
                    ZStack {
                        RingView(progress: remaining / total, color: Theme.water, lineWidth: 6)
                        Image(systemName: "timer").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.water)
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Dinlenme").eyebrow(Theme.water)
                        Text(Fmt.duration(remaining.rounded(.up))).formaFont(.numberL).monospacedDigit()
                    }
                    Spacer()
                    Button("−15") { model.adjustRest(by: -15) }.buttonStyle(SecondaryButtonStyle(compact: true))
                    Button("+15") { model.adjustRest(by: 15) }.buttonStyle(SecondaryButtonStyle(compact: true))
                    Button { model.skipRest() } label: { Image(systemName: "forward.end.fill") }
                        .buttonStyle(PrimaryButtonStyle(color: Theme.water, foreground: Theme.background, compact: true))
                        .accessibilityLabel("Dinlenmeyi atla")
                }
                .padding(14)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.water.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 12)
                .onChange(of: remaining <= 0) { _, ended in
                    if ended && notifiedEnd != end {
                        notifiedEnd = end
                        if model.settings.gym.restTimerHaptics { Haptics.warning() }
                        model.skipRest()
                    }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Bitirme

struct FinishWorkoutSheet: View {
    var onFinish: (Int?, String) -> Void
    @State private var rpe: Double = 7
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Antrenmanı bitir").formaFont(.title).padding(.top, 20)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ne kadar zordu?").formaFont(.bodyMedium)
                    Spacer()
                    Text("\(Int(rpe))/10").formaFont(.numberS, Theme.lime)
                }
                Slider(value: $rpe, in: 1...10, step: 1).tint(Theme.lime)
                Text(rpeText).formaFont(.caption, Theme.textSecondary)
            }
            .cardStyle()
            TextField("Not (isteğe bağlı)", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Button("Kaydet ve bitir") { onFinish(Int(rpe), note) }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("workout.save")
            Text("Tamamlanmamış setler kaydedilmez.").formaFont(.caption, Theme.textTertiary)
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var rpeText: String {
        switch Int(rpe) {
        case ...4: return "Hafif — rahatça daha fazlasını yapabilirdin."
        case 5...6: return "Orta — iyi bir çalışma."
        case 7...8: return "Zor — son setlerde 1–3 tekrar yedeğin vardı. Gelişim için ideal."
        default: return "Çok zor — tükenişe yakın. Toparlanmaya dikkat."
        }
    }
}

struct WorkoutSummaryView: View {
    @Environment(AppModel.self) private var model
    var result: AppModel.WorkoutResult
    var onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tebrikler!").eyebrow(Theme.lime)
                    Text(result.session.title + " tamamlandı").formaFont(.display).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 40)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(label: "Süre", value: Fmt.minutes(result.session.duration), symbol: "clock")
                    StatTile(label: "Hacim", value: Fmt.int(result.session.totalVolume), unit: "kg", color: Theme.lime, symbol: "scalemass")
                    StatTile(label: "Set", value: "\(result.session.completedSetCount)", symbol: "square.stack.3d.up")
                    StatTile(label: "XP", value: "+\(result.xpGained)", color: Theme.gold, symbol: "star.fill")
                }
                if let prev = result.previousVolume, prev > 0 {
                    let change = (result.session.totalVolume - prev) / prev * 100
                    Label("Geçen seferki aynı güne göre hacim \(change >= 0 ? "+" : "")\(Int(change.rounded()))%",
                          systemImage: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .formaFont(.callout, change >= 0 ? Theme.lime : Theme.textSecondary)
                }
                if !result.records.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Yeni rekorlar", systemImage: "trophy.fill").formaFont(.headline, Theme.gold)
                        ForEach(result.records) { r in
                            HStack {
                                Text(model.exercise(r.exerciseID)?.name ?? "").formaFont(.callout)
                                Spacer()
                                Text(r.kind == .bestEstimated1RM ? "1RM ~\(Fmt.kg(r.value)) kg" : "\(Fmt.kg(r.weightKg)) kg × \(r.reps)")
                                    .formaFont(.callout, Theme.gold)
                            }
                        }
                    }
                    .cardStyle(background: Theme.gold.opacity(0.1))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Şimdi ne yapmalı?", systemImage: "sparkles").formaFont(.headline)
                    let remaining = max(0, model.targets.proteinG - model.todayMacros.protein)
                    Text("• Önümüzdeki birkaç saat içinde \(Fmt.int(NutritionEngine.perMealProtein(weightKg: model.latestWeight))) g protein içeren bir öğün ye (bugün kalan: \(Fmt.int(remaining)) g).")
                    Text("• Ter kaybını telafi etmek için 500 ml civarı su iç.")
                    Text("• Çalışan kaslar 48–72 saat içinde toparlanır; harita bunu takip ediyor.")
                }
                .formaFont(.caption, Theme.textSecondary)
                .cardStyle()
                Button("Tamam", action: onClose).buttonStyle(PrimaryButtonStyle())
                    .accessibilityIdentifier("summary.done")
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Alternatifler

struct AlternativesView: View {
    @Environment(AppModel.self) private var model
    var index: Int
    var onDone: () -> Void

    var body: some View {
        let current = model.activeWorkout?.exercises[safe: index].flatMap { model.exercise($0.exerciseID) }
        let alternatives = model.allExercises.filter { ex in
            guard let current, ex.id != current.id else { return false }
            return ex.primary.first == current.primary.first && ex.isAvailable(with: model.profile.equipment)
        }
        List {
            Section {
                ForEach(alternatives) { ex in
                    Button {
                        model.replaceExercise(at: index, with: ex)
                        onDone()
                    } label: {
                        HStack(spacing: 12) {
                            ExerciseAnimationView(exercise: ex, cornerRadius: 10, animated: false).frame(width: 64, height: 48)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).formaFont(.callout)
                                Text(ex.equipment.map(\.displayName).joined(separator: ", ")).formaFont(.caption, Theme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            } footer: {
                Text("Makine doluysa aynı kası çalıştıran başka bir hareketle değiştir.").formaFont(.caption, Theme.textTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Alternatifler")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Plaka hesaplayıcı

struct PlateCalculatorView: View {
    @Environment(AppModel.self) private var model
    @State var initialWeight: Double
    @State private var weight: Double = 60

    var body: some View {
        let gym = model.settings.gym
        let result = StrengthMath.plates(target: weight, bar: gym.barWeightKg, available: gym.plates)
        VStack(alignment: .leading, spacing: 18) {
            Text("Plaka hesaplayıcı").formaFont(.title).padding(.top, 20)
            NumberStepper(title: "Hedef", value: $weight, step: 2.5, range: gym.barWeightKg...400, unit: "kg")
            Text("Bar \(Fmt.kg(gym.barWeightKg)) kg · Her tarafa:").formaFont(.caption, Theme.textSecondary)
            HStack(alignment: .center, spacing: 3) {
                Rectangle().fill(Theme.textTertiary).frame(width: 40, height: 8)
                ForEach(Array(result.perSide.enumerated()), id: \.offset) { _, p in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(plateColor(p))
                        .frame(width: 14, height: 40 + CGFloat(p) * 3)
                        .overlay(Text(Fmt.kg(p)).font(.forma(.micro)).foregroundStyle(.white).rotationEffect(.degrees(-90)).fixedSize())
                }
                Rectangle().fill(Theme.textTertiary).frame(width: 20, height: 8)
                Spacer()
            }
            .frame(height: 130)
            Text(result.perSide.isEmpty ? "Sadece bar" : result.perSide.map(Fmt.kg).joined(separator: " + ") + " kg")
                .formaFont(.bodyMedium)
            if result.remainder > 0.01 {
                Text("Mevcut plakalarla en yakın: \(Fmt.kg(result.achievable)) kg").formaFont(.caption, Theme.energy)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .onAppear { weight = max(gym.barWeightKg, initialWeight) }
    }

    private func plateColor(_ p: Double) -> Color {
        switch p {
        case 25...: return Color(hex: 0xD84B3E)
        case 20..<25: return Color(hex: 0x2F6FD6)
        case 15..<20: return Color(hex: 0xE2B33C)
        case 10..<15: return Color(hex: 0x3E9B4F)
        default: return Color(hex: 0x6E7782)
        }
    }
}
