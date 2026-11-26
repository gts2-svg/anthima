import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// تصميم «محادثة»: خلفية فاتحة دافئة، فقاعات بيضاء، ولون فيروزي للتطبيق.
enum T {
    static let bg = Color(hex: 0xF4F5F1)
    static let ink = Color(hex: 0x14201C)
    static let muted = Color(hex: 0x66706B)
    static let line = Color(hex: 0xE2E5DF)
    static let accent = Color(hex: 0x0F766E)
    static let accentSoft = Color(hex: 0xCCEDE8)
    static let amber = Color(hex: 0xB45309)
    static let amberSoft = Color(hex: 0xFEF3C7)
    static let amberLine = Color(hex: 0xF2D49B)
    static let red = Color(hex: 0xB42318)
    static let redSoft = Color(hex: 0xFDE8E6)
    static let redLine = Color(hex: 0xF5C2BE)
    static let gold = Color(hex: 0xC9A24B)

    /// لون كل قسم: (الخلفية، الحبر، الحرف)
    static func cat(_ key: String) -> (soft: Color, ink: Color, letter: String) {
        switch key {
        case "murori": return (Color(hex: 0xFFE4D6), Color(hex: 0x9A3412), "م")
        case "ahwal": return (Color(hex: 0xEDE9FE), Color(hex: 0x5B21B6), "أ")
        case "jazai": return (Color(hex: 0xFEE2E2), Color(hex: 0x991B1B), "ج")
        default: return (Color(hex: 0xE0E7FF), Color(hex: 0x312E81), "ح")
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
}

extension View {
    func appEnvironment() -> some View {
        environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
            .tint(T.accent)
            .preferredColorScheme(.light)
    }
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
            .background(Color.white, in: Circle())
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
            .background(on ? T.accent : Color.white, in: Capsule())
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
