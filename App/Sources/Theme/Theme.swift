import SwiftUI
import FormaKit

/// Forma'nın görsel dili: koyu grafit zemin, limon yeşili vurgu, Space Grotesk rakamlar.
enum Theme {
    // Zeminler
    static let background = Color(hex: 0x0E1013)
    static let surface = Color(hex: 0x171A1F)
    static let surfaceRaised = Color(hex: 0x1F232A)
    static let surfaceHigh = Color(hex: 0x2A2F37)
    static let hairline = Color(hex: 0x2A2F37)

    // Metin
    static let textPrimary = Color(hex: 0xF3F1EA)
    static let textSecondary = Color(hex: 0xA7B0BA)
    static let textTertiary = Color(hex: 0x6E7782)

    // Vurgular
    static let lime = Color(hex: 0xC6F24E)
    static let limeDeep = Color(hex: 0x8FB33A)
    static let onLime = Color(hex: 0x12150A)
    static let water = Color(hex: 0x5AB0FF)
    static let waterDeep = Color(hex: 0x13314D)
    static let energy = Color(hex: 0xFF9B4A)
    static let supplement = Color(hex: 0xB9A6FF)
    static let coral = Color(hex: 0xFF6B5B)
    static let gold = Color(hex: 0xFFC94D)
    static let amber = Color(hex: 0xE8C547)

    static let protein = lime
    static let carbs = energy
    static let fat = water

    static let radius: CGFloat = 22
    static let radiusSmall: CGFloat = 14
    static let gutter: CGFloat = 16

    static func recoveryColor(_ percent: Double) -> Color {
        switch percent {
        case ..<50: return energy
        case ..<80: return amber
        default: return lime
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

// MARK: - Yazı tipleri

enum FontStyle {
    case display, title, headline, numberXL, numberL, numberM, numberS, body, bodyMedium, callout, caption, label, micro
}

extension Font {
    /// Uygulamaya gömülü yazı tipleri. Bulunamazsa sistem yazı tipine düşer.
    static func forma(_ style: FontStyle) -> Font {
        switch style {
        case .display: return .custom("SpaceGrotesk-Bold", size: 34, relativeTo: .largeTitle)
        case .title: return .custom("SpaceGrotesk-Bold", size: 26, relativeTo: .title)
        case .headline: return .custom("SpaceGrotesk-SemiBold", size: 20, relativeTo: .headline)
        case .numberXL: return .custom("SpaceGrotesk-Bold", size: 56, relativeTo: .largeTitle)
        case .numberL: return .custom("SpaceGrotesk-Bold", size: 36, relativeTo: .title)
        case .numberM: return .custom("SpaceGrotesk-SemiBold", size: 24, relativeTo: .title2)
        case .numberS: return .custom("SpaceGrotesk-Medium", size: 17, relativeTo: .body)
        case .body: return .custom("DMSans-Regular", size: 16, relativeTo: .body)
        case .bodyMedium: return .custom("DMSans-Medium", size: 16, relativeTo: .body)
        case .callout: return .custom("DMSans-Medium", size: 14, relativeTo: .callout)
        case .caption: return .custom("DMSans-Regular", size: 13, relativeTo: .caption)
        case .label: return .custom("DMSans-SemiBold", size: 12, relativeTo: .caption)
        case .micro: return .custom("DMSans-Bold", size: 10, relativeTo: .caption2)
        }
    }
}

extension View {
    func formaFont(_ style: FontStyle, _ color: Color = Theme.textPrimary) -> some View {
        self.font(.forma(style)).foregroundStyle(color)
    }

    /// Küçük, aralıklı büyük harf etiket ("BUGÜN", "PROTEİN").
    func eyebrow(_ color: Color = Theme.textTertiary) -> some View {
        self.font(.forma(.label)).tracking(1.4).textCase(.uppercase).foregroundStyle(color)
    }

    func cardStyle(padding: CGFloat = 16, background: Color = Theme.surface, radius: CGFloat = Theme.radius) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white.opacity(0.04), lineWidth: 1))
    }

    func screenBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}

// MARK: - Sayı biçimleri

enum Fmt {
    private static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func int(_ v: Double) -> String {
        integer.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
    }

    static func liters(_ ml: Double) -> String {
        let l = ml / 1000
        return String(format: "%.1f", l).replacingOccurrences(of: ".", with: ",")
    }

    static func kg(_ v: Double) -> String { v.formattedKg }

    static func oneDecimal(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }

    static func duration(_ t: TimeInterval) -> String {
        let total = max(0, Int(t))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    static func minutes(_ t: TimeInterval) -> String {
        let m = Int(t / 60)
        if m >= 60 { return "\(m / 60) sa \(m % 60) dk" }
        return "\(m) dk"
    }

    static let dayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM"
        return f
    }()

    static let weekdayDayMonth: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM EEEE"
        return f
    }()

    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMM"
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func relativeDay(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.forma
        if cal.isDateInToday(date) { return "Bugün" }
        if cal.isDateInYesterday(date) { return "Dün" }
        let days = cal.days(from: date, to: now)
        if days < 7 { return "\(days) gün önce" }
        return shortDate.string(from: date)
    }
}
