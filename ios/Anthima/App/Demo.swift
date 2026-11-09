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
        switch screen {
        case "law": nav.library = [.law("ithbat")]
        case "reg": nav.library = [.law("murafaat_reg")]
        case "article": nav.library = [.article("murafaat|30")]
        case "regarticle": nav.library = [.article("murafaat_reg|30.1")]
        case "search": nav.tab = 1; nav.searchDraft = "مدة الاستيناف"
        case "number": nav.tab = 1; nav.searchDraft = "الماده الثلاثون مرافعات"
        case "ask": nav.tab = 2
        case "saved": nav.tab = 3
        case "settings": nav.library = [.settings]
        default: break
        }
    }
}
#endif
