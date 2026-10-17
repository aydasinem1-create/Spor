import SwiftUI
import FormaKit

// MARK: - Halka

struct RingView: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 10
    var track: Color = Theme.surfaceHigh

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.75), color], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(0.05, min(progress, 1)))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if progress > 1 {
                // Hedef aşıldıysa ikinci tur ince bir parıltı
                Circle()
                    .trim(from: 0, to: min(progress - 1, 1))
                    .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: lineWidth * 0.45, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: progress)
    }
}

// MARK: - Çubuk

struct BarView: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 8
    var track: Color = Theme.surfaceHigh

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(max(progress, 0), 1)))
                    .opacity(progress <= 0 ? 0 : 1)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }
}

struct MacroRow: View {
    var label: String
    var value: Double
    var target: Double
    var unit: String = "g"
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).formaFont(.callout, Theme.textSecondary)
                Spacer()
                (Text(Fmt.int(value)).font(.forma(.numberS)).foregroundStyle(Theme.textPrimary)
                 + Text(" / \(Fmt.int(target)) \(unit)").font(.forma(.caption)).foregroundStyle(Theme.textTertiary))
            }
            BarView(progress: target > 0 ? value / target : 0, color: color)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Düğmeler

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.lime
    var foreground: Color = Theme.onLime
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.forma(compact ? .callout : .bodyMedium))
            .fontWeight(.semibold)
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? 16 : 22)
            .padding(.vertical, compact ? 9 : 15)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(color, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.forma(compact ? .callout : .bodyMedium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 9 : 14)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(Theme.surfaceRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconButton: View {
    var systemName: String
    var size: CGFloat = 36
    var tint: Color = Theme.textPrimary
    var background: Color = Theme.surfaceRaised
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(background, in: Circle())
        }
        .buttonStyle(PressableStyle())
    }
}

struct Chip: View {
    var title: String
    var systemImage: String? = nil
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .semibold)) }
                Text(title).font(.forma(.callout))
            }
            .foregroundStyle(isOn ? Theme.onLime : Theme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isOn ? Theme.lime : Theme.surfaceRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Başlıklar

struct ScreenHeader<Trailing: View>: View {
    var eyebrow: String
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow).eyebrow()
                Text(title).formaFont(.display)
            }
            Spacer()
            trailing
        }
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = EmptyView()
    }
}

struct SectionTitle: View {
    var title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title).formaFont(.headline)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.forma(.callout))
                    .foregroundStyle(Theme.lime)
            }
        }
        .padding(.top, 8)
    }
}

struct StatTile: View {
    var label: String
    var value: String
    var unit: String? = nil
    var color: Color = Theme.textPrimary
    var symbol: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(color) }
                Text(label).eyebrow()
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).formaFont(.numberM, color)
                if let unit { Text(unit).formaFont(.caption, Theme.textSecondary) }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .cardStyle(padding: 14)
    }
}

struct EmptyCard: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            Text(title).formaFont(.bodyMedium)
            Text(message).formaFont(.caption, Theme.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }
}

// MARK: - Hareket görseli (başlangıç ↔ bitiş pozisyonu)

final class ExerciseImageCache {
    static let shared = ExerciseImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(datasetID: String, frame: Int) -> UIImage? {
        let name = "\(datasetID)_\(frame)"
        if let img = cache.object(forKey: name as NSString) { return img }
        let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "ExerciseImages")
            ?? Bundle.main.url(forResource: name, withExtension: "jpg")
        guard let url, let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }
}

/// Hareketin başlangıç ve bitiş fotoğraflarını sırayla göstererek hareketi canlandırır.
struct ExerciseAnimationView: View {
    var exercise: Exercise
    var cornerRadius: CGFloat = 18
    var animated = true
    @State private var frame = 0
    @State private var isPaused = false

    private var datasetID: String? { exercise.datasetIDs.first }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.surfaceRaised
            if let id = datasetID, let first = ExerciseImageCache.shared.image(datasetID: id, frame: 0) {
                let second = ExerciseImageCache.shared.image(datasetID: id, frame: 1) ?? first
                ZStack {
                    Image(uiImage: first).resizable().scaledToFill().opacity(frame == 0 ? 1 : 0)
                    Image(uiImage: second).resizable().scaledToFill().opacity(frame == 1 ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.45), value: frame)
                .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                HStack(spacing: 6) {
                    Circle().fill(frame == 0 ? Theme.lime : Color.white.opacity(0.4)).frame(width: 6, height: 6)
                    Circle().fill(frame == 1 ? Theme.lime : Color.white.opacity(0.4)).frame(width: 6, height: 6)
                    Text(frame == 0 ? "Başlangıç" : "Bitiş").font(.forma(.micro)).foregroundStyle(.white)
                    Spacer()
                    if animated {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(10)
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            if animated { isPaused.toggle() } else { frame = 1 - frame }
        }
        .task(id: "\(exercise.id)-\(isPaused)") {
            guard animated, !isPaused else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if Task.isCancelled { break }
                frame = 1 - frame
            }
        }
        .accessibilityLabel("\(exercise.name) hareket görseli")
    }
}

// MARK: - Kutlama

struct ConfettiView: View {
    var colors: [Color] = [Theme.lime, Theme.gold, Theme.water, Theme.energy, Theme.supplement]
    @State private var start = Date()

    private struct Piece {
        var x: Double, speed: Double, drift: Double, spin: Double, size: Double, colorIndex: Int, delay: Double
    }

    @State private var pieces: [Piece] = (0..<70).map { _ in
        Piece(x: .random(in: 0...1), speed: .random(in: 180...420), drift: .random(in: -60...60),
              spin: .random(in: 2...8), size: .random(in: 5...10), colorIndex: .random(in: 0..<5), delay: .random(in: 0...0.4))
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let lt = t - p.delay
                    guard lt > 0 else { continue }
                    let y = -20 + lt * p.speed
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(lt * 2) * p.drift
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(lt * p.spin))
                    c.opacity = max(0, 1 - lt / 2.6)
                    c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                           with: .color(colors[p.colorIndex % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear { start = Date() }
    }
}

struct ToastView: View {
    var symbol: String
    var title: String
    var subtitle: String?
    var tint: Color = Theme.lime

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.onLime)
                .frame(width: 38, height: 38)
                .background(tint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).formaFont(.bodyMedium)
                if let subtitle { Text(subtitle).formaFont(.caption, Theme.textSecondary) }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(Theme.surfaceRaised.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
        .padding(.horizontal, Theme.gutter)
    }
}

// MARK: - Sayı ayarlayıcı

struct NumberStepper: View {
    var title: String
    @Binding var value: Double
    var step: Double
    var range: ClosedRange<Double>
    var unit: String
    var format: (Double) -> String = { $0.formattedKg }

    var body: some View {
        HStack {
            Text(title).formaFont(.body, Theme.textSecondary)
            Spacer()
            IconButton(systemName: "minus", size: 34) { value = max(range.lowerBound, value - step) }
            Text("\(format(value)) \(unit)")
                .formaFont(.numberS)
                .frame(minWidth: 84)
                .monospacedDigit()
            IconButton(systemName: "plus", size: 34) { value = min(range.upperBound, value + step) }
        }
    }
}

// MARK: - Yardımcı

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: min(width, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
