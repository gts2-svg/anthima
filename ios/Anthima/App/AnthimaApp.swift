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

    private var tabs: some View {
        TabView(selection: $nav.tab) {
            NavigationStack(path: $nav.library) {
                LibraryView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("المكتبة", systemImage: "books.vertical") }
            .tag(0)

            NavigationStack(path: $nav.search) {
                SearchView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("بحث", systemImage: "magnifyingglass") }
            .tag(1)

            NavigationStack(path: $nav.ask) {
                AskView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("اسأل", systemImage: "bubble.left.and.text.bubble.right") }
            .tag(2)

            NavigationStack(path: $nav.saved) {
                SavedView().navigationDestination(for: Nav.self, destination: destination)
            }
            .tabItem { Label("المحفوظات", systemImage: "bookmark") }
            .tag(3)
        }
    }

    @ViewBuilder
    private func destination(_ n: Nav) -> some View {
        switch n {
        case .law(let id): LawView(lawID: id)
        case .article(let key): ArticleView(startKey: key)
        case .settings: SettingsView()
        }
    }
}

/// The opening cover: title and name, as on the home page.
struct SplashView: View {
    var body: some View {
        ZStack {
            T.ink.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(T.gold)
                    .padding(.bottom, 8)
                Text("مكتبة الأنظمة الخاصة")
                    .font(F.title(32))
                    .foregroundStyle(.white)
                Text("جبران طالع التليدي")
                    .font(F.ruqaa(24))
                    .foregroundStyle(T.gold)
            }
        }
    }
}
