import Foundation

/// One search hit.
struct SearchHit: Identifiable {
    let article: Article
    let score: Double
    var id: String { article.id }
}

/// An in-memory index over every article: tolerant of spelling slips, prefixes
/// (و، ال، ب…) and article numbers written as digits or words.
struct SearchIndex {
    private struct Doc {
        let lawID: String
        let index: Int
        let folded: String
        let headTerms: Set<String>
    }

    private var docs: [Doc] = []
    private var postings: [String: [Int32]] = [:]
    private var vocabulary: [String] = []
    private var lawTerms: [String: Set<String>] = [:]
    private var lawsByID: [String: Law] = [:]
    /// Laws in library order (for number search across all laws).
    private var lawOrder: [String] = []
    /// In how many articles each term appears.
    private var df: [String: Int] = [:]

    /// Everyday wording → the words the laws use («رسوم» → «تكاليف قضائية»). Set after loading.
    struct Concept {
        let keys: Set<String>
        let targets: [String]
    }
    var concepts: [Concept] = []

    init() {}

    /// Reads «synonyms.json»: {"رسوم": "تكاليف قضائية", …}. A key of several words needs all of them.
    static func concepts(from data: Data) -> [Concept] {
        guard let raw = try? JSONDecoder().decode([String: String].self, from: data) else { return [] }
        return raw.compactMap { k, v in
            let keys = Set(ArabicText.terms(k))
            let targets = ArabicText.terms(v)
            return keys.isEmpty || targets.isEmpty ? nil : Concept(keys: keys, targets: targets)
        }
    }

    private mutating func finish() {
        vocabulary = Array(postings.keys)
        df.reserveCapacity(postings.count)
        for (t, list) in postings {
            var n = 0
            var last: Int32 = -1
            for d in list where d != last { n += 1; last = d }   // postings are in document order
            df[t] = n
        }
    }

    init(laws: [Law]) {
        for law in laws {
            lawsByID[law.id] = law
            lawOrder.append(law.id)
            lawTerms[law.id] = Set(ArabicText.terms(law.name))
            for a in law.articles {
                let id = Int32(docs.count)
                let body = (a.title ?? "") + " " + a.text
                let folded = ArabicText.fold(body)
                let head = Set(ArabicText.terms((a.title ?? "") + " " + (a.part ?? "") + " " + (a.chapter ?? "")))
                docs.append(Doc(lawID: law.id, index: a.index, folded: " " + folded + " ", headTerms: head))
                for t in ArabicText.termsOfFolded(folded) {
                    postings[t, default: []].append(id)
                }
            }
        }
        finish()
    }

    var isEmpty: Bool { docs.isEmpty }

    private func article(_ d: Doc) -> Article? {
        guard let law = lawsByID[d.lawID], law.articles.indices.contains(d.index) else { return nil }
        return law.articles[d.index]
    }

    // MARK: query

    /// Which laws the query names («مرافعات», «الإثبات», «نظام التنفيذ»…), best first: most shared
    /// words, then a law before its regulation (unless the query says «لائحة»), laws in force before
    /// repealed ones, then the closest name. Only the best-matching group is returned.
    func lawsNamed(in query: String) -> [String] {
        let q = Set(ArabicText.terms(query))
        guard !q.isEmpty else { return [] }
        let wantsReg = ArabicText.fold(query).contains("لايح")
        var best: [(common: Int, kind: Int, repealed: Int, extra: Int, order: Int, id: String)] = []
        for (order, id) in lawOrder.enumerated() {
            guard let terms = lawTerms[id], let law = lawsByID[id] else { continue }
            let common = q.intersection(terms).subtracting(["نظام", "لايح"]).count
            guard common > 0 else { continue }
            var kind = law.kind == .law ? 0 : (law.kind == .reg ? 1 : 2)
            if wantsReg { kind = law.kind == .reg ? 0 : (law.kind == .law ? 1 : 2) }
            best.append((common, kind, law.isRepealed ? 1 : 0, terms.subtracting(q).count, order, id))
        }
        guard let top = best.map({ $0.common }).max() else { return [] }
        let group = best.filter { $0.common == top }.sorted {
            ($0.kind, $0.repealed, $0.extra, $0.order) < ($1.kind, $1.repealed, $1.extra, $1.order)
        }
        guard let first = group.first else { return [] }
        return group.filter { $0.kind == first.kind }.map { $0.id }
    }

