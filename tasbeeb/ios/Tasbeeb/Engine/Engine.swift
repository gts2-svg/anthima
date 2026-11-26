import Foundation
import JavaScriptCore

// MARK: نماذج ما يعيده المحرك

struct EngineField: Decodable, Hashable {
    let k: String
    let label: String
    let kind: String          // choice | text
    let options: [String]
    let labels: [String]
    let value: String
    let status: String        // ok | unc | mis | opt | user
    let req: Bool
    let ph: String

    /// العنوان الظاهر للقيمة الحالية (لموقف المدعى عليه مثلاً).
    var shownValue: String {
        if let i = options.firstIndex(of: value), i < labels.count { return labels[i] }
        return value
    }
    var needsAnswer: Bool { status == "unc" || (status == "mis" && req) }
}

struct EngineChip: Decodable, Hashable {
    let id: String
    let label: String
    let on: Bool
}

struct EngineAlert: Decodable, Hashable {
    let lvl: String
    let title: String
    let body: String
    let checks: [String]
}

struct DocItem: Decodable, Hashable {
    let label: String
    let v: String
}

struct EngineDoc: Decodable, Hashable {
    let type: String
    let label: String
    let items: [DocItem]
    let weak: Bool
    let name: String
}

struct EngineView: Decodable {
    let cat: String
    let catName: String
    let type: String
    let typeName: String
    let conf: String
    let generic: Bool
    let fields: [EngineField]
    let chips: [EngineChip]
    let alerts: [EngineAlert]
    let text: String
    let parts: [EnginePart]?
    let docs: [EngineDoc]

    static let empty = EngineView(cat: "", catName: "", type: "", typeName: "", conf: "", generic: false,
                                  fields: [], chips: [], alerts: [], text: "", parts: nil, docs: [])
    var conflicts: [EngineAlert] { alerts.filter { $0.lvl == "red" } }
}

struct EnginePart: Decodable, Hashable {
    let title: String
    let text: String
}

struct Catalog: Decodable {
    struct Cat: Decodable, Hashable { let key: String; let name: String }
    struct Kind: Decodable, Hashable { let key: String; let cat: String; let name: String }
    let cats: [Cat]
    let types: [Kind]
}

// MARK: المحرك

/// يشغّل محرك التسبيب (engine.js) داخل JavaScriptCore على الجهاز. لا شيء يخرج من الجهاز.
/// الحالة نص JSON يحفظه التطبيق مع القضية، وكل عملية تأخذ الحالة وتعيد حالة جديدة.
final class Engine {
    static let shared = Engine()
    private let ctx: JSContext
    private(set) var lastError: String?

    private init() {
        ctx = JSContext()!
        ctx.exceptionHandler = { _, exc in
            Engine.shared_lastError = exc?.toString()
        }
        if let url = Bundle.main.url(forResource: "engine", withExtension: "js"),
           let src = try? String(contentsOf: url, encoding: .utf8) {
            ctx.evaluateScript(src)
        }
    }
    fileprivate static var shared_lastError: String?

    private func call(_ fn: String, _ args: [Any]) -> String {
        guard let tb = ctx.objectForKeyedSubscript("TB"), !tb.isUndefined else { return "" }
        let v = tb.invokeMethod(fn, withArguments: args)
        if let e = Engine.shared_lastError { lastError = e; Engine.shared_lastError = nil }
        return v?.toString() ?? ""
    }

    func analyze(_ text: String, state: String) -> String { call("analyze", [text, state]) }
    func setType(_ state: String, _ type: String) -> String { call("setType", [state, type]) }
    func setField(_ state: String, _ k: String, _ v: String) -> String { call("setField", [state, k, v]) }
    func toggleEv(_ state: String, _ id: String) -> String { call("toggleEv", [state, id]) }
    func addDoc(_ state: String, text: String, ocr: Bool, conf: Double, name: String) -> String {
        call("addDoc", [state, text, ocr, conf, name])
    }
    func removeDoc(_ state: String, index: Int) -> String { call("removeDoc", [state, index]) }
    func tokenize(_ state: String, _ text: String) -> String { call("tokenize", [state, text]) }
    func fill(_ state: String, _ text: String) -> String { call("fill", [state, text]) }

    func view(_ state: String) -> EngineView {
        let json = call("view", [state])
        guard let data = json.data(using: .utf8),
              let v = try? JSONDecoder().decode(EngineView.self, from: data) else { return .empty }
        return v
    }

    lazy var catalog: Catalog = {
        let json = self.call("catalog", [])
        if let d = json.data(using: .utf8), let c = try? JSONDecoder().decode(Catalog.self, from: d) { return c }
        return Catalog(cats: [], types: [])
    }()
}
