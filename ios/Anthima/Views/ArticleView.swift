import SwiftUI

/// One article — design «صباح». Swipe sideways to the next or previous article like turning pages;
/// the text sits in a soft white card, the regulation link in amber, actions as three tiles.
struct ArticleView: View {
    let startKey: String
    @ObservedObject private var store = UserStore.shared
    @ObservedObject private var nav = AppNav.shared
    @State private var current: String?
    @State private var showSize = false

    private var lib: Library { Library.shared }

    init(startKey: String) {
        self.startKey = startKey
        _current = State(initialValue: Library.shared.article(key: startKey)?.id)
    }

    var body: some View {
        if let first = lib.article(key: startKey), let law = lib.law(first.lawID) {
            let currentArticle = law.articles.first { $0.id == (current ?? first.id) } ?? first
            let position = law.articles.firstIndex { $0.id == currentArticle.id } ?? 0
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(law.articles) { a in
                        ArticlePage(article: a, law: law)
                            .containerRelativeFrame(.horizontal)
                            .id(a.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $current)
            .background(T.bg.ignoresSafeArea())
            .onAppear {
                if current == nil { current = first.id }
                store.lastRead = currentArticle.key
            }
            .onChange(of: current) { _, _ in
                store.lastRead = currentArticle.key
            }
            .sensoryFeedback(.selection, trigger: current)
            .navigationTitle(Text(verbatim: "\(position + 1) من \(law.articles.count)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showSize.toggle() } label: { Text("Aa").font(.system(size: 16, weight: .bold)) }
                        .accessibilityLabel("حجم الخط")
                        .popover(isPresented: $showSize) {
                            HStack(spacing: 14) {
                                Button { store.textSize = max(14, store.textSize - 1) } label: { Text("أ").font(F.text(15)) }
                                Slider(value: $store.textSize, in: 14...30, step: 1).frame(width: 160)
                                Button { store.textSize = min(30, store.textSize + 1) } label: { Text("أ").font(F.text(26)) }
                            }
                            .padding(18)
                            .presentationCompactAdaptation(.popover)
                        }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button { step(law, position - 1) } label: { RoundIcon(system: "chevron.backward", tint: position > 0 ? T.ink : T.line, size: 56) }
                        .buttonStyle(.press)
                        .disabled(position == 0)
                        .accessibilityLabel("المادة السابقة")
                    Button { nav.askAbout(currentArticle) } label: {
                        Label("اسأل عنها", systemImage: "sparkles")
                            .font(F.ui(16, .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background { Capsule().fill(T.accent).shadow(color: T.accent.opacity(0.35), radius: 14, x: 0, y: 8) }
                    }
                    .buttonStyle(.press)
                    Button { step(law, position + 1) } label: { RoundIcon(system: "chevron.forward", tint: position < law.articles.count - 1 ? T.ink : T.line, size: 56) }
                        .buttonStyle(.press)
                        .disabled(position >= law.articles.count - 1)
                        .accessibilityLabel("المادة التالية")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        } else {
            Text("ما لقيت هذه المادة").font(F.ui(15)).foregroundStyle(T.muted)
        }
    }

    private func step(_ law: Law, _ i: Int) {
        guard law.articles.indices.contains(i) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { current = law.articles[i].id }
    }
}

/// The content of one article page.
struct ArticlePage: View {
    let article: Article
    let law: Law
    @ObservedObject private var store = UserStore.shared
    @ObservedObject private var nav = AppNav.shared
    @State private var toast: String?

    private var lib: Library { Library.shared }

    var body: some View {
        let a = article
        let sec = T.section(law.cat)
        let isLaw = law.kind == .law
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: [law.name, a.chapter ?? a.part ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(F.ui(13, .semibold))
                        .foregroundStyle(isLaw ? T.accent : T.amberInk)
                        .lineLimit(2)
                    Text(verbatim: a.displayHeading).font(F.title(28)).foregroundStyle(T.ink)
                    if let t = a.title, !t.isEmpty {
                        Text(verbatim: t).font(F.ui(16, .semibold)).foregroundStyle(sec.ink)
                    }
                    if a.repealed == true {
                        Text("ملغاة").font(F.ui(12, .bold)).foregroundStyle(T.red)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .background(Color(hex: 0xFEE2E2), in: Capsule())
                    }
                }

                Text(verbatim: a.text)
                    .font(F.text(store.textSize))
                    .foregroundStyle(T.ink)
                    .lineSpacing(store.textSize * 0.55)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .card(isLaw ? .white : Color(hex: 0xFFFBEB), radius: 26)

                if let n = a.note, !n.isEmpty {
                    Text(verbatim: n).font(F.ui(12)).foregroundStyle(T.muted)
                }

                regulationLinks(a)
                parentLink(a)

                HStack(spacing: 10) {
                    tile("نسخ", icon: "doc.on.doc") {
                        Clipboard.copy(Clipboard.plain(a, law: law)); flash("نُسخ النص")
                    }
                    tile("للتسبيب", icon: "text.alignright") {
                        Clipboard.copy(Clipboard.forReasoning(a, law: law)); flash("نُسخ بصيغة التسبيب")
                    }
                    tile(store.isSaved(a) ? "محفوظة" : "احفظ", icon: store.isSaved(a) ? "bookmark.fill" : "bookmark",
                         tint: store.isSaved(a) ? T.amber : T.accent) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { store.toggleSave(a) }
                    }
                }
                if let toast {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(F.ui(13, .semibold)).foregroundStyle(T.green)
                        .frame(maxWidth: .infinity)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(verbatim: law.source ?? "").font(F.ui(11)).foregroundStyle(T.muted).padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func regulationLinks(_ a: Article) -> some View {
        let regs = lib.regulationLinks(for: a)
        if regs.count == 1, let r = regs.first {
            Button { nav.open(.article(r.key)) } label: {
                HStack(spacing: 12) {
                    Text(verbatim: r.label)
                        .font(F.ui(13, .bold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("لها في اللائحة التنفيذية مادة واحدة").font(F.ui(14))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward").font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Color(hex: 0x78350F))
                .padding(14)
                .background(T.amberSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.press)
        } else if regs.count > 1 {
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: "لها في اللائحة التنفيذية \(regs.count) \(regs.count <= 10 ? "مواد" : "مادة")")
                    .font(F.ui(14, .semibold)).foregroundStyle(Color(hex: 0x78350F))
                FlowLayout(spacing: 8) {
                    ForEach(regs) { r in
                        Button { nav.open(.article(r.key)) } label: {
                            Text(verbatim: r.label)
                                .font(F.ui(13, .bold))
                                .foregroundStyle(Color(hex: 0x78350F))
                                .padding(.horizontal, 12)
                                .frame(minHeight: 38)
                                .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.press)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(T.amberSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    @ViewBuilder
    private func parentLink(_ a: Article) -> some View {
        if law.kind == .reg, let ref = a.ref, let pid = law.parent, let p = lib.law(pid),
           let target = p.articles.first(where: { $0.n == ref }) {
            Button { nav.open(.article(target.key)) } label: {
                HStack(spacing: 12) {
                    NumberBadge(text: ref)
                    Text(verbatim: "افتح المادة (\(ref)) من \(p.name)").font(F.ui(14, .semibold)).foregroundStyle(T.accent)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward").font(.system(size: 13, weight: .bold)).foregroundStyle(T.accent)
                }
                .padding(12)
                .card(radius: 20)
            }
            .buttonStyle(.press)
        }
    }

    private func tile(_ title: String, icon: String, tint: Color = T.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
                Text(title).font(F.ui(13)).foregroundStyle(T.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .card(radius: 20)
        }
        .buttonStyle(.press)
    }

    private func flash(_ s: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { toast = s }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { if toast == s { toast = nil } }
        }
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
                    .background(T.accentSoft, in: Capsule())
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