    /// «المادة 30 مرافعات», «م30», «المادة الثلاثون من نظام الإثبات», «1/30».
    func numberLookup(_ query: String, in scope: String?) -> [Article] {
        let folded = " " + ArabicText.fold(query)
        // «/» is folded away, so «1/30» is read from the query itself (digits made Western first).
        let raw = String(String.UnicodeScalarView(query.unicodeScalars.map { u -> Unicode.Scalar in
            switch u.value {
            case 0x0660...0x0669: return Unicode.Scalar(u.value - 0x0660 + 48)!
            case 0x06F0...0x06F9: return Unicode.Scalar(u.value - 0x06F0 + 48)!
            default: return u
            }
        }))
        let explicit = folded.range(of: #"\s(الماده|ماده|م)\s*\d"#, options: .regularExpression) != nil
            || folded.range(of: #"\s(الماده|ماده)\s"#, options: .regularExpression) != nil
        let words = ArabicText.tokens(query).filter { !ArabicText.stopwords.contains($0) }
        guard explicit || words.count <= 3 else { return [] }
        var number: String?
        if let r = raw.range(of: #"\d+\s*/\s*\d+"#, options: .regularExpression) {
            let pair = raw[r].replacingOccurrences(of: " ", with: "").split(separator: "/")
            if pair.count == 2 { number = "\(pair[1]).\(pair[0])" }
        } else if let r = folded.range(of: #"\d+"#, options: .regularExpression) {
            number = String(folded[r])
        } else if let r = folded.range(of: #"\s(الماده|ماده)\s+(.+)"#, options: .regularExpression) {
            let rest = folded[r].split(separator: " ").dropFirst().joined(separator: " ")
            // «المادة الثلاثون من نظام…»
            if let n = ArabicText.ordinal(rest) { number = String(n) }
        }
        guard let number else { return [] }
        let isPair = number.contains(".")
        var ids = scope.map { [$0] } ?? lawsNamed(in: query)
        if isPair && scope == nil {
            // «1/30 مرافعات»: numbers with a slash are regulation items of the named law.
            ids = ids.flatMap { id -> [String] in
                guard lawsByID[id]?.kind == .law else { return [id] }
                let regs = lawOrder.filter { lawsByID[$0]?.parent == id && lawsByID[$0]?.kind == .reg }
                return regs.isEmpty ? [id] : regs
            }
        }
        if ids.isEmpty {
            // No law named: «1/30» lives in regulations, a plain number in laws; in force first.
            let pool = lawOrder.compactMap { lawsByID[$0] }.filter { isPair ? $0.kind == .reg : $0.kind == .law }
            ids = (pool.filter { !$0.isRepealed } + pool.filter(\.isRepealed)).map(\.id)
        }
        var out: [Article] = []
        for id in ids {
            guard let law = lawsByID[id] else { continue }
            if let a = law.articles.first(where: { $0.n == number && !$0.isRepealed })
                ?? law.articles.first(where: { $0.n == number }) {
                out.append(a)
            }
        }
        return out
    }

    private static func editDistanceAtMost1(_ a: String, _ b: String) -> Bool {
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > 1 { return false }
        var i = 0, j = 0, edits = 0
        while i < x.count && j < y.count {
            if x[i] == y[j] { i += 1; j += 1; continue }
            edits += 1
            if edits > 1 { return false }
            if x.count > y.count { i += 1 }
            else if x.count < y.count { j += 1 }
            else {
                // a swap of two neighbours counts as one slip
                if i + 1 < x.count && x[i] == y[j + 1] && x[i + 1] == y[j] { i += 2; j += 2; continue }
                i += 1; j += 1
            }
        }
        return edits + (x.count - i) + (y.count - j) <= 1
    }

    /// Terms of the query plus close spellings found in the laws. A close spelling is used only
    /// when it looks like a correction (the typed word is unknown, or the other is far commoner),
    /// so «اقرار» doesn't also pull in «اسرار» and «اضرار».
    private func expand(_ term: String) -> [(String, Double)] {
        var out: [(String, Double)] = []
        let dfT = df[term] ?? 0
        if dfT > 0 { out.append((term, 1)) }
        let tn = term.count
        if tn >= 3 {
            for v in vocabulary where v != term {
                let vn = v.count
                if vn > tn && vn - tn <= 2 && v.hasPrefix(term) {
                    out.append((v, 0.5))
                } else if (tn >= 4 || (tn == 3 && vn == 4)) && abs(vn - tn) <= 1
                            && SearchIndex.editDistanceAtMost1(term, v) {
                    if dfT == 0 || (df[v] ?? 0) >= 8 * dfT { out.append((v, 0.8)) }
                }
            }
        }
        return out
    }

    func search(_ query: String, in scope: String? = nil, limit: Int = 60) -> [SearchHit] {
        let terms = Array(Set(ArabicText.terms(query)))
        guard !terms.isEmpty else { return [] }
        let named = scope == nil ? Set(lawsNamed(in: query)) : []
        let lawWords = named.isEmpty ? Set<String>() : named.compactMap { lawTerms[$0] }.reduce(Set<String>()) { $0.union($1) }
        let content = terms.filter { !lawWords.contains($0) }
        let useTerms = content.isEmpty ? terms : content
        let n = Double(max(docs.count, 1))

        // Groups: each query word, plus one group per concept the query mentions.
        var groups: [(members: [(String, Double)], concept: Bool)] = useTerms.map { ([($0, 1.0)], false) }
        let qset = Set(terms)
        for c in concepts where c.keys.isSubset(of: qset) {
            let extra = c.targets.filter { !useTerms.contains($0) && !lawWords.contains($0) }
            if !extra.isEmpty { groups.append((extra.map { ($0, 0.7) }, true)) }
        }
        let conceptCount = groups.filter { $0.concept }.count

        var scores: [Int32: Double] = [:]
        var matched: [Int32: Double] = [:]
        for g in groups {
            var perDoc: [Int32: Double] = [:]
            for (base, gw) in g.members {
                let baseIDF = df[base].map { log(1 + n / Double($0)) }
                for (v, w) in expand(base) {
                    guard let list = postings[v], let dv = df[v], dv > 0 else { continue }
                    var idf = log(1 + n / Double(dv))
                    if w < 1, let baseIDF { idf = min(idf, baseIDF) }   // a variant never outweighs the word typed
                    var tf: [Int32: Int] = [:]
                    for d in list { tf[d, default: 0] += 1 }
                    for (d, c) in tf {
                        perDoc[d, default: 0] += gw * w * idf * (1 + log(Double(min(c, 4))))
                    }
                }
            }
            let cap = (perDoc.values.max() ?? 0) * 1.5
            for (d, sc) in perDoc {
                scores[d, default: 0] += g.concept ? min(sc, cap) : sc
                matched[d, default: 0] += g.concept ? 0.5 : 1
            }
        }
        let denom = Double(useTerms.count) + 0.5 * Double(conceptCount)

        let phrase = " " + ArabicText.tokens(query).filter { !ArabicText.stopwords.contains($0) }.joined(separator: " ")
        var hits: [SearchHit] = []
        for (d, s) in scores {
            let doc = docs[Int(d)]
            if let scope, doc.lawID != scope { continue }
            var score = s
            let m = matched[d] ?? 0
            score *= pow(min(1, m / denom), 2) * 2 + 0.2
            if useTerms.count > 1 && phrase.count > 4 && doc.folded.contains(phrase) { score *= 2.5 }
            if !doc.headTerms.isDisjoint(with: useTerms) { score *= 1.3 }
            if named.contains(doc.lawID) { score *= 3 }
            if let law = lawsByID[doc.lawID], law.kind == .law { score *= 1.1 }
            if let law = lawsByID[doc.lawID], law.isPending { score *= 0.8 }
            guard let a = article(doc) else { continue }
            if a.isRepealed { score *= 0.35 }   // still findable, but below the texts in force
            hits.append(SearchHit(article: a, score: score))
        }
        hits.sort { $0.score > $1.score }
        return Array(hits.prefix(limit))
    }

    /// The part of the text around the first matching word, for result previews.
    static func snippet(_ text: String, query: String, length: Int = 150) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        let terms = ArabicText.terms(query)
        let words = flat.split(separator: " ")
        var start = 0
        outer: for (i, w) in words.enumerated() {
            let t = ArabicText.stem(ArabicText.fold(String(w)).replacingOccurrences(of: " ", with: ""))
            for q in terms where t.hasPrefix(q) || q.hasPrefix(t) && t.count >= 3 {
                start = max(0, i - 6)
                break outer
            }
        }
        var out = words[start...].joined(separator: " ")
        if out.count > length { out = String(out.prefix(length)) + "…" }
        return (start > 0 ? "…" : "") + out
    }
}

// MARK: - The ready-made index file
//
// The index is built once on the build machine (ios/tools/IndexTool) with this same code and
// shipped as «searchindex.dat», so the phone only reads it. The file records every law's id and
// article count; if they do not match the bundled laws it is ignored and the index is rebuilt.

extension SearchIndex {
    private static let magic: UInt32 = 0x3158_4941   // "AIX1"
    private static let version: UInt32 = 2

