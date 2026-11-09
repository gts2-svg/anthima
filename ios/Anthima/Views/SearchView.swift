import SwiftUI

/// «بحث» across every law: by meaning (tolerant of spelling slips) or by article number.
struct SearchView: View {
    @ObservedObject private var nav = AppNav.shared
    @ObservedObject private var lib = Library.shared
    @ObservedObject private var store = UserStore.shared
    @State private var query = ""
    @State private var scope: String? = nil
    @State private var hits: [SearchHit] = []
    @State private var numbered: [Article] = []
    @State private var pending: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("بحث").font(F.title(28)).foregroundStyle(T.ink).padding(.top, 4)
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
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: hits.count)
        }
        .background(T.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
            Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .semibold)).foregroundStyle(T.accent)
            TextField("", text: $query, prompt: Text("اكتب المعنى أو رقم المادة").foregroundStyle(T.muted))
                .font(F.ui(16))
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { store.rememberSearch(query) }
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(T.muted) }
                    .accessibilityLabel("مسح")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .background(Capsule().fill(Color.white).shadow(color: T.accent.opacity(0.12), radius: 14, x: 0, y: 6))
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
            .background(T.accentSoft, in: Capsule())
        }
    }

    /// Before typing: your recent searches (if any) and a short line on what works.
    private var tips: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.recentSearches.isEmpty {
                HStack {
                    Text("بحثت عنها مؤخراً").font(F.ui(14, .semibold)).foregroundStyle(T.ink)
                    Spacer()
                    Button("مسح") { withAnimation { store.recentSearches = [] } }
                        .font(F.ui(13)).foregroundStyle(T.muted)
                }
                FlowLayout(spacing: 8) {
                    ForEach(store.recentSearches, id: \.self) { q in
                        Button { query = q } label: {
                            Label(q, systemImage: "clock.arrow.circlepath")
                                .font(F.ui(14))
                                .foregroundStyle(T.ink)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 40)
                                .background(Capsule().fill(Color.white).shadow(color: Color(hex: 0x111827).opacity(0.05), radius: 6, x: 0, y: 2))
                        }
                        .buttonStyle(.press)
                    }
                }
            }
            VStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(T.accent)
                    .frame(width: 72, height: 72)
                    .background(T.accentSoft, in: Circle())
                Text("اكتب بالمعنى أو برقم المادة").font(F.ui(16, .semibold)).foregroundStyle(T.ink)
                Text("ولو فيها خطأ إملائي، يفهمها.").font(F.ui(14)).foregroundStyle(T.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, store.recentSearches.isEmpty ? 50 : 24)
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
        Button {
            store.rememberSearch(query)
            nav.open(.article(a.key))
        } label: { ArticleRow(article: a, preview: preview, showLaw: true) }
            .buttonStyle(.press)
            .softScroll()
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
