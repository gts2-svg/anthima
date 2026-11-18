import SwiftUI

// iPad: the same screens as the iPhone, arranged for a large screen.
// Wide (landscape): a sidebar on the right, and a law opens as two columns — its articles beside the article.
// Narrow (portrait): a floating tab bar at the top, and a law shows either its list or the article,
// with «المواد» to switch. When the app gets a narrow window (Split View), the system switches it to
// the iPhone layout by itself.

private struct PadWideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True on an iPad window wide enough for the sidebar and two columns.
    var padWide: Bool {
        get { self[PadWideKey.self] }
        set { self[PadWideKey.self] = newValue }
    }
}

/// Keeps a screen's scrolling content at a comfortable reading width on a large screen.
struct PadReadable: ViewModifier {
    var maxWidth: CGFloat = 860

    func body(content: Content) -> some View {
        GeometryReader { geo in
            content.contentMargins(.horizontal, max(0, (geo.size.width - maxWidth) / 2), for: .scrollContent)
        }
    }
}

extension View {
    func padReadable(_ maxWidth: CGFloat = 860) -> some View { modifier(PadReadable(maxWidth: maxWidth)) }
}

private struct PadTab {
    let title: String
    let icon: String
    let iconOn: String
}

private let padTabs = [
    PadTab(title: "الرئيسية", icon: "house", iconOn: "house.fill"),
    PadTab(title: "بحث", icon: "magnifyingglass", iconOn: "magnifyingglass"),
    PadTab(title: "اسأل", icon: "sparkles", iconOn: "sparkles"),
    PadTab(title: "المحفوظات", icon: "bookmark", iconOn: "bookmark.fill"),
]

struct PadRoot: View {
    @ObservedObject private var nav = AppNav.shared
    @State private var sidebarOpen = false

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 1000
            Group {
                if wide {
                    HStack(spacing: 0) {
                        PadSideNav(full: !isReading || sidebarOpen, canCollapse: isReading, sidebarOpen: $sidebarOpen)
                        Rectangle().fill(T.line).frame(width: 1).ignoresSafeArea()
                        stacks
                    }
                } else {
                    VStack(spacing: 0) {
                        PadTopBar()
                        stacks
                    }
                }
            }
            .environment(\.padWide, wide)
        }
        .background(T.bg.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: nav.tab)
    }

    /// A law, an article or a comparison is open: the sidebar shrinks to icons to leave room for reading.
    private var isReading: Bool {
        guard let last = currentPath.last else { return false }
        switch last {
        case .law, .article, .comparison: return true
        default: return false
        }
    }

    private var currentPath: [Nav] {
        switch nav.tab {
        case 1: return nav.search
        case 2: return nav.ask
        case 3: return nav.saved
        default: return nav.library
        }
    }

    private var stacks: some View {
        ZStack {
            stack(0, path: $nav.library) { LibraryView() }
            stack(1, path: $nav.search) { SearchView().padReadable() }
            stack(2, path: $nav.ask) { AskView().padReadable() }
            stack(3, path: $nav.saved) { SavedView().padReadable() }
        }
    }

    private func stack<Root: View>(_ i: Int, path: Binding<[Nav]>, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: path) {
            root().navigationDestination(for: Nav.self) { n in PadRoot.destination(n) }
        }
        .opacity(nav.tab == i ? 1 : 0)
        .allowsHitTesting(nav.tab == i)
        .accessibilityHidden(nav.tab != i)
    }

    @ViewBuilder
    static func destination(_ n: Nav) -> some View {
        switch n {
        case .category(let id): CategoryView(catID: id).padReadable()
        case .law(let id): PadReader(lawID: id, startKey: nil)
        case .article(let key): PadReader(lawID: Library.shared.article(key: key)?.lawID ?? "", startKey: key)
        case .comparison(let key): ComparisonView(key: key).padReadable()
        case .settings: SettingsView().padReadable()
        }
    }

    /// Tapping the tab you are on goes back to its first screen.
    static func select(_ i: Int) {
        let nav = AppNav.shared
        if nav.tab == i {
            switch i {
            case 1: nav.search = []
            case 2: nav.ask = []
            case 3: nav.saved = []
            default: nav.library = []
            }
        } else {
            nav.tab = i
        }
    }
}

