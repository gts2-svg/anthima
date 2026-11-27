import SwiftUI

@main
struct TasbeebApp: App {
    var body: some Scene {
        WindowGroup {
            AppRoot()
        }
    }
}

/// الجذر: الجوال قائمة ثم محادثة؛ والآيباد القائمة والمحادثة جنباً إلى جنب.
struct AppRoot: View {
    @AppStorage("appearance") private var appearance = Appearance.light.rawValue
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selected: UUID?

    var body: some View {
        Group {
            if hSize == .regular {
                NavigationSplitView {
                    HomeView(selection: $selected)
                        .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
                } detail: {
                    if let id = selected {
                        CaseLoader(id: id, inSplit: true).id(id)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "text.bubble").font(.system(size: 44, weight: .light)).foregroundStyle(T.accent)
                            Text("اختر قضية من القائمة، أو ابدأ قضية جديدة").font(F.ui(16)).foregroundStyle(T.muted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(T.bg)
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack {
                    HomeView(selection: nil)
                }
            }
        }
        .appEnvironment()
        .preferredColorScheme((Appearance(rawValue: appearance) ?? .light).scheme)
    }
}
