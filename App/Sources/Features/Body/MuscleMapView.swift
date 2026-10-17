import SwiftUI
import FormaKit

/// Önden ve arkadan stilize kas haritası.
struct MuscleMapView: View {
    enum Side { case front, back }

    enum Mode {
        case recovery
        case volume
        case selection(Set<MuscleGroup>)
        case highlight(primary: [MuscleGroup], secondary: [MuscleGroup])
    }

    @Environment(AppModel.self) private var model
    var side: Side
    var mode: Mode
    var compact = false
    var onTap: ((MuscleGroup) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let fit = BodyGeometry.fit(in: geo.size)
            let colors = fillColors()
            Canvas { ctx, _ in
                ctx.translateBy(x: fit.origin.x, y: fit.origin.y)
                ctx.scaleBy(x: fit.scale, y: fit.scale)
                let base = BodyGeometry.base(side)
                ctx.fill(base, with: .color(Theme.surfaceHigh))
                for region in BodyGeometry.regions(side) {
                    let color = colors[region.muscle] ?? Theme.surfaceHigh
                    ctx.fill(region.path, with: .color(color))
                    if !compact {
                        ctx.stroke(region.path, with: .color(Theme.background.opacity(0.85)), lineWidth: 1.4)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard let onTap else { return }
                let p = CGPoint(x: (location.x - fit.origin.x) / fit.scale, y: (location.y - fit.origin.y) / fit.scale)
                if let hit = BodyGeometry.regions(side).last(where: { $0.path.contains(p) }) {
                    Haptics.selection()
                    onTap(hit.muscle)
                }
            }
        }
        .aspectRatio(BodyGeometry.size.width / BodyGeometry.size.height, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(side == .front ? "Önden kas haritası" : "Arkadan kas haritası")
    }

    private func fillColors() -> [MuscleGroup: Color] {
        var out: [MuscleGroup: Color] = [:]
        switch mode {
        case .recovery:
            for s in model.recovery {
                switch s.status {
                case .ready: out[s.muscle] = Theme.lime.opacity(s.lastTrained == nil ? 0.38 : 0.7)
                case .recovering: out[s.muscle] = Theme.amber
                case .fatigued: out[s.muscle] = Theme.energy
                }
            }
        case .volume:
            for v in model.weeklyVolume {
                let p = min(1, v.sets / max(1, v.target.lowerBound))
                out[v.muscle] = p <= 0 ? Theme.surfaceRaised : Theme.lime.opacity(0.18 + 0.82 * p)
            }
        case .selection(let selected):
            for m in MuscleGroup.allCases { out[m] = selected.contains(m) ? Theme.lime : Color(hex: 0x3A414B) }
        case .highlight(let primary, let secondary):
            for m in MuscleGroup.allCases { out[m] = Color(hex: 0x353B44) }
            for m in secondary { out[m] = Theme.lime.opacity(0.42) }
            for m in primary { out[m] = Theme.lime }
        }
        return out
    }
}

/// Vücut çizimi 200 × 440 birimlik bir alanda tanımlıdır; sol taraf çizilir, sağ taraf aynalanır.
enum BodyGeometry {
    static let size = CGSize(width: 200, height: 440)

    struct Region {
        var muscle: MuscleGroup
        var path: Path
    }

    struct Fit { var origin: CGPoint; var scale: CGFloat }

    static func fit(in rect: CGSize) -> Fit {
        let scale = min(rect.width / size.width, rect.height / size.height)
        return Fit(origin: CGPoint(x: (rect.width - size.width * scale) / 2, y: (rect.height - size.height * scale) / 2), scale: scale)
    }

    static func base(_ side: MuscleMapView.Side) -> Path { side == .front ? frontBase : backBase }
    static func regions(_ side: MuscleMapView.Side) -> [Region] { side == .front ? frontRegions : backRegions }

    // MARK: Yardımcılar

    private static func pts(_ xy: [(CGFloat, CGFloat)]) -> [CGPoint] { xy.map { CGPoint(x: $0.0, y: $0.1) } }

    /// Noktalardan yumuşak, kapalı bir şekil (köşeler kontrol noktası olur).
    static func smooth(_ xy: [(CGFloat, CGFloat)]) -> Path {
        let p = pts(xy)
        var path = Path()
        guard p.count > 2 else { return path }
        let mids = (0..<p.count).map { i -> CGPoint in
            let a = p[i], b = p[(i + 1) % p.count]
            return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        path.move(to: mids[p.count - 1])
        for i in 0..<p.count { path.addQuadCurve(to: mids[i], control: p[i]) }
        path.closeSubpath()
        return path
    }

    private static let mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 200, ty: 0)

    private static func both(_ path: Path) -> Path {
        var p = path
        p.addPath(path.applying(mirror))
        return p
    }

    private static func pair(_ muscle: MuscleGroup, _ xy: [(CGFloat, CGFloat)]) -> Region {
        Region(muscle: muscle, path: both(smooth(xy)))
    }

    private static func pairRect(_ muscle: MuscleGroup, _ rects: [CGRect], radius: CGFloat) -> Region {
        var p = Path()
        for r in rects { p.addRoundedRect(in: r, cornerSize: CGSize(width: radius, height: radius), style: .continuous) }
        return Region(muscle: muscle, path: both(p))
    }

    // MARK: Taban siluet

    private static var commonLimbs: Path {
        var p = Path()
        p.addPath(smooth([(54, 76), (44, 90), (40, 120), (42, 142), (54, 146), (60, 120), (62, 96)]))      // üst kol
        p.addPath(smooth([(42, 140), (34, 170), (30, 204), (40, 208), (48, 178), (55, 146)]))                // ön kol
        p.addEllipse(in: CGRect(x: 26, y: 204, width: 15, height: 23))                                         // el
        p.addPath(smooth([(70, 224), (65, 262), (70, 302), (76, 328), (97, 328), (99, 290), (100, 238)]))    // uyluk
        p.addEllipse(in: CGRect(x: 74, y: 322, width: 24, height: 20))                                         // diz
        p.addPath(smooth([(74, 338), (70, 372), (77, 412), (93, 413), (97, 372), (97, 340)]))                // baldır kemiği
        p.addPath(smooth([(78, 408), (70, 428), (98, 430), (95, 408)]))                                       // ayak
        return both(p)
    }

    private static let torso: Path = smooth([
        (92, 58), (70, 64), (55, 72), (51, 92), (60, 106), (66, 140), (70, 180), (67, 214), (72, 234), (100, 242),
        (128, 234), (133, 214), (130, 180), (134, 140), (140, 106), (149, 92), (145, 72), (130, 64), (108, 58)
    ])

    static let frontBase: Path = {
        var p = Path()
        p.addEllipse(in: CGRect(x: 83, y: 8, width: 34, height: 44))
        p.addRoundedRect(in: CGRect(x: 90, y: 44, width: 20, height: 20), cornerSize: CGSize(width: 6, height: 6))
        p.addPath(torso)
        p.addPath(commonLimbs)
        return p
    }()

    static let backBase: Path = frontBase

    // MARK: Önden kaslar

    static let frontRegions: [Region] = [
        pair(.traps, [(93, 55), (82, 62), (70, 67), (90, 66)]),
        pair(.sideDelts, [(57, 73), (49, 84), (51, 98), (57, 96), (60, 82)]),
        pair(.frontDelts, [(71, 67), (59, 73), (55, 88), (60, 97), (68, 90), (75, 76)]),
        pair(.chest, [(98, 70), (77, 71), (66, 83), (68, 98), (80, 107), (98, 107)]),
        pair(.biceps, [(57, 98), (49, 105), (46, 124), (50, 139), (56, 137), (61, 116)]),
        pair(.forearms, [(48, 147), (40, 161), (35, 190), (41, 201), (48, 177), (54, 151)]),
        pairRect(.abs, [CGRect(x: 88, y: 111, width: 11, height: 21), CGRect(x: 88, y: 135, width: 11, height: 22),
                        CGRect(x: 88, y: 160, width: 11, height: 26), CGRect(x: 89, y: 189, width: 10, height: 24)], radius: 4),
        pair(.obliques, [(85, 112), (75, 116), (72, 150), (74, 186), (84, 198), (86, 150)]),
        pair(.quads, [(74, 234), (69, 262), (73, 300), (80, 321), (92, 320), (96, 292), (94, 252), (87, 238)]),
        pair(.adductors, [(97, 242), (92, 254), (94, 283), (99, 289), (100, 252)]),
        pair(.calves, [(76, 346), (73, 370), (79, 398), (86, 396), (85, 368), (83, 347)])
    ]

    // MARK: Arkadan kaslar

    static let backRegions: [Region] = [
        pair(.traps, [(100, 50), (92, 55), (73, 67), (83, 76), (93, 92), (100, 104)]),
        pair(.sideDelts, [(57, 73), (49, 84), (51, 98), (57, 96), (60, 82)]),
        pair(.rearDelts, [(71, 68), (59, 73), (54, 88), (60, 96), (70, 86)]),
        pair(.upperBack, [(97, 80), (85, 81), (79, 100), (86, 124), (97, 132)]),
        pair(.lats, [(78, 86), (65, 97), (62, 124), (70, 160), (84, 178), (90, 150), (83, 122)]),
        pair(.lowerBack, [(99, 140), (92, 142), (89, 180), (93, 208), (99, 211)]),
        pair(.triceps, [(57, 98), (47, 105), (43, 126), (47, 141), (56, 139), (61, 118)]),
        pair(.forearms, [(48, 147), (40, 161), (35, 190), (41, 201), (48, 177), (54, 151)]),
        pair(.glutes, [(100, 215), (85, 212), (72, 225), (72, 253), (86, 267), (100, 263)]),
        pair(.hamstrings, [(75, 270), (72, 297), (78, 323), (92, 323), (98, 297), (96, 271)]),
        pair(.calves, [(77, 343), (72, 362), (76, 391), (84, 399), (93, 387), (95, 361), (90, 343)])
    ]
}

// MARK: - Toparlanma ekranı

struct RecoveryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var selected: MuscleGroup?
    @State private var showInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Görünüm", selection: $mode) {
                    Text("Toparlanma").tag(0)
                    Text("Haftalık set").tag(1)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    VStack(spacing: 6) {
                        MuscleMapView(side: .front, mode: mode == 0 ? .recovery : .volume) { selected = $0 }
                        Text("Ön").eyebrow()
                    }
                    VStack(spacing: 6) {
                        MuscleMapView(side: .back, mode: mode == 0 ? .recovery : .volume) { selected = $0 }
                        Text("Arka").eyebrow()
                    }
                }
                .frame(height: 360)
                .cardStyle()

