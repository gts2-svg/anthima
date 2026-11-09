import Foundation
import Combine

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
        // decodeIfPresent: a missing key costs nothing, unlike `try? decode`, which builds
        // and throws an error for each of the thousands of absent optional fields.
        n = Article.str(c, .n) ?? ""
        label = Article.str(c, .label) ?? n
        heading = Article.str(c, .heading) ?? ""
        title = Article.str(c, .title)
        part = Article.str(c, .part)
        chapter = Article.str(c, .chapter)
        text = Article.str(c, .text) ?? ""
        note = Article.str(c, .note)
        ref = Article.str(c, .ref)
        repealed = (try? c.decodeIfPresent(Bool.self, forKey: .repealed)) ?? nil
    }

    private static func str(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> String? {
        (try? c.decodeIfPresent(String.self, forKey: k)) ?? nil
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

    /// Decodes the bundled laws file and fills each article's law and position.
    /// Shared by the app and by the build tool that makes the search index.
    static func prepared(from data: Data) -> LibraryFile? {
        guard let file = try? JSONDecoder().decode(LibraryFile.self, from: data) else { return nil }
        var laws = file.laws
        for li in laws.indices {
            for ai in laws[li].articles.indices {
                laws[li].articles[ai].lawID = laws[li].id
                laws[li].articles[ai].index = ai
            }
        }
        return LibraryFile(categories: file.categories, laws: laws)
    }
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

    /// True once the search index is ready (normally a moment after the laws are on screen).
    @Published private(set) var indexReady = false

    /// For the build machine's report: how long loading took and where the index came from.
    private(set) var loadSeconds: Double = 0
    private(set) var indexSeconds: Double = 0
    private(set) var indexSource = ""

    func load() async {
        if isLoaded { return }
        let t0 = Date()
        let file: LibraryFile? = await Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: "laws", withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return LibraryFile.prepared(from: data)
        }.value
        await MainActor.run {
            if let file {
                categories = file.categories
                laws = file.laws
                lawByID = Dictionary(uniqueKeysWithValues: file.laws.map { ($0.id, $0) })
            }
            loadSeconds = Date().timeIntervalSince(t0)
            isLoaded = true
        }
        // The index is made once on the build machine and shipped with the app; reading it takes
        // a fraction of a second. Only if it is missing or does not match the laws is it rebuilt here.
        let all = laws
        let t1 = Date()
        let (idx, source) = await Task.detached(priority: .userInitiated) { () -> (SearchIndex, String) in
            if let url = Bundle.main.url(forResource: "searchindex", withExtension: "dat"),
               let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               let ready = SearchIndex(data: data, laws: all) {
                return (ready, "bundled")
            }
            return (SearchIndex(laws: all), "built-on-device")
        }.value
        await MainActor.run {
            index = idx
            indexSeconds = Date().timeIntervalSince(t1)
            indexSource = source
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
