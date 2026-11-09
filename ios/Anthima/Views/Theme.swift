import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Design «د · صباح»: light and airy, soft white cards, a lively indigo, a soft colour per section.
enum T {
    static let bg = Color(hex: 0xF6F7FB)
    static let ink = Color(hex: 0x111827)
    static let muted = Color(hex: 0x6B7280)
    static let accent = Color(hex: 0x4F46E5)
    static let accentDeep = Color(hex: 0x312E81)
    static let accentSoft = Color(hex: 0xEEF2FF)
    static let accentTint = Color(hex: 0xE0E7FF)
    static let line = Color(hex: 0xE5E7EB)
    static let field = Color(hex: 0xF3F4F6)
    static let gold = Color(hex: 0xB7791F)
    static let amberSoft = Color(hex: 0xFEF3C7)
    static let amberInk = Color(hex: 0x92400E)
    static let amber = Color(hex: 0xF59E0B)
    static let green = Color(hex: 0x047857)
    static let red = Color(hex: 0xB91C1C)

    // kept for the views that still use the old names
    static var sand: Color { amberSoft }
    static var sandLine: Color { Color(hex: 0xFCD34D) }
    static var sandInk: Color { amberInk }

    struct Section {
        let soft: Color
        let ink: Color
        let short: String
        let icon: String
    }

    static func section(_ cat: String) -> Section {
        switch cat {
        case "tijari": return Section(soft: Color(hex: 0xD1FAE5), ink: Color(hex: 0x065F46), short: "تجاري", icon: "briefcase")
        case "muroor": return Section(soft: Color(hex: 0xFFE4D6), ink: Color(hex: 0x9A3412), short: "مرور", icon: "car")
        case "madani": return Section(soft: Color(hex: 0xFEF3C7), ink: Color(hex: 0x92400E), short: "مدني", icon: "doc.text")
        case "aqari": return Section(soft: Color(hex: 0xFCE7F3), ink: Color(hex: 0x9D174D), short: "عقار", icon: "building.2")
        case "jazai": return Section(soft: Color(hex: 0xFEE2E2), ink: Color(hex: 0x991B1B), short: "جزائي", icon: "shield")
        case "ahwal": return Section(soft: Color(hex: 0xEDE9FE), ink: Color(hex: 0x5B21B6), short: "أحوال", icon: "person.2")
        default: return Section(soft: Color(hex: 0xE0E7FF), ink: Color(hex: 0x312E81), short: "قضاء", icon: "building.columns")
        }
    }

    static func catColors(_ cat: String) -> (soft: Color, ink: Color, short: String) {
        let s = section(cat)
        return (s.soft, s.ink, s.short)
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

    static func title(_ size: CGFloat, heavy: Bool = true) -> Font {
        .custom(heavy ? "Alexandria-ExtraBold" : "Alexandria-Bold", size: size)
    }

    /// Article text: the same clear modern face, a little larger.
    static func text(_ size: CGFloat, semibold: Bool = false) -> Font {
        .custom(semibold ? "IBMPlexSansArabic-Medium" : "IBMPlexSansArabic-Regular", size: size)
    }

    static func ruqaa(_ size: CGFloat) -> Font { .custom("ArefRuqaa-Bold", size: size) }
}

extension View {
    /// A white card with a soft shadow.
    func card(_ color: Color = .white, radius: CGFloat = 22, shadow: Bool = true) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color)
                .shadow(color: shadow ? Color(hex: 0x111827).opacity(0.06) : .clear, radius: 10, x: 0, y: 4)
        }
    }

    func anthimaEnvironment() -> some View {
        environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
            .tint(T.accent)
            .preferredColorScheme(.light)
    }

    /// Cards shrink and fade a little as they scroll in and out — the list feels alive.
    func softScroll() -> some View {
        scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                .opacity(phase.isIdentity ? 1 : 0.7)
        }
    }
}

