import WidgetKit
import SwiftUI
import AppIntents
import FormaKit

@main
struct FormaWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        RingsWidget()
        NextWorkoutWidget()
        WorkoutLiveActivity()
        if #available(iOSApplicationExtension 18.0, *) {
            WaterControl()
            CreatineControl()
        }
    }
}

// MARK: - Zaman çizelgesi

struct SnapshotEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
    var isPlaceholder = false
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .preview, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: context.isPreview ? .preview : current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: current())
        // Gece yarısı sıfırlanması için ertesi günün başında yenile
        let cal = Calendar.forma
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date().addingTimeInterval(3600)
        let next = min(tomorrow, Date().addingTimeInterval(30 * 60))
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func current() -> SnapshotEntry.Snapshot {
        let storage = AppConfig.storage
        let today = DayKey.key(Date())
        guard var snap = storage.readSnapshot() else { return .empty(day: today) }
        if snap.day != today {
            // Yeni gün: sayaçları sıfırla, hedefleri koru
            snap = WidgetSnapshot(day: today, generatedAt: Date(), targets: snap.targets, kcal: 0, protein: 0, waterMl: 0,
                                  supplements: snap.supplements.map { var s = $0; s.taken = false; return s },
                                  nextWorkoutTitle: snap.nextWorkoutTitle, nextWorkoutFocus: snap.nextWorkoutFocus,
                                  nextWorkoutMinutes: snap.nextWorkoutMinutes, trainedToday: false, creatineStreak: snap.creatineStreak,
                                  weekWorkouts: snap.weekWorkouts, weekTarget: snap.weekTarget, level: snap.level,
                                  levelProgress: snap.levelProgress, readiness: nil)
        }
        return snap.applying(storage.pendingEvents().map(\.1))
    }
}

extension SnapshotEntry {
    typealias Snapshot = WidgetSnapshot
}

extension WidgetSnapshot {
    static func empty(day: String) -> WidgetSnapshot {
        WidgetSnapshot(day: day, generatedAt: Date(), targets: .placeholder, kcal: 0, protein: 0, waterMl: 0, supplements: [],
                       nextWorkoutTitle: nil, nextWorkoutFocus: nil, nextWorkoutMinutes: nil, trainedToday: false, creatineStreak: 0,
                       weekWorkouts: 0, weekTarget: 3, level: 1, levelProgress: 0, readiness: nil)
    }
}

// MARK: - Renkler

enum WTheme {
    static let bg = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let surface = Color(red: 0.09, green: 0.10, blue: 0.12)
    static let track = Color(red: 0.165, green: 0.184, blue: 0.216)
    static let text = Color(red: 0.953, green: 0.945, blue: 0.918)
    static let secondary = Color(red: 0.655, green: 0.69, blue: 0.729)
    static let lime = Color(red: 0.776, green: 0.949, blue: 0.306)
    static let onLime = Color(red: 0.07, green: 0.08, blue: 0.04)
    static let water = Color(red: 0.353, green: 0.69, blue: 1.0)
    static let energy = Color(red: 1.0, green: 0.608, blue: 0.29)
    static let violet = Color(red: 0.725, green: 0.651, blue: 1.0)

