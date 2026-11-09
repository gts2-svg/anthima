#if DEBUG
import Foundation

/// Screenshots on the build machine: `-screen home|law|article|search|ask|saved|settings`.
enum Demo {
    static var screen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func apply() {
        guard let screen else { return }
        let nav = AppNav.shared
        let lib = Library.shared
        let store = UserStore.shared
        if let a = lib.article(key: "murafaat|30") { store.lastRead = a.key }
        if store.saved.isEmpty { store.saved = ["ithbat|3", "murafaat|30", "tahkeem|2"] }
        if store.recentSearches.isEmpty { store.recentSearches = ["مدة الاستئناف", "الدليل الناقص", "التحكيم"] }
        switch screen {
        case "law": nav.library = [.law("ithbat")]
        case "category": nav.library = [.category("qadaa")]
        case "reg": nav.library = [.law("murafaat_reg")]
        case "article": nav.library = [.article("murafaat|30")]
        case "regarticle": nav.library = [.article("murafaat_reg|30.1")]
        case "search": nav.tab = 1; nav.searchDraft = "مدة الاستئناف"
        case "number": nav.tab = 1; nav.searchDraft = "المادة الثلاثون مرافعات"
        case "ask": nav.tab = 2
        case "saved": nav.tab = 3
        case "settings": nav.library = [.settings]
        default: break
        }
    }

    /// Tells the build machine the screen is ready to photograph: written once the cover is gone
    /// and the index is ready, with how long each took. The build waits for this file instead of
    /// a fixed delay, and treats a screen that never writes it as stuck.
    @MainActor
    static func markReady(launch: Date) async {
        guard screen != nil else { return }
        let lib = Library.shared
        let shown = Date().timeIntervalSince(launch)
        while !lib.indexReady { try? await Task.sleep(nanoseconds: 100_000_000) }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let report = String(format: "screen=%@ cover_gone=%.2fs laws=%.2fs index=%.2fs (%@)\n",
                            screen ?? "", shown, lib.loadSeconds, lib.indexSeconds, lib.indexSource)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? report.write(to: dir.appendingPathComponent("demo-ready.txt"), atomically: true, encoding: .utf8)
    }
}
#endif