/// Every tappable card: a gentle springy press and a light tap under the finger.
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

// MARK: zoom transitions (iOS 18 and later; a normal push before that)

private struct ZoomSpaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var zoomSpace: Namespace.ID? {
        get { self[ZoomSpaceKey.self] }
        set { self[ZoomSpaceKey.self] = newValue }
    }
}

struct ZoomSource: ViewModifier {
    let id: String
    @Environment(\.zoomSpace) private var space

    func body(content: Content) -> some View {
        if let space {
            if #available(iOS 18.0, *) {
                content.matchedTransitionSource(id: id, in: space)
            } else {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    func zoomSource(_ id: String) -> some View { modifier(ZoomSource(id: id)) }

    @ViewBuilder
    func zoomDestination(_ id: String, in space: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: space))
        } else {
            self
        }
    }
}

// MARK: shared pieces

/// The round number used in lists: «30», «1/30».
struct NumberBadge: View {
    let text: String
    var soft = T.accentSoft
    var ink = T.accent

    var body: some View {
        Text(verbatim: text)
            .font(F.ui(text.count > 4 ? 11 : 15, .bold))
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 42, height: 42)
            .background(soft, in: Circle())
    }
}

struct Chip: View {
    let text: String
    var on = false
    var body: some View {
        Text(verbatim: text)
            .font(F.ui(13, on ? .semibold : .regular))
            .foregroundStyle(on ? Color.white : T.ink)
            .padding(.horizontal, 15)
            .frame(minHeight: 36)
            .background(on ? T.ink : Color.white, in: Capsule())
    }
}

/// A row for an article in any list.
struct ArticleRow: View {
    let article: Article
    var preview: String? = nil
    var showLaw = false

    var body: some View {
        let law = Library.shared.law(article.lawID)
        let sec = T.section(law?.cat ?? "")
        let saved = UserStore.shared.isSaved(article)
        let isLaw = law?.kind == .law
        HStack(alignment: .top, spacing: 14) {
            NumberBadge(text: article.badge,
                        soft: saved ? T.amberSoft : (isLaw ? T.accentSoft : T.amberSoft),
                        ink: saved ? T.amberInk : (isLaw ? T.accent : T.amberInk))
            VStack(alignment: .leading, spacing: 4) {
                if showLaw, let law {
                    Text(verbatim: law.name).font(F.ui(12, .semibold)).foregroundStyle(sec.ink)
                }
                if let t = article.title, !t.isEmpty {
                    Text(verbatim: t).font(F.ui(14, .semibold)).foregroundStyle(T.ink)
                } else if article.n.isEmpty, !article.heading.isEmpty {
                    Text(verbatim: article.heading).font(F.ui(14, .semibold)).foregroundStyle(T.ink)
                }
                Text(verbatim: preview ?? article.text.replacingOccurrences(of: "\n", with: " "))
                    .font(F.text(15))
                    .foregroundStyle(article.repealed == true ? T.muted : T.ink)
                    .lineLimit(3)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                if saved {
                    Label("محفوظة", systemImage: "star.fill")
                        .font(F.ui(12, .semibold))
                        .foregroundStyle(Color(hex: 0xB45309))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 22)
        .overlay {
            if saved {
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color(hex: 0xFCD34D), lineWidth: 2)
            }
        }
    }
}

/// «تم» above the keyboard.
struct KeyboardDone: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.immediately)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("تم") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .font(F.ui(16, .bold))
                }
            }
    }
}

extension View {
    func keyboardDone() -> some View { modifier(KeyboardDone()) }
}

/// A round white button in the floating bars.
struct RoundIcon: View {
    let system: String
    var tint: Color = T.ink
    var size: CGFloat = 52
    var body: some View {
        Image(systemName: system)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Color.white, in: Circle())
            .shadow(color: Color(hex: 0x111827).opacity(0.10), radius: 10, x: 0, y: 4)
    }
}
