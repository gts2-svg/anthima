import SwiftUI

/// «بحث» across every law: by meaning (tolerant of spelling slips) or by article number.
struct SearchView: View {
    @ObservedObject private var nav = AppNav.shared
    @ObservedObject private var lib = Library.shared
    @State private var query = ""
    @State private var scope: String? = nil
    @State private var hits: [SearchHit] = []
    @State private var numbered: [Article] = []
    @State private var pending: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                field
                scopePicker
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    tips
                } else if !lib.indexReady {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("يجهّز الفهرس…").font(F.ui(14)).foregroundStyle(T.muted)
                    }
                    .padding(.vertical, 20)
                } else if hits.isEmpty && numbered.isEmpty {
                    Text("ما فيه نتائج. جرّب كلمة ثانية، أو اسأل من تبويب «اسأل» بكلامك.")
                        .font(F.ui(14)).foregroundStyle(T.muted).padding(.vertical, 20)
                } else {
                    results
                }
            }
            .padding(16)
        }
        .background(T.bg.ignoresSafeArea())
        .navigationTitle("بحث")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDone()
        .onAppear(perform: takeDraft)
        .onChange(of: nav.searchDraft) { _, _ in takeDraft() }
        .onChange(of: query) { _, _ in schedule() }
        .onChange(of: scope) { _, _ in schedule() }
        .onChange(of: lib.indexReady) { _, _ in schedule() }
    }

    private func takeDraft() {
        if let d = nav.searchDraft {
            query = d
            nav.searchDraft = nil
        }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
            TextField("", text: $query, prompt: Text("اكتب المعنى أو رقم المادة…").foregroundStyle(T.muted))
                .font(F.ui(16))
                .focused($focused)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(T.muted) }
                    .accessibilityLabel("مسح")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .card(radius: 14)
    }

    private var scopePicker: some View {
        Menu {
            Button("كل الأنظمة") { scope = nil }
            ForEach(Library.shared.laws) { l in
                Button(l.name) { scope = l.id }
            }
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: scope.flatMap { Library.shared.law($0)?.name } ?? "كل الأنظمة")
                    .font(F.ui(13, .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(T.accent)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(T.accentSoft, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("أمثلة").font(F.ui(13, .bold)).foregroundStyle(T.muted)
            ForEach(["المادة 30 مرافعات", "الماده الثلاثون من نظام الاثبات", "مدة الاستيناف", "شروط قبول الدعوي", "التعويض عن الضرر المعنوي"], id: \.self) { ex in
                Button { query = ex } label: {
                    HStack {
                        Text(verbatim: ex).font(F.ui(14)).foregroundStyle(T.ink)
                        Spacer()
                        Image(systemName: "arrow.up.left").font(.system(size: 12)).foregroundStyle(T.muted)
                    }
                    .padding(14)
                    .card(radius: 14)
                }
                .buttonStyle(.plain)
            }
            Text("ما يهم الهمزات ولا التاء المربوطة ولا الأخطاء البسيطة.")
                .font(F.ui(12)).foregroundStyle(T.muted)
        }
    }

    private var results: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            if !numbered.isEmpty {
                Text("بالرقم").font(F.ui(13, .bold)).foregroundStyle(T.muted)
                ForEach(numbered) { a in link(a, preview: nil) }
            }
            if !hits.isEmpty {
                Text(verbatim: "بالمعنى · \(hits.count)").font(F.ui(13, .bold)).foregroundStyle(T.muted).padding(.top, numbered.isEmpty ? 0 : 8)
                ForEach(hits) { h in link(h.article, preview: SearchIndex.snippet(h.article.text, query: query)) }
            }
        }
    }

    private func link(_ a: Article, preview: String?) -> some View {
        Button { nav.open(.article(a.key)) } label: { ArticleRow(article: a, preview: preview, showLaw: true) }
            .buttonStyle(.plain)
    }

    private func schedule() {
        pending?.cancel()
        let q = query, s = scope
        pending = Task {
            try? await Task.sleep(nanoseconds: 220_000_000)
            if Task.isCancelled { return }
            let idx = Library.shared.index
            let result = await Task.detached(priority: .userInitiated) { () -> ([Article], [SearchHit]) in
                let n = idx.numberLookup(q, in: s)
                let h = idx.search(q, in: s, limit: 60).filter { hit in !n.contains { $0.id == hit.article.id } }
                return (n, h)
            }.value
            if Task.isCancelled { return }
            numbered = result.0
            hits = result.1
        }
    }
}
