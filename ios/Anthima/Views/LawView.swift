import SwiftUI

/// One law, regulation or rules document: its articles, its parts, and what you saved from it.
struct LawView: View {
    let lawID: String
    @ObservedObject private var nav = AppNav.shared
    @ObservedObject private var store = UserStore.shared
    @ObservedObject private var lib = Library.shared
    @State private var tab = 0
    @State private var query = ""
    @State private var searching = false
    @State private var jumpTo: String?

    private var law: Law? { Library.shared.law(lawID) }

    var body: some View {
        if let law {
            let sec = T.section(law.cat)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        head(law)
                        if searching { searchField.transition(.move(edge: .top).combined(with: .opacity)) }
                        partChips(law)
                        switch tab {
                        case 2: savedList(law)
                        default: articles(law)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
                .onChange(of: jumpTo) { _, id in
                    guard let id else { return }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { proxy.scrollTo(id, anchor: .top) }
                    jumpTo = nil
                }
            }
            .background(
                LinearGradient(colors: [sec.soft, T.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.3)).ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { searching.toggle() }
                    } label: { Image(systemName: searching ? "xmark" : "magnifyingglass") }
                        .accessibilityLabel("بحث في هذا النظام")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button { nav.askScope = law.id; nav.askDraft = ""; nav.tab = 2 } label: {
                    Label { Text(verbatim: "اسأل عن \(law.name)").lineLimit(1) } icon: { Image(systemName: "sparkles") }
                        .font(F.ui(15, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background {
                            Capsule().fill(T.accent).shadow(color: T.accent.opacity(0.35), radius: 14, x: 0, y: 8)
                        }
                }
                .buttonStyle(.press)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .keyboardDone()
        } else {
            Text("ما لقيت هذا النظام").font(F.ui(15)).foregroundStyle(T.muted)
        }
    }

    private func head(_ law: Law) -> some View {
        let sec = T.section(law.cat)
        let lib = Library.shared
        let kids = lib.children(of: law)
        let parent = law.parent.flatMap { lib.law($0) }
        let partsText = law.parts.isEmpty ? "" : " · \(law.parts.count) \(law.parts.count <= 10 ? "أبواب وفصول" : "باباً وفصلاً")"
        return VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: lib.categoryName(law.cat)).font(F.ui(13, .semibold)).foregroundStyle(sec.ink)
            Text(verbatim: law.name).font(F.title(28)).foregroundStyle(T.ink).fixedSize(horizontal: false, vertical: true)
            Text(verbatim: "\(law.kind.label) · \(law.countText)" + partsText)
                .font(F.ui(13)).foregroundStyle(T.muted)
            if let d = law.decree, !d.isEmpty {
                Text(verbatim: d).font(F.ui(12)).foregroundStyle(T.muted)
            }
            if let parent {
                Button { nav.open(.law(parent.id)) } label: {
                    Label { Text(verbatim: "صادرة لـ \(parent.name)") } icon: { Image(systemName: "arrow.uturn.up") }
                        .font(F.ui(13, .semibold))
                        .foregroundStyle(T.accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 38)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.press)
                .padding(.top, 4)
            }
            if !kids.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(kids) { k in
                            Button { nav.open(.law(k.id)) } label: {
                                Label { Text(verbatim: k.name.replacingOccurrences(of: " " + law.name, with: "")) } icon: {
                                    Image(systemName: "list.bullet.rectangle")
                                }
                                .font(F.ui(13, .semibold))
                                .foregroundStyle(T.amberInk)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 38)
                                .background(T.amberSoft, in: Capsule())
                            }
                            .buttonStyle(.press)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(T.accent)
            TextField("", text: $query, prompt: Text("ابحث في هذا النظام أو اكتب رقم المادة").foregroundStyle(T.muted))
                .font(F.ui(15))
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(T.muted) }
                    .accessibilityLabel("مسح")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(Capsule().fill(Color.white).shadow(color: T.accent.opacity(0.10), radius: 10, x: 0, y: 4))
    }