    static func display(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Bold", size: size) }
    static func body(_ size: CGFloat, _ weight: String = "Medium") -> Font { .custom("DMSans-\(weight)", size: size) }
}

struct MiniRing: View {
    var progress: Double
    var color: Color
    var width: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().stroke(WTheme.track, lineWidth: width)
            Circle().trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Bugün widget'ı (etkileşimli)

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.WidgetKind.today, provider: SnapshotProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(WTheme.bg, for: .widget)
        }
        .configurationDisplayName("Bugün")
        .description("Protein, su ve takviyeler; tek dokunuşla su ve kreatin ekle.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SnapshotEntry

    private var s: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemLarge: large
        default: medium
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    MiniRing(progress: s.waterMl / max(1, s.targets.waterMl), color: WTheme.water, width: 6)
                    MiniRing(progress: s.protein / max(1, s.targets.proteinG), color: WTheme.lime, width: 6).padding(9)
                }
                .frame(width: 52, height: 52)
                Spacer()
                if let c = s.supplements.first(where: { $0.kind == .creatine }) {
                    Image(systemName: c.taken ? "bolt.circle.fill" : "bolt.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(c.taken ? WTheme.lime : WTheme.secondary)
                }
            }
            Spacer(minLength: 0)
            Text("\(Int(s.protein)) g").font(WTheme.display(20)).foregroundStyle(WTheme.lime)
            + Text(" protein").font(WTheme.body(11)).foregroundStyle(WTheme.secondary)
            Text(String(format: "%.1f L", s.waterMl / 1000).replacingOccurrences(of: ".", with: ",")).font(WTheme.display(16)).foregroundStyle(WTheme.water)
            Button(intent: LogWaterIntent(ml: 250)) {
                Label("250 ml", systemImage: "plus")
                    .font(WTheme.body(12, "SemiBold"))
                    .frame(maxWidth: .infinity)
            }
            .tint(WTheme.water)
            .buttonStyle(.borderedProminent)
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                row(label: "Protein", value: "\(Int(s.protein))/\(Int(s.targets.proteinG)) g", progress: s.protein / max(1, s.targets.proteinG), color: WTheme.lime)
                row(label: "Su", value: String(format: "%.1f/%.1f L", s.waterMl / 1000, s.targets.waterMl / 1000).replacingOccurrences(of: ".", with: ","),
                    progress: s.waterMl / max(1, s.targets.waterMl), color: WTheme.water)
                row(label: "Kalori", value: "\(Int(s.kcal))/\(Int(s.targets.kcal))", progress: s.kcal / max(1, s.targets.kcal), color: WTheme.energy)
            }
            VStack(spacing: 8) {
                Button(intent: LogWaterIntent(ml: 250)) {
                    Label("+250 ml", systemImage: "drop.fill").font(WTheme.body(12, "SemiBold")).frame(maxWidth: .infinity)
                }
                .tint(WTheme.water)
                .buttonStyle(.borderedProminent)
                if let c = s.supplements.first(where: { $0.kind == .creatine }) {
                    Button(intent: TakeSupplementIntent(supplementID: c.id, kind: c.kind)) {
                        Label(c.taken ? "Kreatin ✓" : "Kreatin", systemImage: "bolt.fill").font(WTheme.body(12, "SemiBold")).frame(maxWidth: .infinity)
                    }
                    .tint(c.taken ? WTheme.track : WTheme.lime)
                    .foregroundStyle(c.taken ? WTheme.lime : WTheme.onLime)
                    .buttonStyle(.borderedProminent)
                    .disabled(c.taken)
                }
                if s.creatineStreak > 1 {
                    Text("🔥 \(s.creatineStreak) gün").font(WTheme.body(11)).foregroundStyle(WTheme.energy)
                }
            }
            .frame(width: 112)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Bugün").font(WTheme.display(20)).foregroundStyle(WTheme.text)
                Spacer()
                Text("Sv. \(s.level)").font(WTheme.body(12, "SemiBold")).foregroundStyle(WTheme.lime)
            }
            medium
            Divider().overlay(WTheme.track)
            Text("Takviyeler").font(WTheme.body(12, "SemiBold")).foregroundStyle(WTheme.secondary)
            HStack(spacing: 8) {
                ForEach(s.supplements.prefix(3)) { item in
                    Button(intent: TakeSupplementIntent(supplementID: item.id, kind: item.kind)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Image(systemName: item.taken ? "checkmark.circle.fill" : "circle")
                            Text(item.name).font(WTheme.body(11, "SemiBold")).lineLimit(1)
                            Text(item.dose).font(WTheme.body(10)).foregroundStyle(WTheme.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(item.taken ? WTheme.lime : WTheme.text)
                    .padding(8)
                    .background(WTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    .disabled(item.taken)
                }
            }
            Spacer(minLength: 0)
            if let title = s.nextWorkoutTitle, !s.trainedToday {
                Link(destination: URL(string: "forma://workout/start")!) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(WTheme.display(15)).foregroundStyle(WTheme.onLime)
                            Text(s.nextWorkoutFocus ?? "").font(WTheme.body(11)).foregroundStyle(WTheme.onLime.opacity(0.7)).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "play.fill").foregroundStyle(WTheme.onLime)
                    }
                    .padding(12)
                    .background(WTheme.lime, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func row(label: String, value: String, progress: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(WTheme.body(11)).foregroundStyle(WTheme.secondary)
                Spacer()
                Text(value).font(WTheme.body(11, "SemiBold")).foregroundStyle(WTheme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(WTheme.track)
                    Capsule().fill(color).frame(width: max(4, geo.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Kilit ekranı halkaları

struct RingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.WidgetKind.rings, provider: SnapshotProvider()) { entry in
            RingsWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Halkalar")
        .description("Kilit ekranında su ve protein.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct RingsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: SnapshotEntry

    var body: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryCircular:
            Gauge(value: min(1, s.waterMl / max(1, s.targets.waterMl))) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text(String(format: "%.1f", s.waterMl / 1000).replacingOccurrences(of: ".", with: ","))
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()
        case .accessoryInline:
            Text("💧 \(String(format: "%.1f", s.waterMl / 1000)) L · 🥩 \(Int(s.protein)) g")
        default:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                    Text(String(format: "%.1f / %.1f L", s.waterMl / 1000, s.targets.waterMl / 1000).replacingOccurrences(of: ".", with: ","))
                }
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                    Text("\(Int(s.protein)) / \(Int(s.targets.proteinG)) g")
                }
                if let c = s.supplements.first(where: { $0.kind == .creatine }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text(c.taken ? "Kreatin alındı" : "Kreatin bekliyor")
                    }
                }
            }
            .font(.system(size: 13, weight: .medium))
            .widgetAccentable()
        }
    }
}

// MARK: - Sıradaki antrenman

struct NextWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.WidgetKind.next, provider: SnapshotProvider()) { entry in
            NextWorkoutView(entry: entry)
                .containerBackground(WTheme.lime, for: .widget)
                .widgetURL(URL(string: "forma://workout/start"))
        }
        .configurationDisplayName("Sıradaki antrenman")
        .description("Bugünün antrenmanı ve haftalık ilerleme.")
        .supportedFamilies([.systemSmall])
    }
}

