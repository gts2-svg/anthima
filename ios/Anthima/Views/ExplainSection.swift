import SwiftUI

/// Under the article text: two buttons, «الشرح» and «المثال». Each opens its card under the text,
/// and both can be open together. What is open stays open while swiping to the next article.
struct ExplainSection: View {
    let explanation: Explanation
    @ObservedObject private var store = UserStore.shared
    @AppStorage("explain.sharhOpen") private var sharhOpen = false
    @AppStorage("explain.mithalOpen") private var mithalOpen = false

    var body: some View {
        let ex = explanation
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ExplainPill(title: "الشرح", icon: "lightbulb", color: T.accent, on: sharhOpen) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { sharhOpen.toggle() }
                }
                if ex.mithal != nil {
                    ExplainPill(title: "المثال", icon: "text.book.closed", color: T.green, on: mithalOpen) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { mithalOpen.toggle() }
                    }
                }
            }
            if sharhOpen {
                ExplainCard(kind: .sharh, text: ex.sharh, size: store.textSize)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if mithalOpen, let m = ex.mithal {
                ExplainCard(kind: .mithal, text: m, size: store.textSize)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if let rules = ex.rules, !rules.isEmpty {
                Text(verbatim: "القواعد الكلية (\(rules.count))")
                    .font(F.ui(16, .bold))
                    .foregroundStyle(T.ink)
                    .padding(.top, 8)
                ForEach(rules) { r in
                    RuleCard(rule: r)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: sharhOpen)
        .sensoryFeedback(.selection, trigger: mithalOpen)
    }
}

/// A rounded button: outlined when closed, filled when its card is open.
struct ExplainPill: View {
    let title: String
    let icon: String
    let color: Color
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(F.ui(16, .semibold))
                .foregroundStyle(on ? Color.white : color)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(on ? color : Color.white))
                .overlay(Capsule().strokeBorder(color, lineWidth: 1.5))
        }
        .buttonStyle(.press)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The soft card that holds the explanation (indigo) or the example (green).
struct ExplainCard: View {
    enum Kind { case sharh, mithal }
    let kind: Kind
    let text: String
    let size: Double

    var body: some View {
        let isSharh = kind == .sharh
        let ink = isSharh ? T.accentDeep : T.green
        let soft = isSharh ? T.accentSoft : Color(hex: 0xECFDF5)
        let bodySize = max(14, size - 2)
        VStack(alignment: .leading, spacing: 8) {
            Label(isSharh ? "الشرح" : "المثال", systemImage: isSharh ? "lightbulb" : "text.book.closed")
                .font(F.ui(14, .bold))
                .foregroundStyle(ink)
            Text(verbatim: text)
                .font(F.text(bodySize))
                .foregroundStyle(T.ink)
                .lineSpacing(bodySize * 0.5)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(soft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// One rule of article 720: its text, and the same two buttons for its own explanation and example.
struct RuleCard: View {
    let rule: RuleExplanation
    @ObservedObject private var store = UserStore.shared
    @State private var sharhOpen = false
    @State private var mithalOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: rule.label)
                .font(F.ui(13, .semibold))
                .foregroundStyle(T.accent)
            Text(verbatim: rule.text)
                .font(F.text(max(15, store.textSize - 1), semibold: true))
                .foregroundStyle(T.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                ExplainPill(title: "الشرح", icon: "lightbulb", color: T.accent, on: sharhOpen) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { sharhOpen.toggle() }
                }
                if rule.mithal != nil {
                    ExplainPill(title: "المثال", icon: "text.book.closed", color: T.green, on: mithalOpen) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { mithalOpen.toggle() }
                    }
                }
            }
            if sharhOpen {
                ExplainCard(kind: .sharh, text: rule.s, size: store.textSize)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if mithalOpen, let m = rule.mithal {
                ExplainCard(kind: .mithal, text: m, size: store.textSize)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 22)
    }
}
