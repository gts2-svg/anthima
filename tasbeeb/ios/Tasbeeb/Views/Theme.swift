import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Color {
    /// لون يتبدّل مع الوضع الداكن
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { tc in
            let h = tc.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255,
                           blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        })
    }
}

/// تصميم «محادثة»: خلفية فاتحة دافئة، فقاعات بيضاء، ولون فيروزي للتطبيق؛ وله وضع داكن اختياري بألوان «ليل».
enum T {
    static let bg = Color(light: 0xF4F5F1, dark: 0x0F1513)
    static let card = Color(light: 0xFFFFFF, dark: 0x1A2320)
    static let ink = Color(light: 0x14201C, dark: 0xE6ECE8)
    static let muted = Color(light: 0x66706B, dark: 0x9AA6A0)
    static let line = Color(light: 0xE2E5DF, dark: 0x2B3632)
    static let accent = Color(light: 0x0F766E, dark: 0x13897D)
    static let accentSoft = Color(light: 0xCCEDE8, dark: 0x123A36)
    static let amber = Color(light: 0xB45309, dark: 0xF5B54A)
    static let amberSoft = Color(light: 0xFEF3C7, dark: 0x3A2A10)
    static let amberLine = Color(light: 0xF2D49B, dark: 0x6B4E1C)
    static let red = Color(light: 0xB42318, dark: 0xFF8A80)
    static let redSoft = Color(light: 0xFDE8E6, dark: 0x3B1714)
    static let redLine = Color(light: 0xF5C2BE, dark: 0x6E2A25)
    static let gold = Color(hex: 0xC9A24B)

    /// لون كل قسم: (الخلفية، الحبر، الحرف)
    static func cat(_ key: String) -> (soft: Color, ink: Color, letter: String) {
        switch key {
        case "murori": return (Color(light: 0xFFE4D6, dark: 0x3A2418), Color(light: 0x9A3412, dark: 0xFDBA8C), "م")
        case "ahwal": return (Color(light: 0xEDE9FE, dark: 0x2A2346), Color(light: 0x5B21B6, dark: 0xC4B5FD), "أ")
        case "jazai": return (Color(light: 0xFEE2E2, dark: 0x3B1C1C), Color(light: 0x991B1B, dark: 0xFCA5A5), "ج")
        default: return (Color(light: 0xE0E7FF, dark: 0x1F2547), Color(light: 0x312E81, dark: 0xA5B4FC), "ح")
        }
    }

    static func level(_ lvl: String) -> (ink: Color, soft: Color) {
        switch lvl {
        case "red": return (red, redSoft)
        case "warn": return (amber, amberSoft)
        default: return (accent, accentSoft)
        }
    }
}

enum F {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black: return .custom("IBMPlexSansArabic-Bold", size: size)
        case .semibold: return .custom("IBMPlexSansArabic-SemiBold", size: size)
        case .medium: return .custom("IBMPlexSansArabic-Medium", size: size)
        default: return .custom("IBMPlexSansArabic-Regular", size: size)
        }
    }
    static func title(_ size: CGFloat) -> Font { .custom("Alexandria-Bold", size: size) }
    /// خط بطاقة الناتج: النسخ اختياراً من الإعدادات، وإلا خط التطبيق
    static func output(_ size: CGFloat, naskh: Bool) -> Font {
        naskh ? .custom("NotoNaskhArabic-Regular", size: size + 1.5) : ui(size)
    }
}

extension View {
    func appEnvironment() -> some View {
        environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
            .tint(T.accent)
    }
}

/// المظهر المختار من الإعدادات: فاتح (الافتراضي) أو داكن أو حسب الجهاز
enum Appearance: String, CaseIterable {
    case light, dark, system
    var label: String { self == .light ? "فاتح" : (self == .dark ? "داكن" : "حسب الجهاز") }
    var scheme: ColorScheme? { self == .light ? .light : (self == .dark ? .dark : nil) }
}

/// ضغطة لينة مع اهتزاز خفيف.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

extension ButtonStyle where Self == PressStyle {
    static var press: PressStyle { PressStyle() }
}

/// زر دائري صغير في الشريط العلوي.
struct RoundIcon: View {
    let system: String
    var tint: Color = T.ink
    var size: CGFloat = 42
    var body: some View {
        Image(systemName: system)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(T.card, in: Circle())
            .overlay(Circle().strokeBorder(T.line))
    }
}

/// شريحة رد سريع.
struct ReplyChip: View {
    let text: String
    var on = false
    var body: some View {
        Text(verbatim: text)
            .font(F.ui(14, .semibold))
            .foregroundStyle(on ? Color.white : T.accent)
            .padding(.horizontal, 15)
            .frame(minHeight: 40)
            .background(on ? T.accent : T.card, in: Capsule())
            .overlay(Capsule().strokeBorder(T.accent, lineWidth: 1.5))
    }
}

/// شريط المسافات بين الأسطر للنص العربي الطويل.
struct Para: View {
    let text: String
    var size: CGFloat = 15
    var spacing: CGFloat = 7
    var body: some View {
        Text(verbatim: text)
            .font(F.ui(size))
            .lineSpacing(spacing)
            .foregroundStyle(T.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
