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

    init() {}

    init(laws: [Law]) {
        for law in laws {
            lawsByID[law.id] = law
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
        vocabulary = Array(postings.keys)
    }

    var isEmpty: Bool { docs.isEmpty }

    private func article(_ d: Doc) -> Article? {
        guard let law = lawsByID[d.lawID], law.articles.indices.contains(d.index) else { return nil }
        return law.articles[d.index]
    }

    // MARK: query

    /// Which laws the query names («مرافعات», «الإثبات»…), if any.
    func lawsNamed(in query: String) -> [String] {
        let q = Set(ArabicText.terms(query))
        guard !q.isEmpty else { return [] }
        var best: [(String, Int)] = []
        for (id, terms) in lawTerms {
            let common = q.intersection(terms).subtracting(["نظام", "لايح", "تنفيذ"]).count
            if common > 0 { best.append((id, common)) }
        }
        let top = best.map(\.1).max() ?? 0
        return best.filter { $0.1 == top }.map(\.0)
    }

    /// «المادة 30 مرافعات», «م30», «المادة الثلاثون من نظام الإثبات», «1/30».
    func numberLookup(_ query: String, in scope: String?) -> [Article] {
        let folded = " " + ArabicText.fold(query)
        let explicit = folded.range(of: #"\s(الماده|ماده|م)\s*\d"#, options: .regularExpression) != nil
            || folded.range(of: #"\s(الماده|ماده)\s"#, options: .regularExpression) != nil
        let words = ArabicText.tokens(query).filter { !ArabicText.stopwords.contains($0) }
        guard explicit || words.count <= 3 else { return [] }
        var number: String?
        if let r = folded.range(of: #"\d+\s*/\s*\d+"#, options: .regularExpression) {
            let pair = folded[r].replacingOccurrences(of: " ", with: "").split(separator: "/")
            if pair.count == 2 { number = "\(pair[1]).\(pair[0])" }
        } else if let r = folded.range(of: #"\d+"#, options: .regularExpression) {
            number = String(folded[r])
        } else if let r = folded.range(of: #"\s(الماده|ماده)\s+(.+)"#, options: .regularExpression) {
            let rest = folded[r].split(separator: " ").dropFirst().joined(separator: " ")
            // «المادة الثلاثون من نظام…»
            if let n = ArabicText.ordinal(rest) { number = String(n) }
        }
        guard let number else { return [] }
        var ids = scope.map { [$0] } ?? lawsNamed(in: query)
        if ids.isEmpty { ids = lawsByID.values.filter { $0.kind == .law }.map(\.id) }
        var out: [Article] = []
        for id in ids {
            if let law = lawsByID[id], let a = law.articles.first(where: { $0.n == number }) { out.append(a) }
        }
        return out.sorted { $0.lawID < $1.lawID }
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

    /// Terms of the query plus close spellings found in the laws.
    private func expand(_ term: String) -> [(String, Double)] {
        var out: [(String, Double)] = []
        if postings[term] != nil { out.append((term, 1)) }
        if term.count >= 3 {
            for v in vocabulary where v != term {
                if v.count > term.count && v.hasPrefix(term) && v.count - term.count <= 3 {
                    out.append((v, 0.6))
                } else if term.count >= 4 && SearchIndex.editDistanceAtMost1(term, v) {
                    out.append((v, 0.7))
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

        var scores: [Int32: Double] = [:]
        var matched: [Int32: Int] = [:]
        for t in useTerms {
            var seenForTerm = Set<Int32>()
            for (v, w) in expand(t) {
                guard let list = postings[v] else { continue }
                let idf = log(1 + n / Double(Set(list).count))
                var tf: [Int32: Int] = [:]
                for d in list { tf[d, default: 0] += 1 }
                for (d, c) in tf {
                    scores[d, default: 0] += w * idf * (1 + log(Double(min(c, 4))))
                    if !seenForTerm.contains(d) {
                        seenForTerm.insert(d)
                        matched[d, default: 0] += 1
                    }
                }
            }
        }

        let phrase = " " + ArabicText.tokens(query).filter { !ArabicText.stopwords.contains($0) }.joined(separator: " ")
        var hits: [SearchHit] = []
        for (d, s) in scores {
            let doc = docs[Int(d)]
            if let scope, doc.lawID != scope { continue }
            var score = s
            let m = Double(matched[d] ?? 0)
            score *= pow(m / Double(useTerms.count), 2) * 2 + 0.2
            if useTerms.count > 1 && phrase.count > 4 && doc.folded.contains(phrase) { score *= 2.5 }
            if !doc.headTerms.isDisjoint(with: useTerms) { score *= 1.3 }
            if named.contains(doc.lawID) { score *= 3 }
            if let law = lawsByID[doc.lawID], law.kind == .law { score *= 1.1 }
            guard let a = article(doc) else { continue }
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
    private static let version: UInt32 = 1

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
        vocabulary = Array(postings.keys)
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
