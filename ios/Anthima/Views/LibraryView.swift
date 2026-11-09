import SwiftUI

/// «الرئيسية» — design «صباح»: greeting, the search pill, «اسأل», the sections as soft
/// coloured tiles, and «كمّل من حيث وقفت».
struct LibraryView: View {
    @ObservedObject private var lib = Library.shared
    @ObservedObject private var nav = AppNav.shared
    @ObservedObject private var store = UserStore.shared
    @State private var query = ""
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                searchPill
                askCard
                continueCard
                sections
                allLaws
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
        }
        .background(T.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .keyboardDone()
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { appeared = true }
        }
    }

    private var greeting: String {
        let h = Calendar(identifier: .gregorian).component(.hour, from: Date())
        return h < 12 ? "صباح الخير" : "مساء الخير"
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: greeting).font(F.ui(14)).foregroundStyle(T.muted)
                Text("مكتبة الأنظمة الخاصة").font(F.title(26)).foregroundStyle(T.ink)
                Text("جبران طالع التليدي").font(F.ruqaa(19)).foregroundStyle(T.gold)
            }
            Spacer()
            Button { nav.open(.settings) } label: { RoundIcon(system: "gearshape", size: 46) }
                .buttonStyle(.press)
                .accessibilityLabel("الإعدادات")
        }
        .padding(.top, 8)
    }

    private var searchPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .semibold)).foregroundStyle(T.accent)
            TextField("", text: $query, prompt: Text("ابحث بالمعنى أو برقم المادة").foregroundStyle(T.muted))
                .font(F.ui(16))
                .foregroundStyle(T.ink)
                .submitLabel(.search)
                .onSubmit(goSearch)
        }
        .padding(.horizontal, 20)
        .frame(height: 58)
        .background {
            Capsule().fill(Color.white).shadow(color: T.accent.opacity(0.12), radius: 14, x: 0, y: 6)
        }
    }

    private func goSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        nav.searchDraft = q
        query = ""
        nav.tab = 1
    }

    private var askCard: some View {
        Button { nav.tab = 2 } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("اسأل الأنظمة").font(F.ui(17, .bold))
                    Text("اكتب سؤالك، يجيك الجواب بنص المادة").font(F.ui(13)).foregroundStyle(Color(hex: 0xE0E7FF))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.system(size: 14, weight: .bold)).foregroundStyle(Color(hex: 0xC7D2FE))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x6366F1), T.accent], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: T.accent.opacity(0.30), radius: 16, x: 0, y: 8)
            }
        }
        .buttonStyle(.press)
    }

    @ViewBuilder
    private var continueCard: some View {
        if let k = store.lastRead, let a = lib.article(key: k), let law = lib.law(a.lawID) {
            Button { nav.open(.article(k)) } label: {
                HStack(spacing: 12) {
                    NumberBadge(text: a.badge)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("كمّل من حيث وقفت").font(F.ui(12)).foregroundStyle(T.muted)
                        Text(verbatim: law.name).font(F.ui(15, .semibold)).foregroundStyle(T.ink).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(T.muted)
                }
                .padding(14)
                .card(radius: 22)
            }
            .buttonStyle(.press)
        }
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("الأقسام").font(F.title(19, heavy: false)).foregroundStyle(T.ink)
                Spacer()
                Text(verbatim: "\(lib.laws.count) نظاماً ولائحة · \(lib.articleCount) مادة").font(F.ui(12)).foregroundStyle(T.muted)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(lib.categories) { c in
                    let n = lib.laws.filter { $0.cat == c.id }.count
                    if n > 0 {
                        Button { nav.open(.category(c.id)) } label: { SectionTile(cat: c, count: n) }
                            .buttonStyle(.press)
                            .zoomSource("cat-\(c.id)")
                    }
                }
            }
        }
    }

    private var allLaws: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("كل الأنظمة واللوائح").font(F.title(19, heavy: false)).foregroundStyle(T.ink).padding(.top, 6)
            LazyVStack(spacing: 10) {
                ForEach(lib.laws) { law in
                    Button { nav.open(.law(law.id)) } label: { LawRow(law: law) }
                        .buttonStyle(.press)
                        .zoomSource("law-\(law.id)")
                        .softScroll()
                }
            }
        }
    }
}

struct SectionTile: View {
    let cat: Category
    let count: Int

    var body: some View {
        let s = T.section(cat.id)
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: s.icon).font(.system(size: 22, weight: .semibold))
            Text(verbatim: cat.name).font(F.ui(16, .bold)).multilineTextAlignment(.leading)
            Text(verbatim: count == 1 ? "نظام واحد" : (count == 2 ? "نظامان" : "\(count) \(count <= 10 ? "أنظمة ولوائح" : "نظاماً ولائحة")"))
                .font(F.ui(12)).opacity(0.75)
        }
        .foregroundStyle(s.ink)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .background(s.soft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct LawRow: View {
    let law: Law

    var body: some View {
        let s = T.section(law.cat)
        HStack(spacing: 12) {
            Image(systemName: law.kind == .law ? s.icon : (law.kind == .reg ? "list.bullet.rectangle" : "checklist"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(law.kind == .law ? s.ink : T.amberInk)
                .frame(width: 46, height: 46)
                .background(law.kind == .law ? s.soft : T.amberSoft, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: law.name).font(F.ui(15, .semibold)).foregroundStyle(T.ink).multilineTextAlignment(.leading)
                Text(verbatim: "\(law.kind.label) · \(law.countText)").font(F.ui(12)).foregroundStyle(T.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(hex: 0x9CA3AF))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .card(radius: 22)
    }
}

/// One section: its laws, regulations and rules.
struct CategoryView: View {
    let catID: String
    @ObservedObject private var nav = AppNav.shared

    var body: some View {
        let lib = Library.shared
        let s = T.section(catID)
        let laws = lib.laws.filter { $0.cat == catID }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: s.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(s.ink)
                        .frame(width: 58, height: 58)
                        .background(s.soft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Text(verbatim: lib.categoryName(catID)).font(F.title(28)).foregroundStyle(T.ink)
                    Text(verbatim: "\(laws.count) \(laws.count <= 10 ? "أنظمة ولوائح" : "نظاماً ولائحة")").font(F.ui(13)).foregroundStyle(T.muted)
                }
                .padding(.bottom, 4)
                LazyVStack(spacing: 10) {
                    ForEach(laws) { law in
                        Button { nav.open(.law(law.id)) } label: { LawRow(law: law) }
                            .buttonStyle(.press)
                            .zoomSource("law-\(law.id)")
                            .softScroll()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(colors: [s.soft, T.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.35)).ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
