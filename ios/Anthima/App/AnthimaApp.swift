import SwiftUI

@main
struct AnthimaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .anthimaEnvironment()
        }
    }
}

enum Nav: Hashable {
    case category(String)
    case law(String)
    case article(String)
    case settings
}

/// Tab selection and the navigation path of each tab.
final class AppNav: ObservableObject {
    static let shared = AppNav()
    @Published var tab = 0
    @Published var library: [Nav] = []
    @Published var search: [Nav] = []
    @Published var ask: [Nav] = []
    @Published var saved: [Nav] = []
    /// Set by «اسأل عن هذه المادة».
    @Published var askDraft: String?
    @Published var askScope: String?
    @Published var searchDraft: String?

    func open(_ n: Nav) {
        switch tab {
        case 1: search.append(n)
        case 2: ask.append(n)
        case 3: saved.append(n)
        default: library.append(n)
        }
    }

    func askAbout(_ a: Article) {
        let law = Library.shared.law(a.lawID)
        askScope = a.lawID
        askDraft = "عن \(a.displayHeading) من \(law?.name ?? ""): "
        tab = 2
    }
}

struct RootView: View {
    @ObservedObject private var lib = Library.shared
    @ObservedObject private var nav = AppNav.shared
    @State private var splashDone = false

    var body: some View {
        ZStack {
            if lib.isLoaded {
                tabs
            }
            if !lib.isLoaded || !splashDone {
                SplashView()
                    .transition(.opacity)
            }
        }
        .task {
            let start = Date()
            Task { await lib.load() }
            while !lib.isLoaded { try? await Task.sleep(nanoseconds: 50_000_000) }
            let left = 1.1 - Date().timeIntervalSince(start)
            if left > 0 { try? await Task.sleep(nanoseconds: UInt64(left * 1_000_000_000)) }
            #if DEBUG
            Demo.apply()
            #endif
            withAnimation(.easeOut(duration: 0.35)) { splashDone = true }
            #if DEBUG
            await Demo.markReady(launch: start)
            #endif
        }
    }

    @Namespace private var zoom

    private var tabs: some View {
        TabView(selection: $nav.tab) {
            NavigationStack(path: $nav.library) {
                LibraryView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("الرئيسية", systemImage: "house") }
            .tag(0)

            NavigationStack(path: $nav.search) {
                SearchView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("بحث", systemImage: "magnifyingglass") }
            .tag(1)

            NavigationStack(path: $nav.ask) {
                AskView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("اسأل", systemImage: "sparkles") }
            .tag(2)

            NavigationStack(path: $nav.saved) {
                SavedView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("المحفوظات", systemImage: "bookmark") }
            .tag(3)
        }
        .environment(\.zoomSpace, zoom)
        .sensoryFeedback(.selection, trigger: nav.tab)
    }

    @ViewBuilder
    private func destination(_ n: Nav) -> some View {
        switch n {
        case .category(let id): CategoryView(catID: id).zoomDestination("cat-\(id)", in: zoom)
        case .law(let id): LawView(lawID: id).zoomDestination("law-\(id)", in: zoom)
        case .article(let key): ArticleView(startKey: key)
        case .settings: SettingsView()
        }
    }
}

/// The opening cover: soft morning colours, the title and the name.
struct SplashView: View {
    @State private var shown = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xE0E7FF), T.bg], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(T.accent)
                    .padding(.bottom, 6)
                Text("مكتبة الأنظمة الخاصة")
                    .font(F.title(30))
                    .foregroundStyle(T.ink)
                Text("جبران طالع التليدي")
                    .font(F.ruqaa(22))
                    .foregroundStyle(T.gold)
            }
            .scaleEffect(shown ? 1 : 0.92)
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { shown = true }
        }
    }
}