    /// «الكل», then each part, then «المحفوظ» — tap a part to slide to it.
    private func partChips(_ law: Law) -> some View {
        let savedCount = law.articles.filter { store.saved.contains($0.key) }.count
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { withAnimation { tab = 0 } } label: { Chip(text: "الكل", on: tab == 0 && query.isEmpty) }
                if savedCount > 0 {
                    Button { withAnimation { tab = 2 } } label: { Chip(text: "★ المحفوظ \(savedCount)", on: tab == 2) }
                }
                ForEach(law.parts, id: \.self) { p in
                    Button {
                        tab = 0
                        query = ""
                        let target = LawView.firstRowID(of: p, in: law)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { jumpTo = target }
                    } label: { Chip(text: LawView.shortPart(p)) }
                }
            }
            .buttonStyle(.press)
            .padding(.vertical, 2)
        }
    }

    /// «الباب الأول: أحكام عامة» → «أحكام عامة».
    static func shortPart(_ p: String) -> String {
        if let r = p.range(of: ":") {
            let rest = p[r.upperBound...].trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { return String(rest.prefix(28)) }
        }
        let words = p.split(separator: " ")
        if words.count > 2, ["الباب", "الفصل", "الفرع", "القسم"].contains(String(words[0])) {
            return words.dropFirst(2).joined(separator: " ").prefix(28).description
        }
        return String(p.prefix(28))
    }

    @ViewBuilder
    private func articles(_ law: Law) -> some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty && !lib.indexReady {
            HStack(spacing: 8) {
                ProgressView()
                Text("يجهّز الفهرس…").font(F.ui(14)).foregroundStyle(T.muted)
            }
            .padding(.vertical, 20)
        } else if !q.isEmpty {
            let idx = Library.shared.index
            let byNumber = idx.numberLookup(q, in: law.id)
            let hits = idx.search(q, in: law.id, limit: 80)
            if byNumber.isEmpty && hits.isEmpty {
                Text("ما فيه نتائج في هذا النظام.").font(F.ui(14)).foregroundStyle(T.muted).padding(.vertical, 20)
            }
            LazyVStack(spacing: 8) {
                ForEach(byNumber) { a in row(a) }
                ForEach(hits.filter { h in !byNumber.contains { $0.id == h.article.id } }) { h in
                    row(h.article, preview: SearchIndex.snippet(h.article.text, query: q))
                }
            }
        } else {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(LawView.rows(law)) { r in
                    switch r.kind {
                    case .part(let p):
                        Text(verbatim: p).font(F.title(16, heavy: false)).foregroundStyle(T.ink)
                            .padding(.top, 12).padding(.horizontal, 4)
                    case .chapter(let c):
                        Text(verbatim: c).font(F.ui(12, .semibold)).foregroundStyle(T.muted)
                            .padding(.horizontal, 4)
                    case .article(let a):
                        row(a)
                    }
                }
            }
        }
    }

    struct ListRow: Identifiable {
        enum Kind { case part(String), chapter(String), article(Article) }
        let id: String
        let kind: Kind
    }

    /// Articles with their part and chapter titles in between, each with a unique id.
    static func rows(_ law: Law) -> [ListRow] {
        var out: [ListRow] = []
        var lastPart = "", lastChapter = ""
        for (i, a) in law.articles.enumerated() {
            let p = a.part ?? "", c = a.chapter ?? ""
            if !p.isEmpty && p != lastPart {
                out.append(ListRow(id: "part-\(i)", kind: .part(p)))
                lastChapter = ""
            }
            if !c.isEmpty && c != lastChapter {
                out.append(ListRow(id: "chapter-\(i)", kind: .chapter(c)))
            }
            lastPart = p
            lastChapter = c
            out.append(ListRow(id: a.id, kind: .article(a)))
        }
        return out
    }

    /// The row id of the first title of a part, for «الأبواب».
    static func firstRowID(of part: String, in law: Law) -> String? {
        rows(law).first { r in
            if case .part(let p) = r.kind { return p == part }
            return false
        }?.id
    }

    private func row(_ a: Article, preview: String? = nil) -> some View {
        Button { nav.open(.article(a.key)) } label: { ArticleRow(article: a, preview: preview) }
            .buttonStyle(.press)
            .softScroll()
    }

    private func partsList(_ law: Law, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            if law.parts.isEmpty {
                Text("هذا النص ما فيه أبواب.").font(F.ui(14)).foregroundStyle(T.muted).padding(.vertical, 20)
            }
            ForEach(law.parts, id: \.self) { p in
                let count = law.articles.filter { $0.part == p && !$0.n.isEmpty }.count
                Button {
                    tab = 0
                    query = ""
                    let target = LawView.firstRowID(of: p, in: law)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { jumpTo = target }
                } label: {
                    HStack {
                        Text(verbatim: p).font(F.ui(14, .semibold)).foregroundStyle(T.ink).multilineTextAlignment(.leading)
                        Spacer()
                        Text(verbatim: "\(count)").font(F.ui(12)).foregroundStyle(T.muted)
                    }
                    .padding(14)
                    .card()
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func savedList(_ law: Law) -> some View {
        let mine = law.articles.filter { store.saved.contains($0.key) }
        if mine.isEmpty {
            Text("ما حفظت شيئاً من هذا النظام. اضغط على علامة الحفظ في أي مادة.")
                .font(F.ui(14)).foregroundStyle(T.muted).padding(.vertical, 20)
        }
        LazyVStack(spacing: 8) {
            ForEach(mine) { a in row(a) }
        }
    }
}
