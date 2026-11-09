import Foundation

enum LawKind: String, Codable {
    case law, reg, rules

    var label: String {
        switch self {
        case .law: return "نظام"
        case .reg: return "لائحة"
        case .rules: return "قواعد"
        }
    }
}

struct Category: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct Article: Codable, Identifiable, Hashable {
    let n: String
    let label: String
    let heading: String
    let title: String?
    let part: String?
    let chapter: String?
    let text: String
    let note: String?
    let ref: String?
    let repealed: Bool?
    /// Filled after loading.
    var lawID: String = ""
    var index: Int = 0

    var id: String { "\(lawID)|\(index)" }
    var key: String { "\(lawID)|\(n.isEmpty ? "#\(index)" : n)" }

    enum CodingKeys: String, CodingKey {
        case n, label, heading, title, part, chapter, text, note, ref, repealed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        n = (try? c.decode(String.self, forKey: .n)) ?? ""
        label = (try? c.decode(String.self, forKey: .label)) ?? n
        heading = (try? c.decode(String.self, forKey: .heading)) ?? ""
        title = try? c.decode(String.self, forKey: .title)
        part = try? c.decode(String.self, forKey: .part)
        chapter = try? c.decode(String.self, forKey: .chapter)
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        note = try? c.decode(String.self, forKey: .note)
        ref = try? c.decode(String.self, forKey: .ref)
        repealed = try? c.decode(Bool.self, forKey: .repealed)
    }

    /// «المادة الثلاثون» / «المادة 1/30» / a table caption.
    var displayHeading: String {
        if !heading.isEmpty { return heading }
        return label.isEmpty ? "نص" : "المادة \(label)"
    }

    /// Short number for badges: «30», «1/30».
    var badge: String { label.isEmpty ? "•" : label }

    var place: String {
        [part, chapter].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct Law: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let cat: String
    let kind: LawKind
    let decree: String?
    let source: String?
    let parent: String?
    var articles: [Article]

    static func == (a: Law, b: Law) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    var numberedCount: Int { articles.filter { !$0.n.isEmpty }.count }

    var countText: String {
        let n = numberedCount
        return ArabicText.count(n, one: "مادة", two: "مادتان", few: "مواد", many: "مادة")
    }

    /// Parts in reading order, for «الأبواب».
    var parts: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for a in articles {
            let p = a.part ?? ""
            if !p.isEmpty && !seen.contains(p) {
                seen.insert(p)
                out.append(p)
            }
        }
        return out
    }
}

struct LibraryFile: Codable {
    let categories: [Category]
    let laws: [Law]
}

/// All laws, loaded once from the bundled file.
final class Library: ObservableObject {
    static let shared = Library()

    @Published private(set) var isLoaded = false
    private(set) var categories: [Category] = []
    private(set) var laws: [Law] = []
    private(set) var lawByID: [String: Law] = [:]
    private(set) var index = SearchIndex()

    var articleCount: Int { laws.reduce(0) { $0 + $1.numberedCount } }

    /// True once the search index is built (a few seconds after the laws are on screen).
    @Published private(set) var indexReady = false

    func load() async {
        if isLoaded { return }
        let file: LibraryFile? = await Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: "laws", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder().decode(LibraryFile.self, from: data) else { return nil }
            var laws = file.laws
            for li in laws.indices {
                for ai in laws[li].articles.indices {
                    laws[li].articles[ai].lawID = laws[li].id
                    laws[li].articles[ai].index = ai
                }
            }
            return LibraryFile(categories: file.categories, laws: laws)
        }.value
        await MainActor.run {
            if let file {
                categories = file.categories
                laws = file.laws
                lawByID = Dictionary(uniqueKeysWithValues: file.laws.map { ($0.id, $0) })
            }
            isLoaded = true
        }
        let all = laws
        let idx = await Task.detached(priority: .utility) { SearchIndex(laws: all) }.value
        await MainActor.run {
            index = idx
            indexReady = true
        }
    }

    func law(_ id: String) -> Law? { lawByID[id] }

    func article(key: String) -> Article? {
        let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let law = lawByID[parts[0]] else { return nil }
        if parts[1].hasPrefix("#"), let i = Int(parts[1].dropFirst()), law.articles.indices.contains(i) {
            return law.articles[i]
        }
        return law.articles.first { $0.n == parts[1] }
    }

    func categoryName(_ id: String) -> String {
        categories.first { $0.id == id }?.name ?? ""
    }

    /// Regulations, rules and procedures issued under a law.
    func children(of law: Law) -> [Law] {
        laws.filter { $0.parent == law.id }
    }

    /// Regulation articles that point at this article (shown as links, never merged).
    func regulationLinks(for article: Article) -> [Article] {
        guard let law = lawByID[article.lawID], law.kind == .law, !article.n.isEmpty else { return [] }
        return children(of: law)
            .filter { $0.kind == .reg }
            .flatMap { $0.articles.filter { $0.ref == article.n } }
    }
}
