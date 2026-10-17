import SwiftUI
import FormaKit

struct WorkoutHomeView: View {
    @Environment(AppModel.self) private var model
    @Binding var showWorkout: Bool
    @State private var showPrograms = false
    @State private var showLibrary = false
    @State private var showRecovery = false
    @State private var dayToStart: ProgramDay?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenHeader(eyebrow: "Bu hafta \(model.sessionsThisWeek.count)/\(model.profile.trainingDaysPerWeek)", title: "Antrenman")
                    planCard
                    nextWorkoutCard
                    quickActions
                    if let program = model.currentProgram { programDays(program) }
                    weekStrip
                    history
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPrograms) { NavigationStack { ProgramPickerView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showLibrary) { NavigationStack { ExerciseLibraryView() }.presentationBackground(Theme.background) }
            .sheet(isPresented: $showRecovery) { NavigationStack { RecoveryView() }.presentationBackground(Theme.background) }
            .confirmationDialog("Bu günü başlat?", isPresented: Binding(get: { dayToStart != nil }, set: { if !$0 { dayToStart = nil } }),
                                titleVisibility: .visible, presenting: dayToStart) { day in
                Button("\(day.name) başlat") { start(day: day) }
                Button("Vazgeç", role: .cancel) {}
            }
        }
    }

    private var planCard: some View {
        Button { showPrograms = true } label: {
            HStack(spacing: 14) {
                Image(systemName: model.settings.planMode.isAuto ? "wand.and.stars" : "list.bullet.rectangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.lime)
                    .frame(width: 44, height: 44)
                    .background(Theme.lime.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Planın").eyebrow()
                    Text(model.currentProgram?.name ?? "Otomatik plan").formaFont(.bodyMedium)
                    Text(model.settings.planMode.isAuto ? "Toparlanmaya ve haftalık hacme göre her gün yeniden kurulur"
                                                        : (model.currentProgram?.summary ?? ""))
                        .formaFont(.caption, Theme.textSecondary).lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Text("Değiştir").font(.forma(.callout)).foregroundStyle(Theme.lime)
            }
            .cardStyle()
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder private var nextWorkoutCard: some View {
        let plan = model.nextPlan
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sıradaki").eyebrow()
                    Text(plan.title).formaFont(.title)
                }
                Spacer()
                Text("~\(plan.minutes) dk").formaFont(.callout, Theme.textSecondary)
            }
            ForEach(Array(plan.slots.enumerated()), id: \.offset) { index, slot in
                if let ex = slot.resolvedExercise(equipment: model.profile.equipment) ?? model.exercise(slot.exerciseID) {
                    NavigationLink {
                        ExerciseDetailView(exercise: ex)
                    } label: {
                        HStack(spacing: 12) {
                            ExerciseAnimationView(exercise: ex, cornerRadius: 12, animated: false)
                                .frame(width: 58, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).formaFont(.callout).lineLimit(1)
                                Text("\(slot.sets) × \(slot.repLow)–\(slot.repHigh)\(ex.tracking == .duration ? " sn" : "") · \(ex.primary.first?.displayName ?? "")")
                                    .formaFont(.caption, Theme.textSecondary)
                            }
                            Spacer()
                            if let last = ProgressionEngine.history(for: ex.id, in: model.finishedSessions, limit: 1).first {
                                Text(ProgressionEngine.summary(of: last, tracking: ex.tracking))
                                    .formaFont(.caption, Theme.textTertiary).lineLimit(1)
                                    .frame(maxWidth: 90, alignment: .trailing)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            ForEach(plan.rationale, id: \.self) { r in
                Label(r, systemImage: "info.circle").formaFont(.caption, Theme.textSecondary)
            }
            Button {
                if model.activeWorkout == nil { model.startWorkout(plan) }
                showWorkout = true
            } label: {
                Label(model.activeWorkout == nil ? "Antrenmana başla" : "Antrenmana dön", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("workout.start")
        }
        .cardStyle(padding: 18)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickAction("Kas haritası", "figure.arms.open", Theme.energy) { showRecovery = true }
            quickAction("Hareketler", "books.vertical.fill", Theme.water) { showLibrary = true }
            quickAction("Boş başla", "plus", Theme.supplement) {
                if model.activeWorkout == nil { model.startEmptyWorkout() }
                showWorkout = true
            }
        }
    }

    private func quickAction(_ title: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(color)
                    .frame(width: 40, height: 40).background(color.opacity(0.14), in: Circle())
                Text(title).formaFont(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func programDays(_ program: WorkoutProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Program günleri")
            ForEach(Array(program.days.enumerated()), id: \.element.id) { index, day in
                let isNext = index == model.settings.programDayIndex % max(1, program.days.count)
                Button { dayToStart = day } label: {
                    HStack {
                        Text("\(index + 1)").formaFont(.numberS, isNext ? Theme.onLime : Theme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(isNext ? Theme.lime : Theme.surfaceRaised, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.name).formaFont(.bodyMedium)
                            Text(day.focus).formaFont(.caption, Theme.textSecondary)
                        }
                        Spacer()
                        if isNext { Text("Sıradaki").font(.forma(.label)).foregroundStyle(Theme.lime) }
                    }
                    .cardStyle(padding: 12)
                }
                .buttonStyle(PressableStyle())
                .disabled(model.activeWorkout != nil)
            }
        }
    }

    private func start(day: ProgramDay) {
        let minutes = day.slots.reduce(0) { $0 + $1.sets } * 2 + 6
        model.startWorkout(PlannedWorkout(title: day.name, focus: day.focus, slots: day.slots, programID: model.currentProgram?.id,
                                          programDayID: day.id, rationale: [], minutes: minutes))
        showWorkout = true
    }

    private var weekStrip: some View {
        let cal = Calendar.forma
        let start = cal.startOfWeek(for: model.now)
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        let trained = Set(model.finishedSessions.map { DayKey.key($0.startedAt) })
        let names = ["Pt", "Sa", "Ça", "Pe", "Cu", "Ct", "Pz"]
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Bu hafta")
            HStack(spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    let done = trained.contains(DayKey.key(d))
                    let today = cal.isDateInToday(d)
                    VStack(spacing: 6) {
                        Text(names[i]).formaFont(.caption, today ? Theme.textPrimary : Theme.textTertiary)
                        ZStack {
                            Circle().fill(done ? Theme.lime : Theme.surfaceRaised)
                            if done {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.onLime)
                            } else {
                                Text("\(cal.component(.day, from: d))").formaFont(.caption, Theme.textSecondary)
                            }
                        }
                        .frame(width: 34, height: 34)
                        .overlay(Circle().strokeBorder(today ? Theme.lime : .clear, lineWidth: 1.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .cardStyle(padding: 12)
        }
    }

    @ViewBuilder private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Geçmiş")
            if model.finishedSessions.isEmpty {
                EmptyCard(symbol: "clock.arrow.circlepath", title: "Henüz antrenman yok", message: "İlk antrenmanını bitirdiğinde burada göreceksin.")
            } else {
                ForEach(model.finishedSessions.prefix(12)) { s in
                    NavigationLink { SessionDetailView(session: s) } label: { SessionRow(session: s) }
                        .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

struct SessionRow: View {
    var session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(Fmt.shortDate.string(from: session.startedAt).components(separatedBy: " ").first ?? "")
                    .formaFont(.numberS)
                Text(Fmt.shortDate.string(from: session.startedAt).components(separatedBy: " ").last ?? "")
                    .font(.forma(.micro)).foregroundStyle(Theme.textTertiary).textCase(.uppercase)
            }
            .frame(width: 44, height: 44)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).formaFont(.bodyMedium)
                Text("\(Fmt.minutes(session.duration)) · \(session.completedSetCount) set · \(Fmt.int(session.totalVolume)) kg")
                    .formaFont(.caption, Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textTertiary)
        }
        .cardStyle(padding: 12)
    }
}

struct SessionDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var session: WorkoutSession
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatTile(label: "Süre", value: Fmt.minutes(session.duration), symbol: "clock")
                    StatTile(label: "Hacim", value: Fmt.int(session.totalVolume), unit: "kg", symbol: "scalemass")
                }
                HStack(spacing: 10) {
                    StatTile(label: "Set", value: "\(session.completedSetCount)", symbol: "square.stack.3d.up")
                    if let hr = session.averageHeartRate {
                        StatTile(label: "Nabız", value: "\(Int(hr))", unit: "bpm", color: Theme.coral, symbol: "heart.fill")
                    } else if let rpe = session.sessionRPE {
                        StatTile(label: "Zorluk", value: "\(rpe)/10", symbol: "gauge.medium")
                    }
                }
                let prs = model.data.records.filter { r in session.endedAt.map { abs(r.date.timeIntervalSince($0)) < 1 } ?? false }
                if !prs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Rekorlar", systemImage: "trophy.fill").formaFont(.headline, Theme.gold)
                        ForEach(prs) { r in
                            Text("\(model.exercise(r.exerciseID)?.name ?? r.exerciseID): \(r.kind.displayName) \(Fmt.kg(r.weightKg)) kg × \(r.reps)")
                                .formaFont(.caption, Theme.textSecondary)
                        }
                    }
                    .cardStyle(background: Theme.gold.opacity(0.1))
                }
                ForEach(session.exercises) { se in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.exercise(se.exerciseID)?.name ?? se.exerciseID).formaFont(.bodyMedium)
                        ForEach(Array(se.sets.enumerated()), id: \.element.id) { i, set in
                            HStack {
                                Text(set.kind == .warmup ? "I" : "\(i + 1)").formaFont(.caption, Theme.textTertiary).frame(width: 20)
                                if model.exercise(se.exerciseID)?.tracking == .duration {
                                    Text("\(set.seconds) sn").formaFont(.callout)
                                } else {
                                    Text("\(Fmt.kg(set.weightKg)) kg × \(set.reps)").formaFont(.callout)
                                }
                                Spacer()
                                if let rir = set.rir { Text("RIR \(rir)").formaFont(.caption, Theme.textTertiary) }
                            }
                        }
                        if !se.note.isEmpty { Text(se.note).formaFont(.caption, Theme.textSecondary) }
                    }
                    .cardStyle()
                }
                if !session.note.isEmpty {
                    Text(session.note).formaFont(.body, Theme.textSecondary).cardStyle()
                }
                Button("Antrenmanı sil", role: .destructive) { confirmDelete = true }
                    .formaFont(.callout, Theme.coral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .screenBackground()
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Bu antrenman silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                model.deleteSession(session.id)
                dismiss()
            }
        }
    }
}