    func serialized(laws: [Law]) -> Data {
        var w = IndexWriter()
        w.u32(Self.magic)
        w.u32(Self.version)
        w.u32(UInt32(laws.count))
        for law in laws {
            w.str(law.id)
            w.u32(UInt32(law.articles.count))
            w.strs((lawTerms[law.id] ?? []).sorted())
        }
        let lawRef = Dictionary(uniqueKeysWithValues: laws.enumerated().map { ($1.id, UInt32($0)) })
        w.u32(UInt32(docs.count))
        for d in docs {
            w.u32(lawRef[d.lawID] ?? 0)
            w.u32(UInt32(d.index))
            w.str(d.folded)
            w.strs(d.headTerms.sorted())
        }
        w.u32(UInt32(postings.count))
        for term in postings.keys.sorted() {
            w.str(term)
            w.i32s(postings[term] ?? [])
        }
        return w.data
    }

    /// Reads a ready-made index; nil when the file is damaged or was made from other laws.
    init?(data: Data, laws: [Law]) {
        var r = IndexReader(data)
        do {
            guard try r.u32() == Self.magic, try r.u32() == Self.version,
                  try r.u32() == UInt32(laws.count) else { return nil }
            var ids: [String] = []
            for law in laws {
                let id = try r.str()
                guard id == law.id, try r.u32() == UInt32(law.articles.count) else { return nil }
                lawTerms[id] = try Set(r.strs())
                lawsByID[id] = law
                lawOrder.append(id)
                ids.append(id)
            }
            let docCount = try Int(r.u32())
            docs.reserveCapacity(docCount)
            for _ in 0..<docCount {
                let ref = try Int(r.u32())
                let index = try Int(r.u32())
                guard ids.indices.contains(ref), laws[ref].articles.indices.contains(index) else { return nil }
                let folded = try r.str()
                let head = try Set(r.strs())
                docs.append(Doc(lawID: ids[ref], index: index, folded: folded, headTerms: head))
            }
            let termCount = try Int(r.u32())
            postings.reserveCapacity(termCount)
            for _ in 0..<termCount {
                let term = try r.str()
                let list = try r.i32s()
                guard list.allSatisfy({ $0 >= 0 && Int($0) < docCount }) else { return nil }
                postings[term] = list
            }
            guard r.atEnd else { return nil }
        } catch {
            return nil
        }
        finish()
    }
}

private struct IndexWriter {
    var data = Data()

