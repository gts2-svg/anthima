import Foundation

/// Arabic text helpers: folding for search, light stemming, ordinals and counts.
enum ArabicText {
    /// Folds spelling variants so «إجراءات» = «اجراءات» and «المحكمة» = «المحكمه».
    /// Works on Unicode scalars, which is many times faster than Characters for 5000 articles.
    static func fold(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        out.reserveCapacity(s.unicodeScalars.count)
        let space = Unicode.Scalar(UInt32(32))!
        for u in s.unicodeScalars {
            let v = u.value
            switch v {
            case 0x064B...0x0655, 0x0670, 0x0640:      // tashkeel and tatweel
                continue
            case 0x0623, 0x0625, 0x0622, 0x0671:       // أ إ آ ٱ → ا
                out.append(Unicode.Scalar(UInt32(0x0627))!)
            case 0x0629:                               // ة → ه
                out.append(Unicode.Scalar(UInt32(0x0647))!)
            case 0x0649:                               // ى → ي
                out.append(Unicode.Scalar(UInt32(0x064A))!)
            case 0x0624:                               // ؤ → و
                out.append(Unicode.Scalar(UInt32(0x0648))!)
            case 0x0626:                               // ئ → ي
                out.append(Unicode.Scalar(UInt32(0x064A))!)
            case 0x0660...0x0669:                      // Arabic-Indic digits
                out.append(Unicode.Scalar(v - 0x0660 + 48)!)
            case 0x06F0...0x06F9:
                out.append(Unicode.Scalar(v - 0x06F0 + 48)!)
            case 0x0621...0x063A, 0x0641...0x064A, 0x0671...0x06D3:
                out.append(u)
            case 48...57, 65...90, 97...122:
                out.append(u)
            default:
                out.append(space)
            }
        }
        return String(out)
    }

    static func tokens(_ s: String) -> [String] {
        fold(s).split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    static let stopwords: Set<String> = [
        "من", "في", "علي", "الي", "عن", "ان", "او", "ما", "لا", "هل", "كيف", "متي", "ماذا", "هو", "هي",
        "التي", "الذي", "الذين", "هذا", "هذه", "ذلك", "تلك", "مع", "عند", "كل", "بين", "ثم", "قد", "لم",
        "لن", "اذا", "اي", "ايش", "وش", "ليش", "يعني", "و", "ف", "ب", "ل", "ك", "به", "بها", "له", "لها",
        "فيه", "فيها", "منه", "منها", "عليه", "عليها", "كان", "يكون", "تكون", "ذا", "اللي", "وين", "شو",
        "المادة", "الماده", "ماده", "نظام", "النظام", "لائحه", "اللائحه"
    ]

    private static let prefixes = ["وبال", "وال", "بال", "كال", "فال", "لل", "ال", "و", "ف", "ب", "ل", "ك"]
    private static let suffixes = ["هما", "كما", "تين", "ات", "ون", "ين", "ان", "ها", "هم", "يه", "ه", "ي"]

    /// A light stem: «والمحاكم» → «محاكم», «الاختصاصات» → «اختصاص».
    static func stem(_ word: String) -> String {
        var w = word
        let n = w.unicodeScalars.count
        for p in prefixes where n - p.unicodeScalars.count >= 3 && w.hasPrefix(p) {
            w = String(w.unicodeScalars.dropFirst(p.unicodeScalars.count))
            break
        }
        let m = w.unicodeScalars.count
        for s in suffixes where m - s.unicodeScalars.count >= 3 && w.hasSuffix(s) {
            w = String(w.unicodeScalars.dropLast(s.unicodeScalars.count))
            break
        }
        return w
    }

    static func terms(_ s: String) -> [String] {
        termsOfFolded(fold(s))
    }

    /// Same as `terms` for text that is already folded.
    static func termsOfFolded(_ folded: String) -> [String] {
        var out: [String] = []
        for sub in folded.split(separator: " ", omittingEmptySubsequences: true) {
            let w = String(sub)
            if stopwords.contains(w) { continue }
            let st = stem(w)
            if st.unicodeScalars.count >= 2 { out.append(st) }
        }
        return out
    }

    // MARK: ordinals («الثلاثون» → 30)

    private static let units: [String: Int] = [
        "الاولي": 1, "الاول": 1, "الحاديه": 1, "الحادي": 1, "الثانيه": 2, "الثاني": 2, "الثالثه": 3, "الثالث": 3,
        "الرابعه": 4, "الرابع": 4, "الخامسه": 5, "الخامس": 5, "السادسه": 6, "السادس": 6, "السابعه": 7, "السابع": 7,
        "الثامنه": 8, "الثامن": 8, "التاسعه": 9, "التاسع": 9, "العاشره": 10, "العاشر": 10
    ]
    private static let tens: [String: Int] = [
        "العشرون": 20, "العشرين": 20, "الثلاثون": 30, "الثلاثين": 30, "الاربعون": 40, "الاربعين": 40,
        "الخمسون": 50, "الخمسين": 50, "الستون": 60, "الستين": 60, "السبعون": 70, "السبعين": 70,
        "الثمانون": 80, "الثمانين": 80, "التسعون": 90, "التسعين": 90
    ]
    private static let hundreds: [String: Int] = ["الماييه": 100, "المييه": 100, "المايه": 100, "الميه": 100, "المايتين": 200, "الميتين": 200, "المايتان": 200]

    /// Reads «الحادية والثلاثون بعد المائة» (already folded) as 131; nil when it is not an ordinal.
    static func ordinal(_ folded: String) -> Int? {
        let words = folded.split(separator: " ").map(String.init)
        var total = 0
        var seen = false
        var i = 0
        while i < words.count {
            var w = words[i]
            if w == "بعد", i + 1 < words.count, let h = hundreds[words[i + 1]] {
                total += h
                seen = true
                i += 2
                continue
            }
            if let h = hundreds[w] { total += h; seen = true; i += 1; continue }
            if w.hasPrefix("و"), tens[String(w.dropFirst())] != nil { w = String(w.dropFirst()) }
            if let u = units[w] { total += u; seen = true }
            else if let t = tens[w] { total += t; seen = true }
            else if w == "عشره" || w == "عشر" { total += 10; seen = true }
            else if seen { break }
            i += 1
        }
        return seen ? total : nil
    }

    // MARK: counts

    /// «مادة واحدة / مادتان / 3 مواد / 15 مادة».
    static func count(_ n: Int, one: String, two: String, few: String, many: String) -> String {
        switch n {
        case 1: return "\(one) واحدة"
        case 2: return two
        case 3...10: return "\(n) \(few)"
        default: return "\(n) \(many)"
        }
    }

    static func ordinalWord(_ n: Int) -> String? {
        let names = ["", "الأولى", "الثانية", "الثالثة", "الرابعة", "الخامسة", "السادسة", "السابعة", "الثامنة", "التاسعة", "العاشرة"]
        return n >= 1 && n <= 10 ? names[n] : nil
    }
}
