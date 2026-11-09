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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        head(law)
                        if searching { searchField }
                        tabs
                        switch tab {
                        case 1: partsList(law, proxy: proxy)
                        case 2: savedList(law)
                        default: articles(law)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .onChange(of: jumpTo) { _, id in
                    guard let id else { return }
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                    jumpTo = nil
                }
            }
            .background(T.bg.ignoresSafeArea())
            .navigationTitle(law.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { withAnimation { searching.toggle() } } label: { Image(systemName: "magnifyingglass") }
                        .accessibilityLabel("بحث في هذا النظام")
                }
            }
            .keyboardDone()
        } else {
            Text("ما لقيت هذا النظام").font(F.ui(15)).foregroundStyle(T.muted)
        }
    }

    private func head(_ law: Law) -> some View {
        let c = T.catColors(law.cat)
        let lib = Library.shared
        let kids = lib.children(of: law)
        let parent = law.parent.flatMap { lib.law($0) }
        return VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: law.name).font(F.title(23)).foregroundStyle(T.ink)
            Text(verbatim: "\(law.kind.label) · \(law.countText)" + (law.parts.isEmpty ? "" : " · \(law.parts.count) \(law.parts.count <= 10 ? "أبواب وفصول" : "باباً وفصلاً")"))
                .font(F.ui(12)).foregroundStyle(T.muted)
            if let d = law.decree, !d.isEmpty {
                Text(verbatim: d).font(F.ui(12)).foregroundStyle(c.ink)
            }
            if let parent {
                Button { nav.open(.law(parent.id)) } label: {
                    Label { Text(verbatim: "صادرة لـ \(parent.name)") } icon: { Image(systemName: "arrow.uturn.up") }
                        .font(F.ui(13, .semibold))
                }
            }
            if !kids.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(kids) { k in
                            Button { nav.open(.law(k.id)) } label: {
                                Text(verbatim: k.name.replacingOccurrences(of: " " + law.name, with: ""))
                                    .font(F.ui(12, .semibold))
                                    .foregroundStyle(T.sandInk)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 34)
                                    .background(T.sand, in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.sandLine))
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
            TextField("", text: $query, prompt: Text("ابحث في هذا النظام أو اكتب رقم المادة").foregroundStyle(T.muted))
                .font(F.ui(15))
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(T.muted) }
                    .accessibilityLabel("مسح")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .card(radius: 14)
    }

    private var tabs: some View {
        HStack(spacing: 22) {
            tabButton("المواد", 0)
            tabButton("الأبواب", 1)
            tabButton("محفوظ منه", 2)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func tabButton(_ title: String, _ i: Int) -> some View {
        Button { tab = i } label: {
            VStack(spacing: 6) {
                Text(title).font(F.ui(14, tab == i ? .bold : .regular)).foregroundStyle(tab == i ? T.accent : T.muted)
                Rectangle().fill(tab == i ? T.accent : Color.clear).frame(height: 3)
            }
            .fixedSize()
            .frame(minHeight: 40)
        }
        .buttonStyle(.plain)
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
                        Text(verbatim: p).font(F.ui(13, .bold)).foregroundStyle(T.ink)
                            .padding(.top, 10).padding(.horizontal, 4)
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
            .buttonStyle(.plain)
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
