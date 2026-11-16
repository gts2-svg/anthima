import Foundation

/// An old law compared with its new version — made once (on the web version) and shipped as a file.
struct Comparison: Codable, Identifiable {
    struct Section: Codable, Identifiable {
        let key: String
        let title: String
        let text: String
        var id: String { key }
    }

    struct Row: Codable, Identifiable, Hashable {
        let new: String
        let old: [String]
        let status: String
        let note: String?
        var id: String { new + "|" + old.joined(separator: ",") }
    }

    let key: String
    let oldLaw: String
    let oldReg: String
    let newLaw: String
    let newReg: String
    let sections: [Section]
    let lawMap: [Row]
    let regMap: [Row]

    var id: String { key }

    /// The laws and regulations this report covers.
    var lawIDs: Set<String> {
        [oldLaw, oldReg == "attached" ? oldLaw + "_reg" : oldReg, newLaw, newReg].reduce(into: Set<String>()) {
            if !$1.isEmpty { $0.insert($1) }
        }
    }

    /// «جديد م٢» → «tanfeeth|2», «قديم لائحة ١/٥» → «tanfeethold_reg|5.1».
    func articleKey(_ ref: String) -> String? {
        let s = ArabicText.fold(ref.replacingOccurrences(of: "/", with: " / "))
        let isNew = s.contains("جديد")
        let isReg = s.contains("لايح")
        let nums = s.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
        guard !nums.isEmpty else { return nil }
        let law: String
        if isNew { law = isReg ? newReg : newLaw }
        else { law = isReg ? (oldReg == "attached" ? oldLaw + "_reg" : oldReg) : oldLaw }
        guard !law.isEmpty else { return nil }
        let n = s.contains("/") && nums.count >= 2 ? "\(nums[1]).\(nums[0])" : nums[0]
        return "\(law)|\(n)"
    }

    /// Plain text: «## Title» lines and «[قديم م١]» tags removed for reading on the phone.
    static func readable(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("## ") }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Comparisons {
    static let all: [Comparison] = {
        guard let url = Bundle.main.url(forResource: "comparisons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Comparison].self, from: data) else { return [] }
        return list
    }()

    static func covering(_ lawID: String) -> Comparison? {
        all.first { $0.lawIDs.contains(lawID) }
    }

    /// The other side of an article: for a new one its old counterparts, for an old one the new.
    static func counterparts(of a: Article) -> (rows: [Comparison.Row], keys: [String], cmp: Comparison)? {
        guard let c = covering(a.lawID) else { return nil }
        let me = "\(a.lawID)|\(a.n)"
        var keys: [String] = []
        var rows: [Comparison.Row] = []
        for r in c.lawMap + c.regMap {
            let newKey = c.articleKey(r.new)
            let oldKeys = r.old.compactMap { c.articleKey($0) }
            if newKey == me {
                keys += oldKeys; rows.append(r)
            } else if oldKeys.contains(me), let newKey {
                keys.append(newKey); rows.append(r)
            }
        }
        return rows.isEmpty ? nil : (rows, keys, c)
    }
}