struct NextWorkoutView: View {
    var entry: SnapshotEntry

    var body: some View {
        let s = entry.snapshot
        VStack(alignment: .leading, spacing: 6) {
            Text(s.trainedToday ? "Bugün tamam" : "Bugün").font(WTheme.body(11, "SemiBold")).foregroundStyle(WTheme.onLime.opacity(0.7))
            Text(s.trainedToday ? "Dinlen ve toparlan" : (s.nextWorkoutTitle ?? "Antrenman"))
                .font(WTheme.display(18)).foregroundStyle(WTheme.onLime).lineLimit(2)
            if let f = s.nextWorkoutFocus, !s.trainedToday {
                Text(f).font(WTheme.body(11)).foregroundStyle(WTheme.onLime.opacity(0.75)).lineLimit(2)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                ForEach(0..<max(1, s.weekTarget), id: \.self) { i in
                    Capsule().fill(i < s.weekWorkouts ? WTheme.onLime : WTheme.onLime.opacity(0.2)).frame(height: 6)
                }
            }
            Text("Bu hafta \(s.weekWorkouts)/\(s.weekTarget)").font(WTheme.body(10, "SemiBold")).foregroundStyle(WTheme.onLime)
        }
    }
}

// MARK: - Denetim Merkezi

@available(iOSApplicationExtension 18.0, *)
struct WaterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "forma.control.water") {
            ControlWidgetButton(action: LogWaterIntent(ml: 250)) {
                Label("+250 ml su", systemImage: "drop.fill")
            }
        }
        .displayName("Su ekle")
        .description("Forma'ya 250 ml su ekler.")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct CreatineControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "forma.control.creatine") {
            ControlWidgetButton(action: TakeCreatineIntent()) {
                Label("Kreatin aldım", systemImage: "bolt.fill")
            }
        }
        .displayName("Kreatin")
        .description("Bugünkü kreatini işaretler.")
    }
}
