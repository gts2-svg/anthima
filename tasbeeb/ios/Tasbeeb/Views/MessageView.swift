import SwiftUI

/// فقاعة واحدة في المحادثة.
struct MessageView: View {
    let m: Msg
    @ObservedObject var s: CaseSession
    var onAlerts: () -> Void
    var onEdit: () -> Void
    var onDetails: () -> Void
    @State private var expanded = false
    @State private var copied = false

    var body: some View {
        switch m.kind {
        case .text where m.role == .user: userText
        case .images: userImages
        case .working: working
        case .doc: docBubble
        case .question: question
        case .evidence: evidence
        case .tasbeeb: tasbeeb
        case .alerts: alertsBubble
        default: botText
        }
    }

    // MARK: فقاعات المستخدم

    private var userText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: m.text)
                .font(F.ui(14))
                .lineSpacing(5)
                .foregroundStyle(.white)
                .lineLimit(expanded ? nil : 7)
                .fixedSize(horizontal: false, vertical: true)
            if m.text.count > 320 {
                Button(expanded ? "عرض أقل" : "عرض الكل") { expanded.toggle() }
                    .font(F.ui(12, .bold)).foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(T.accent, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 4, topTrailingRadius: 18, style: .continuous))
        .frame(maxWidth: 320, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userImages: some View {
        HStack(spacing: 6) {
            ForEach(m.images, id: \.self) { name in
                if let img = CaseStore.shared.image(name) {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: 96, height: 120).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(6)
        .background(T.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: فقاعات التطبيق

    private func botBubble<C: View>(border: Color = T.line, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) { content() }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(Color.white, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous))
            .overlay(UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 4, bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous).stroke(border, lineWidth: 1))
            .frame(maxWidth: 340, alignment: .trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var levelBorder: Color { m.level == "red" ? T.redLine : (m.level == "warn" ? T.amberLine : T.line) }

    private var botText: some View {
        botBubble(border: levelBorder) {
            Para(text: m.text, size: 14, spacing: 5)
            linesView
        }
    }

    @ViewBuilder private var linesView: some View {
        if !m.lines.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(m.lines, id: \.self) { l in
                    Text(verbatim: l).font(F.ui(13)).lineSpacing(3)
                        .foregroundStyle(l.hasPrefix("⚠︎") ? T.red : T.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var working: some View {
        botBubble {
            HStack(spacing: 8) {
                ProgressView().tint(T.accent)
                Text(verbatim: m.text).font(F.ui(14)).foregroundStyle(T.muted)
            }
        }
    }

    private var docBubble: some View {
        botBubble(border: levelBorder) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass").foregroundStyle(T.accent)
                Text(verbatim: m.text).font(F.ui(14, .bold)).foregroundStyle(T.ink)
            }
            linesView
            if m.answered == "weak" {
                Text("قراءة غير واضحة، فراجع الأرقام مع الأصل.").font(F.ui(12)).foregroundStyle(T.amber)
            }
        }
    }

    private var question: some View {
        VStack(alignment: .trailing, spacing: 8) {
            botBubble(border: levelBorder) {
                Para(text: m.text, size: 14, spacing: 5)
                linesView
            }
            if m.answered == nil && !m.options.isEmpty {
                FlowChips(items: Array(m.options.enumerated()).map { ($0.element, m.label(at: $0.offset)) }) { value in
                    s.answer(m.id, value)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var evidence: some View {
        VStack(alignment: .trailing, spacing: 8) {
            botBubble {
                Para(text: m.text, size: 14, spacing: 5)
            }
            if m.answered == nil {
                FlowToggles(chips: s.view.chips) { id in s.toggleEvidence(id) }
                Button { s.evidenceDone(m.id) } label: { ReplyChip(text: "تم", on: true) }
                    .buttonStyle(.press)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var tasbeeb: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: (m.title ?? "التسبيب") + (m.edited ? " (معدّل)" : "") + (m.answered == "old" ? " — نسخة سابقة" : ""))
                    .font(F.ui(12, .bold)).foregroundStyle(m.answered == "old" ? T.muted : T.accent)
                Spacer()
                if !s.view.catName.isEmpty {
                    Text(verbatim: s.view.catName).font(F.ui(11, .semibold)).foregroundStyle(T.cat(s.view.cat).ink)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(T.cat(s.view.cat).soft, in: Capsule())
                }
            }
            Text(verbatim: m.text)
                .font(F.ui(15.5))
                .lineSpacing(9)
                .foregroundStyle(T.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            linesView
            Divider().overlay(T.line)
            HStack(spacing: 6) {
                Button {
                    UIPasteboard.general.string = m.text
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
                } label: {
                    Label(copied ? "نُسخ" : "نسخ", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(F.ui(14, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.press)
                .sensoryFeedback(.success, trigger: copied) { _, now in now }
                ShareLink(item: m.text) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 42).foregroundStyle(T.ink)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(T.line))
                }
                .accessibilityLabel("مشاركة")
                Button(action: onEdit) {
                    Image(systemName: "pencil").font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 42).foregroundStyle(T.ink)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(T.line))
                }
                .accessibilityLabel("تعديل النص")
                Menu {
                    Button { s.saveWording(m) } label: { Label("حفظ صياغتي لهذا النوع", systemImage: "bookmark") }
                    if s.hasSavedWording { Button { s.useSavedWording() } label: { Label("استعمل صياغتي المحفوظة", systemImage: "text.badge.checkmark") } }
                    Button(action: onDetails) { Label("مراجعة البيانات", systemImage: "list.bullet.rectangle") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 42).foregroundStyle(T.ink)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(T.line))
                }
                .accessibilityLabel("المزيد")
            }
        }
        .padding(14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(T.line))
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var alertsBubble: some View {
        let a = s.view.alerts
        let red = a.contains { $0.lvl == "red" }
        return botBubble(border: red ? T.redLine : T.amberLine) {
            Text(verbatim: m.text).font(F.ui(14, .bold)).foregroundStyle(red ? T.red : T.amber)
            Text("للتذكير فقط، ولا تدخل في الضبط").font(F.ui(12)).foregroundStyle(T.muted)
            ForEach(a.prefix(2), id: \.self) { x in
                Text(verbatim: "• " + x.title).font(F.ui(13)).foregroundStyle(T.level(x.lvl).ink)
            }
            Button(action: onAlerts) { ReplyChip(text: "عرض التنبيهات") }.buttonStyle(.press)
        }
    }
}

/// أزرار رد تلتف على أكثر من سطر.
struct FlowChips: View {
    let items: [(String, String)]
    var action: (String) -> Void
    var body: some View {
        WrapLayout(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                Button { action(items[i].0) } label: { ReplyChip(text: items[i].1) }.buttonStyle(.press)
            }
        }
        .frame(maxWidth: 340, alignment: .trailing)
    }
}

struct FlowToggles: View {
    let chips: [EngineChip]
    var toggle: (String) -> Void
    var body: some View {
        WrapLayout(spacing: 6) {
            ForEach(chips, id: \.id) { c in
                Button { toggle(c.id) } label: {
                    HStack(spacing: 4) {
                        if c.on { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)) }
                        Text(verbatim: c.label).font(F.ui(13, c.on ? .semibold : .regular))
                    }
                    .foregroundStyle(c.on ? Color.white : T.ink)
                    .padding(.horizontal, 12).frame(minHeight: 38)
                    .background(c.on ? T.ink : Color.white, in: Capsule())
                    .overlay(Capsule().strokeBorder(c.on ? Color.clear : T.line))
                }
                .buttonStyle(.press)
            }
        }
        .frame(maxWidth: 340, alignment: .trailing)
    }
}

/// تخطيط يلف العناصر على أسطر (يحترم اتجاه اليمين لليسار).
struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 340
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW { y += rowH + spacing; x = 0; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let sz = v.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > bounds.width { y += rowH + spacing; x = 0; rowH = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
