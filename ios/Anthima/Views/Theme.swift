import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Design «ج · واضح»: white and dark navy, blue accent, sand for regulations.
enum T {
    static let bg = Color(hex: 0xF2F4F7)
    static let ink = Color(hex: 0x14202B)
    static let accent = Color(hex: 0x1F5F8B)
    static let accentSoft = Color(hex: 0xE3EDF5)
    static let muted = Color(hex: 0x56616C)
    static let line = Color(hex: 0xE1E5EA)
    static let sand = Color(hex: 0xFBF6EA)
    static let sandLine = Color(hex: 0xEEDDB5)
    static let sandInk = Color(hex: 0x7A5410)
    static let gold = Color(hex: 0xE9C77B)
    static let green = Color(hex: 0x2E6B47)
    static let red = Color(hex: 0x9A3A2A)

    static func catColors(_ cat: String) -> (soft: Color, ink: Color, short: String) {
        switch cat {
        case "madani": return (Color(hex: 0xF4EAD6), Color(hex: 0x7A5410), "مدني")
        case "tijari": return (Color(hex: 0xE2F0E8), Color(hex: 0x2E6B47), "تجاري")
        case "jazai": return (Color(hex: 0xF7E3DF), Color(hex: 0x9A3A2A), "جزائي")
        case "muroor": return (Color(hex: 0xECE6F6), Color(hex: 0x5B4A8B), "مرور")
        case "ahwal": return (Color(hex: 0xF6E4EC), Color(hex: 0x8B3A5E), "أحوال")
        case "aqari": return (Color(hex: 0xDFF1F1), Color(hex: 0x1E6B6B), "عقار")
        default: return (accentSoft, accent, "قضاء")
        }
    }
}

/// The four families chosen in the design.
enum F {
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black: return .custom("ReadexPro-Bold", size: size)
        case .semibold, .medium: return .custom("ReadexPro-SemiBold", size: size)
        default: return .custom("ReadexPro-Regular", size: size)
        }
    }

    static func title(_ size: CGFloat) -> Font { .custom("ReemKufi-Bold", size: size) }

    static func text(_ size: CGFloat, semibold: Bool = false) -> Font {
        .custom(semibold ? "NotoNaskhArabic-SemiBold" : "NotoNaskhArabic-Regular", size: size)
    }

    static func ruqaa(_ size: CGFloat) -> Font { .custom("ArefRuqaa-Bold", size: size) }
}

extension View {
    func card(_ color: Color = .white, radius: CGFloat = 16) -> some View {
        background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func anthimaEnvironment() -> some View {
        environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
            .tint(T.accent)
            .preferredColorScheme(.light)
    }
}

/// The number square used in lists: «30», «1/30».
struct NumberBadge: View {
    let text: String
    var soft = T.accentSoft
    var ink = T.accent

    var body: some View {
        Text(verbatim: text)
            .font(F.ui(text.count > 4 ? 11 : 14, .bold))
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(minWidth: 38, minHeight: 38)
            .padding(.horizontal, text.count > 3 ? 4 : 0)
            .background(soft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct Chip: View {
    let text: String
    var on = false
    var body: some View {
        Text(verbatim: text)
            .font(F.ui(13, on ? .semibold : .regular))
            .foregroundStyle(on ? Color.white : T.ink)
            .padding(.horizontal, 13)
            .frame(minHeight: 34)
            .background(on ? T.ink : Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A row for an article in any list.
struct ArticleRow: View {
    let article: Article
    var preview: String? = nil
    var showLaw = false

    var body: some View {
        let law = Library.shared.law(article.lawID)
        let colors = T.catColors(law?.cat ?? "")
        HStack(alignment: .top, spacing: 12) {
            NumberBadge(text: article.badge,
                        soft: law?.kind == .law ? T.accentSoft : T.sand,
                        ink: law?.kind == .law ? T.accent : T.sandInk)
            VStack(alignment: .leading, spacing: 4) {
                if showLaw, let law {
                    Text(verbatim: law.name).font(F.ui(12, .semibold)).foregroundStyle(colors.ink)
                }
                if let t = article.title, !t.isEmpty {
                    Text(verbatim: t).font(F.ui(13, .semibold)).foregroundStyle(T.ink)
                } else if article.n.isEmpty, !article.heading.isEmpty {
                    Text(verbatim: article.heading).font(F.ui(13, .semibold)).foregroundStyle(T.ink)
                }
                Text(verbatim: preview ?? article.text.replacingOccurrences(of: "\n", with: " "))
                    .font(F.text(15))
                    .foregroundStyle(article.repealed == true ? T.muted : T.ink)
                    .lineLimit(3)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                if UserStore.shared.isSaved(article) {
                    Text("محفوظة عندك").font(F.ui(11, .semibold)).foregroundStyle(T.sandInk)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
