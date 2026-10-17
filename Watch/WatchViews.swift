import SwiftUI
import WatchKit
import FormaKit

struct WatchRootView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        if let live = store.payload.live {
            LiveWorkoutWatchView(live: live)
        } else {
            TodayWatchView()
        }
    }
}

struct TodayWatchView: View {
    @Environment(WatchStore.self) private var store

    var body: some View {
        let p = store.payload
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ring(p.waterMl / max(1, p.waterTarget), WColor.water, String(format: "%.1f", p.waterMl / 1000).replacingOccurrences(of: ".", with: ","), "L su")
                        ring(p.protein / max(1, p.proteinTarget), WColor.lime, "\(Int(p.protein))", "g prot.")
                    }
                    HStack(spacing: 6) {
                        ForEach([250, 500], id: \.self) { ml in
                            Button { store.addWater(Double(ml)) } label: {
                                Label("\(ml)", systemImage: "drop.fill").font(.system(size: 14, weight: .semibold))
                            }
                            .tint(WColor.water)
                        }
                    }
                    ForEach(p.supplements) { s in
                        Button { store.take(s) } label: {
                            HStack {
                                Image(systemName: s.taken ? "checkmark.circle.fill" : s.kind.symbol)
                                    .foregroundStyle(s.taken ? WColor.lime : WColor.violet)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(s.name).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                    Text(s.taken ? "Alındı" : s.dose).font(.system(size: 12)).foregroundStyle(WColor.secondary)
                                }
                                Spacer()
                            }
                        }
                        .disabled(s.taken)
                    }
                    if let next = p.nextWorkout {
                        Button { store.send(["action": "startWorkout"]) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bugün").font(.system(size: 11)).foregroundStyle(WColor.onLime.opacity(0.7))
                                Text(next).font(.system(size: 15, weight: .bold)).foregroundStyle(WColor.onLime)
                                Text("Başlat").font(.system(size: 12, weight: .semibold)).foregroundStyle(WColor.onLime)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .tint(WColor.lime)
                        .buttonStyle(.borderedProminent)
                    }
                    if p.creatineStreak > 1 {
                        Text("🔥 Kreatin serisi \(p.creatineStreak) gün").font(.system(size: 12)).foregroundStyle(WColor.energy)
                    }
                    if store.lastUpdate == nil && p.day.isEmpty {
                        Text("iPhone'da Forma'yı bir kez aç.").font(.system(size: 12)).foregroundStyle(WColor.secondary).multilineTextAlignment(.center)
                    }
                }
            }
            .navigationTitle("Forma")
        }
    }

    private func ring(_ progress: Double, _ color: Color, _ value: String, _ label: String) -> some View {
        ZStack {
            Circle().stroke(WColor.track, lineWidth: 7)
            Circle().trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
                Text(label).font(.system(size: 9)).foregroundStyle(WColor.secondary)
            }
        }
        .frame(width: 72, height: 72)
    }
}

struct LiveWorkoutWatchView: View {
    @Environment(WatchStore.self) private var store
    var live: WatchPayload.Live
    private let workout = WorkoutManager.shared

    var body: some View {
        TabView {
            setPage
            infoPage
        }
        .tabViewStyle(.verticalPage)
    }

    private var setPage: some View {
        VStack(spacing: 6) {
            Text(live.exerciseName).font(.system(size: 14, weight: .semibold)).lineLimit(2).multilineTextAlignment(.center)
            if let end = live.restEndsAt, end > Date() {
                Text(timerInterval: Date()...end, countsDown: true)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(WColor.water)
                    .monospacedDigit()
                HStack {
                    Button("+15") { store.send(["action": "addRest", "seconds": 15]) }
                    Button("Atla") { store.send(["action": "skipRest"]) }.tint(WColor.water)
                }
                .font(.system(size: 14, weight: .semibold))
            } else if live.setCount > 0 {
                Text("Set \(live.setIndex)/\(live.setCount)").font(.system(size: 12)).foregroundStyle(WColor.secondary)
                Text(live.isTimed ? "\(live.reps) sn" : (live.weight > 0 ? "\(live.weight.formattedKg) kg × \(live.reps)" : "\(live.reps) tekrar"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WColor.lime)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Button { store.completeSet() } label: {
                    Image(systemName: "checkmark").font(.system(size: 26, weight: .heavy)).foregroundStyle(WColor.onLime)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .tint(WColor.lime)
                .buttonStyle(.borderedProminent)
            } else {
                Text("Tüm setler bitti 🎉").font(.system(size: 16, weight: .bold))
                Text("iPhone'dan antrenmanı bitir.").font(.system(size: 12)).foregroundStyle(WColor.secondary)
            }
        }
    }

    private var infoPage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(live.title).font(.system(size: 15, weight: .bold))
            Text(timerInterval: live.startedAt...Date.distantFuture, countsDown: false)
                .font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(WColor.lime)
            HStack {
                Image(systemName: "heart.fill").foregroundStyle(WColor.coral)
                Text(workout.heartRate > 0 ? "\(Int(workout.heartRate)) bpm" : "– bpm").font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            Text("\(live.completedSets)/\(live.totalSets) set").font(.system(size: 14)).foregroundStyle(WColor.secondary)
            if let next = live.nextExerciseName {
                Text("Sonra: \(next)").font(.system(size: 12)).foregroundStyle(WColor.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