                legend

                if let m = selected { muscleDetail(m) }

                if mode == 0 {
                    VStack(spacing: 10) {
                        ForEach(model.recovery.sorted { $0.percent < $1.percent }) { s in
                            Button { selected = s.muscle } label: { recoveryRow(s) }.buttonStyle(.plain)
                        }
                    }
                    .cardStyle()
                } else {
                    VStack(spacing: 12) {
                        ForEach(model.weeklyVolume.filter { $0.target.lowerBound >= 4 }) { v in
                            volumeRow(v)
                        }
                    }
                    .cardStyle()
                }

                Button { showInfo = true } label: {
                    Label("Bu harita nasıl hesaplanıyor?", systemImage: "info.circle")
                        .formaFont(.callout, Theme.textSecondary)
                }
                .padding(.bottom, 20)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Kas haritası")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Kapat") { dismiss() }.foregroundStyle(Theme.lime) } }
        .sheet(isPresented: $showInfo) {
            NavigationStack { ArticleView(article: LearnLibrary.article("recovery-map")!) }
                .presentationBackground(Theme.background)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            if mode == 0 {
                legendDot(Theme.lime.opacity(0.7), "Hazır")
                legendDot(Theme.amber, "Toparlanıyor")
                legendDot(Theme.energy, "Yorgun")
            } else {
                legendDot(Theme.surfaceRaised, "Hiç")
                legendDot(Theme.lime.opacity(0.5), "Yarısı")
                legendDot(Theme.lime, "Hedefte")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func legendDot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(c).frame(width: 10, height: 10)
            Text(t).formaFont(.caption, Theme.textSecondary)
        }
    }

    private func recoveryRow(_ s: RecoveryEngine.MuscleState) -> some View {
        HStack(spacing: 12) {
            Text(s.muscle.displayName).formaFont(.callout).frame(width: 90, alignment: .leading)
            BarView(progress: s.percent / 100, color: Theme.recoveryColor(s.percent), height: 8)
            Text("%\(Int(s.percent))").formaFont(.callout, Theme.textSecondary).frame(width: 44, alignment: .trailing).monospacedDigit()
        }
        .contentShape(Rectangle())
    }

    private func volumeRow(_ v: VolumeEngine.MuscleVolume) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(v.muscle.displayName).formaFont(.callout)
                if model.profile.focusMuscles.contains(v.muscle) {
                    Text("ODAK").font(.forma(.micro)).foregroundStyle(Theme.onLime).padding(.horizontal, 6).padding(.vertical, 2).background(Theme.lime, in: Capsule())
                }
                Spacer()
                Text("\(Fmt.oneDecimal(v.sets)) / \(Int(v.target.lowerBound))–\(Int(v.target.upperBound)) set").formaFont(.caption, Theme.textSecondary)
            }
            BarView(progress: v.sets / max(1, v.target.lowerBound), color: v.status == .below ? Theme.amber : Theme.lime, height: 6)
        }
    }

    @ViewBuilder private func muscleDetail(_ m: MuscleGroup) -> some View {
        let s = model.recovery(of: m)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(m.displayName).formaFont(.headline)
                Spacer()
                if let s { Text("%\(Int(s.percent))").formaFont(.numberM, Theme.recoveryColor(s.percent)) }
            }
            if let s {
                if let last = s.lastTrained {
                    Text("Son çalışma: \(Fmt.relativeDay(last))").formaFont(.caption, Theme.textSecondary)
                }
                if s.hoursUntilReady > 1 {
                    Text("Yaklaşık \(Int(s.hoursUntilReady.rounded())) saat sonra hazır.").formaFont(.caption, Theme.textSecondary)
                }
            }
            Text("Ağrı var mı? Haritayı düzeltmek için işaretle.").formaFont(.caption, Theme.textTertiary)
            HStack(spacing: 8) {
                ForEach(0...3, id: \.self) { level in
                    let current = model.data.soreness.last(where: { $0.muscle == m && Calendar.forma.isDateInToday($0.date) })?.level ?? 0
                    Chip(title: ["Yok", "Hafif", "Orta", "Çok"][level], isOn: current == level) { model.logSoreness(m, level: level) }
                }
            }
            let exercises = ExerciseCatalog.exercises(for: m).filter { $0.isAvailable(with: model.profile.equipment) }.prefix(4)
            if !exercises.isEmpty {
                Text("Bu bölge için hareketler").eyebrow().padding(.top, 4)
                ForEach(Array(exercises)) { ex in
                    NavigationLink { ExerciseDetailView(exercise: ex) } label: {
                        HStack {
                            Text(ex.name).formaFont(.callout)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
        }
        .cardStyle(background: Theme.surfaceRaised)
    }
}
