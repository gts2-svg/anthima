import Foundation

/// The short explanation («الشرح») and example («المثال») of one article, written from the
/// Ministry of Justice commentary. Article 720 of نظام المعاملات المدنية also carries its 41 rules.
struct Explanation: Decodable, Hashable {
    let s: String
    let m: String?
    let rules: [RuleExplanation]?

    var sharh: String { s }
    var mithal: String? {
        guard let m, !m.isEmpty else { return nil }
        return m
    }
}

/// One of the general rules («القواعد الكلية») of article 720.
struct RuleExplanation: Decodable, Hashable, Identifiable {
    let label: String
    let text: String
    let s: String
    let m: String?

    var id: String { label }
    var mithal: String? {
        guard let m, !m.isEmpty else { return nil }
        return m
    }
}

/// Read once from explain.json (built from ios/data/explain/) the first time an article is opened.
final class Explanations {
    static let shared = Explanations()

    private var table: [String: [String: Explanation]] = [:]
    private var loaded = false
    private let lock = NSLock()

    func explanation(lawID: String, n: String) -> Explanation? {
        lock.lock()
        defer { lock.unlock() }
        if !loaded {
            loaded = true
            if let url = Bundle.main.url(forResource: "explain", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let t = try? JSONDecoder().decode([String: [String: Explanation]].self, from: data) {
                table = t
            }
        }
        return table[lawID]?[n]
    }
}
