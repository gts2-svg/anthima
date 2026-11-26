import SwiftUI

@main
struct TasbeebApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .appEnvironment()
        }
    }
}
