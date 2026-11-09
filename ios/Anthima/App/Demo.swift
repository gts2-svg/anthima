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

    /// When the system started this process — to tell the system's own launch time apart from the app's.
    static var processStart: Date {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return Date() }
        let t = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000)
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
        let report = String(format: "screen=%@ process_to_first_screen=%.1fs cover_gone=%.2fs laws=%.2fs index=%.2fs (%@)\n",
                            screen ?? "", launch.timeIntervalSince(processStart), shown,
                            lib.loadSeconds, lib.indexSeconds, lib.indexSource)
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? report.write(to: dir.appendingPathComponent("demo-ready.txt"), atomically: true, encoding: .utf8)
    }
}
#endif
