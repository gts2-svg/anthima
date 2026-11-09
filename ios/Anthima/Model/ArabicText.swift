import Foundation

/// Arabic text helpers: folding for search, light stemming, ordinals and counts.
enum ArabicText {
    private static let diacritics: Set<Character> = [
        "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}", "\u{0650}", "\u{0651}", "\u{0652}",
        "\u{0653}", "\u{0654}", "\u{0655}", "\u{0670}", "\u{0640}"
    ]

    /// Folds spelling variants so «إجراءات» = «اجراءات» and «المحكمة» = «المحكمه».
    static func fold(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            if diacritics.contains(ch) { continue }
            switch ch {
            case "أ", "إ", "آ", "ٱ": out.append("ا")
            case "ة": out.append("ه")
            case "ى": out.append("ي")
            case "ؤ": out.append("و")
            case "ئ": out.append("ي")
            case "٠": out.append("0")
            case "١": out.append("1")
            case "٢": out.append("2")
            case "٣": out.append("3")
            case "٤": out.append("4")
            case "٥": out.append("5")
            case "٦": out.append("6")
            case "٧": out.append("7")
            case "٨": out.append("8")
            case "٩": out.append("9")
            default:
                if ch.isLetter || ch.isNumber { out.append(ch) } else { out.append(" ") }
            }
        }
        return out
    }

    static func tokens(_ s: String) -> [String] {
        fold(s).split(separator: " ").map(String.init).filter { !$0.isEmpty }
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
        for p in prefixes where w.hasPrefix(p) && w.count - p.count >= 3 {
            w = String(w.dropFirst(p.count))
            break
        }
        for s in suffixes where w.hasSuffix(s) && w.count - s.count >= 3 {
            w = String(w.dropLast(s.count))
            break
        }
        return w
    }

    static func terms(_ s: String) -> [String] {
        tokens(s).filter { !stopwords.contains($0) }.map(stem).filter { $0.count >= 2 }
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