/// The sidebar (wide): the four sections and the settings. While reading it shrinks to icons.
struct PadSideNav: View {
    let full: Bool
    let canCollapse: Bool
    @Binding var sidebarOpen: Bool
    @ObservedObject private var nav = AppNav.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if canCollapse {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { sidebarOpen.toggle() }
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(T.muted)
                        .frame(width: 50, height: 50)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.press)
                .accessibilityLabel(Text(verbatim: full ? "تصغير الشريط الجانبي" : "إظهار الشريط الجانبي"))
                .padding(.bottom, 4)
            } else {
                Text("التطبيق").font(F.ui(13)).foregroundStyle(T.muted)
                    .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 8)
            }
            ForEach(padTabs.indices, id: \.self) { i in
                item(padTabs[i].title, icon: nav.tab == i ? padTabs[i].iconOn : padTabs[i].icon, on: nav.tab == i) {
                    PadRoot.select(i)
                }
            }
            Spacer(minLength: 0)
            item("الإعدادات", icon: "gearshape", on: false, muted: true) {
                nav.tab = 0
                nav.library = [.settings]
            }
        }
        .padding(.horizontal, full ? 16 : 13)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: full ? 250 : 76, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.75).ignoresSafeArea())
    }

    private func item(_ title: String, icon: String, on: Bool, muted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 26)
                if full {
                    Text(title).font(F.ui(17, on ? .semibold : .medium)).lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(on ? T.accent : (muted ? T.muted : T.ink))
            .padding(.horizontal, full ? 14 : 0)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(on ? T.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .accessibilityLabel(title)
    }
}

/// The floating tab bar at the top (portrait).
struct PadTopBar: View {
    @ObservedObject private var nav = AppNav.shared

    var body: some View {
        HStack(spacing: 4) {
            ForEach(padTabs.indices, id: \.self) { i in
                let on = nav.tab == i
                Button { PadRoot.select(i) } label: {
                    Label { Text(padTabs[i].title) } icon: { Image(systemName: on ? padTabs[i].iconOn : padTabs[i].icon) }
                        .font(F.ui(16, on ? .semibold : .regular))
                        .foregroundStyle(on ? T.accent : T.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(on ? T.accentSoft : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.press)
            }
        }
        .padding(5)
        .background {
            Capsule().fill(Color.white).shadow(color: Color(hex: 0x111827).opacity(0.08), radius: 12, x: 0, y: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(T.bg.ignoresSafeArea(edges: .top))
    }
}

/// A law on the iPad. Wide: its articles in a column beside the open article.
/// Narrow: the list or the article, with «المواد» to go between them.
struct PadReader: View {
    let lawID: String
    let startKey: String?
    @Environment(\.padWide) private var wide
    /// The article opened from the list (a new choice rebuilds the reading pane).
    @State private var opened: String?
    /// The article on screen, which moves as you turn pages (marks the row in the list).
    @State private var shown: String?
    /// Narrow only: the list is showing instead of the article.
    @State private var listShown: Bool
    /// Wide only: the list column is hidden.
    @State private var listHidden = false

    init(lawID: String, startKey: String?) {
        self.lawID = lawID
        self.startKey = startKey
        _opened = State(initialValue: startKey)
        _shown = State(initialValue: startKey)
        _listShown = State(initialValue: startKey == nil)
    }

    private var firstKey: String? { Library.shared.law(lawID)?.articles.first?.key }

    var body: some View {
        // Wide with nothing chosen yet: open the first article so the reading side is never empty.
        let current = opened ?? (wide ? firstKey : nil)
        let marked = shown ?? current
        Group {
            if wide {
                HStack(spacing: 0) {
                    if !listHidden {
                        list(marked: marked, askButton: false)
                            .frame(width: 380)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Rectangle().fill(T.line).frame(width: 1).ignoresSafeArea(edges: .bottom)
                    }
                    reading(current)
                }
            } else if listShown || current == nil {
                list(marked: marked, askButton: true)
            } else {
                reading(current)
            }
        }
        .toolbar {
            if wide || current != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                            if wide { listHidden.toggle() } else { listShown.toggle() }
                        }
                    } label: {
                        Label("المواد", systemImage: "sidebar.right").labelStyle(.titleAndIcon).font(F.ui(15, .semibold))
                    }
                    .accessibilityLabel(Text(verbatim: (wide ? !listHidden : listShown) ? "إخفاء قائمة المواد" : "قائمة المواد"))
                }
            }
        }
    }

    private func list(marked: String?, askButton: Bool) -> some View {
        LawView(lawID: lawID, onSelect: { a in
            withAnimation(.easeOut(duration: 0.2)) {
                opened = a.key
                shown = a.key
                if !wide { listShown = false }
            }
        }, selectedKey: marked, showsAskButton: askButton)
    }

    @ViewBuilder
    private func reading(_ key: String?) -> some View {
        if let key {
            ArticleView(startKey: key, onPageChange: { a in shown = a.key })
                .id(key)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text").font(.system(size: 34, weight: .semibold)).foregroundStyle(T.accent)
                Text("اختر مادة من القائمة").font(F.ui(17, .semibold)).foregroundStyle(T.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(T.bg.ignoresSafeArea())
        }
    }
}