    mutating func u32(_ v: UInt32) {
        withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) }
    }

    mutating func str(_ s: String) {
        let bytes = Array(s.utf8)
        u32(UInt32(bytes.count))
        data.append(contentsOf: bytes)
    }

    mutating func strs(_ list: [String]) {
        u32(UInt32(list.count))
        for s in list { str(s) }
    }

    mutating func i32s(_ list: [Int32]) {
        u32(UInt32(list.count))
        for v in list { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    }
}

private struct IndexReader {
    struct Damaged: Error {}
    private let bytes: [UInt8]
    private var at = 0

    init(_ data: Data) { bytes = [UInt8](data) }

    var atEnd: Bool { at == bytes.count }

    private mutating func take(_ n: Int) throws -> ArraySlice<UInt8> {
        guard n >= 0, at + n <= bytes.count else { throw Damaged() }
        defer { at += n }
        return bytes[at..<(at + n)]
    }

    mutating func u32() throws -> UInt32 {
        let b = try take(4)
        let i = b.startIndex
        return UInt32(b[i]) | UInt32(b[i + 1]) << 8 | UInt32(b[i + 2]) << 16 | UInt32(b[i + 3]) << 24
    }

    mutating func str() throws -> String {
        let n = try Int(u32())
        return try String(decoding: take(n), as: UTF8.self)
    }

    mutating func strs() throws -> [String] {
        let n = try Int(u32())
        var out: [String] = []
        out.reserveCapacity(n)
        for _ in 0..<n { try out.append(str()) }
        return out
    }

    mutating func i32s() throws -> [Int32] {
        let n = try Int(u32())
        guard n >= 0, n <= (bytes.count - at) / 4 else { throw Damaged() }
        var out = [Int32](repeating: 0, count: n)
        let b = try take(n * 4)
        out.withUnsafeMutableBytes { dst in
            b.withUnsafeBytes { src in dst.copyMemory(from: src) }
        }
        return out
    }
}
