import SwiftUI

/// «المكتبة» — design ج: dark header with the title and name, search, the laws by section.
struct LibraryView: View {
    @ObservedObject private var lib = Library.shared
    @ObservedObject private var nav = AppNav.shared
    @ObservedObject private var store = UserStore.shared
    @State private var query = ""
    @State private var cat: String? = nil

    private var shown: [Law] {
        lib.laws.filter { cat == nil || $0.cat == cat }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                VStack(alignment: .leading, spacing: 14) {
                    shortcuts
                    HStack(alignment: .firstTextBaseline) {
                        Text("الأنظمة").font(F.ui(17, .bold)).foregroundStyle(T.ink)
                        Spacer()
                        Text(verbatim: "\(lib.laws.count) نظاماً ولائحة · \(lib.articleCount) مادة")
                            .font(F.ui(12)).foregroundStyle(T.muted)
                    }
                    categories
                    LazyVStack(spacing: 8) {
                        ForEach(shown) { law in
                            Button { nav.open(.law(law.id)) } label: { LawRow(law: law) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
        .keyboardDone()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("مكتبة الأنظمة الخاصة").font(F.title(27)).foregroundStyle(.white)
                    Text("جبران طالع التليدي").font(F.ruqaa(19)).foregroundStyle(T.gold)
                }
                Spacer()
                Button { nav.open(.settings) } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("الإعدادات")
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
                TextField("", text: $query, prompt: Text("مثال: مدة الاعتراض على الحكم").foregroundStyle(T.muted))
                    .font(F.ui(15))
                    .foregroundStyle(T.ink)
                    .submitLabel(.search)
                    .onSubmit(goSearch)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["المادة 30 مرافعات", "الدليل الناقص", "م 77 إثبات", "التعويض عن الضرر"], id: \.self) { ex in
                        Button { query = ex; goSearch() } label: {
                            Text(verbatim: "«\(ex)»")
                                .font(F.ui(12))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 62)
        .padding(.bottom, 22)
        .background(T.ink, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private func goSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        nav.searchDraft = q
        nav.tab = 1
    }

    private var shortcuts: some View {
        HStack(spacing: 10) {
            Button { nav.tab = 2 } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "bubble.left.and.text.bubble.right").font(.system(size: 20))
                    Text("اسأل").font(F.ui(16, .bold))
                    Text("جواب بنص المادة").font(F.ui(12)).foregroundStyle(Color(hex: 0xD6E5F0))
                }
                .foregroundStyle(.white)
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                .card(T.accent, radius: 18)
            }
            .buttonStyle(.plain)

            Button {
                if let k = store.lastRead { nav.open(.article(k)) }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 20)).foregroundStyle(T.accent)
                    Text("آخر ما قرأت").font(F.ui(16, .bold)).foregroundStyle(T.ink)
                    Text(verbatim: lastReadText).font(F.ui(12)).foregroundStyle(T.muted).lineLimit(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                .card(radius: 18)
            }
            .buttonStyle(.plain)
            .disabled(store.lastRead == nil)
        }
    }

    private var lastReadText: String {
        guard let k = store.lastRead, let a = lib.article(key: k), let law = lib.law(a.lawID) else {
            return "لسا ما قرأت شيئاً"
        }
        let short = law.name.replacingOccurrences(of: "نظام ", with: "").replacingOccurrences(of: "اللائحة التنفيذية ل", with: "لائحة ")
        return "\(short) · \(a.badge)"
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Button { cat = nil } label: { Chip(text: "الكل", on: cat == nil) }
                ForEach(lib.categories) { c in
                    let n = lib.laws.filter { $0.cat == c.id }.count
                    if n > 0 {
                        Button { cat = c.id } label: { Chip(text: "\(c.name) \(n)", on: cat == c.id) }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct LawRow: View {
    let law: Law

    var body: some View {
        let c = T.catColors(law.cat)
        HStack(spacing: 12) {
            Text(verbatim: law.kind == .law ? c.short : law.kind.label)
                .font(F.ui(12, .bold))
                .foregroundStyle(law.kind == .law ? c.ink : T.sandInk)
                .frame(width: 44, height: 44)
                .background(law.kind == .law ? c.soft : T.sand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: law.name).font(F.ui(15, .semibold)).foregroundStyle(T.ink).multilineTextAlignment(.leading)
                Text(verbatim: law.countText).font(F.ui(12)).foregroundStyle(T.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .card()
    }
}
