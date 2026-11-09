import SwiftUI

/// One article — design ج: place chips, the text card, links to its regulation, copy and save,
/// and previous / ask / next at the bottom.
struct ArticleView: View {
    let startKey: String
    @ObservedObject private var store = UserStore.shared
    @ObservedObject private var nav = AppNav.shared
    @State private var key: String = ""
    @State private var toast: String?

    private var lib: Library { Library.shared }
    private var article: Article? { lib.article(key: key.isEmpty ? startKey : key) }

    var body: some View {
        Group {
            if let a = article, let law = lib.law(a.lawID) {
                content(a, law: law)
            } else {
                Text("ما لقيت هذه المادة").font(F.ui(15)).foregroundStyle(T.muted)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear {
            if key.isEmpty { key = startKey }
            store.lastRead = key
        }
        .onChange(of: key) { _, k in store.lastRead = k }
    }

    private func content(_ a: Article, law: Law) -> some View {
        let isLaw = law.kind == .law
        let position = (law.articles.firstIndex { $0.id == a.id } ?? 0)
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !a.place.isEmpty {
                        FlowChips(items: [a.part, a.chapter].compactMap { $0 }.filter { !$0.isEmpty })
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(verbatim: a.displayHeading).font(F.ui(13, .bold)).foregroundStyle(isLaw ? T.accent : T.sandInk)
                            Spacer()
                            if a.repealed == true {
                                Text("ملغاة").font(F.ui(12, .bold)).foregroundStyle(T.red)
                            }
                        }
                        if let t = a.title, !t.isEmpty {
                            Text(verbatim: t).font(F.ui(15, .semibold)).foregroundStyle(T.ink)
                        }
                        Text(verbatim: a.text)
                            .font(F.text(store.textSize))
                            .foregroundStyle(T.ink)
                            .lineSpacing(store.textSize * 0.45)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let n = a.note, !n.isEmpty {
                            Text(verbatim: n).font(F.ui(12)).foregroundStyle(T.muted)
                        }
                    }
                    .padding(18)
                    .card(isLaw ? .white : T.sand, radius: 18)
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(isLaw ? Color.clear : T.sandLine))

                    regulationLinks(a)
                    parentLink(a, law: law)

                    HStack(spacing: 8) {
                        actionButton("نسخ النص") { Clipboard.copy(Clipboard.plain(a, law: law)); flash("نُسخ النص") }
                        actionButton("نسخ للتسبيب") { Clipboard.copy(Clipboard.forReasoning(a, law: law)); flash("نُسخ بصيغة التسبيب") }
                        Button { store.toggleSave(a) } label: {
                            Image(systemName: store.isSaved(a) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 18))
                                .foregroundStyle(T.accent)
                                .frame(width: 48, height: 48)
                                .card(radius: 14)
                        }
                        .accessibilityLabel(store.isSaved(a) ? "إلغاء الحفظ" : "حفظ")
                    }
                    if let toast {
                        Text(verbatim: toast).font(F.ui(13, .semibold)).foregroundStyle(T.green)
                            .frame(maxWidth: .infinity)
                    }
                    Text(verbatim: law.source ?? "").font(F.ui(11)).foregroundStyle(T.muted).padding(.top, 6)
                }
                .padding(16)
            }

            HStack(spacing: 8) {
                stepButton(icon: "chevron.backward", label: "المادة السابقة", enabled: position > 0) {
                    move(law, position - 1)
                }
                Button { nav.askAbout(a) } label: {
                    Label("اسأل عن هذه المادة", systemImage: "bubble.left.and.text.bubble.right")
                        .font(F.ui(15, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(T.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                stepButton(icon: "chevron.forward", label: "المادة التالية", enabled: position < law.articles.count - 1) {
                    move(law, position + 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.white.ignoresSafeArea(edges: .bottom))
            .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
        }
        .navigationTitle(Text(verbatim: "\(a.displayHeading)"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.textSize = max(14, store.textSize - 1) } label: { Text("أ-").font(F.ui(14)) }
                    .accessibilityLabel("تصغير الخط")
                Button { store.textSize = min(30, store.textSize + 1) } label: { Text("أ+").font(F.ui(17, .bold)) }
                    .accessibilityLabel("تكبير الخط")
            }
        }
    }

    @ViewBuilder
    private func regulationLinks(_ a: Article) -> some View {
        let regs = lib.regulationLinks(for: a)
        if !regs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "لها في اللائحة التنفيذية (\(regs.count))").font(F.ui(13, .bold)).foregroundStyle(T.sandInk)
                FlowLayout(spacing: 6) {
                    ForEach(regs) { r in
                        Button { nav.open(.article(r.key)) } label: {
                            Text(verbatim: r.label)
                                .font(F.ui(13, .semibold))
                                .foregroundStyle(T.sandInk)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 36)
                                .background(T.sand, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.sandLine))
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: 16)
        }
    }

    @ViewBuilder
    private func parentLink(_ a: Article, law: Law) -> some View {
        if law.kind == .reg, let ref = a.ref, let pid = law.parent, let p = lib.law(pid),
           let target = p.articles.first(where: { $0.n == ref }) {
            Button { nav.open(.article(target.key)) } label: {
                HStack {
                    Text(verbatim: "افتح المادة (\(ref)) من \(p.name)").font(F.ui(13, .semibold))
                    Spacer()
                    Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(T.accent)
                .padding(14)
                .card(radius: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(F.ui(13, .semibold)).foregroundStyle(T.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .card(radius: 14)
        }
        .buttonStyle(.plain)
    }

    private func stepButton(icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? T.ink : T.line)
                .frame(width: 54, height: 50)
                .background(T.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func move(_ law: Law, _ i: Int) {
        guard law.articles.indices.contains(i) else { return }
        key = law.articles[i].key
        toast = nil
    }

    private func flash(_ s: String) {
        toast = s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if toast == s { toast = nil } }
    }
}

/// Small chips that wrap onto new lines.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { s in
                Text(verbatim: s)
                    .font(F.ui(12))
                    .foregroundStyle(T.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(T.accentSoft, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0 && x + s.width > width { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing
            row = max(row, s.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > 0 && x + s.width > bounds.width { x = 0; y += row + spacing; row = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            row = max(row, s.height)
        }
    }
}
