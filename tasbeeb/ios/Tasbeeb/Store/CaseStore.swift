import SwiftUI

/// يحفظ القضايا على الجهاز فقط (ملف داخل التطبيق)، مع صور المرفقات المصغّرة.
final class CaseStore: ObservableObject {
    static let shared = CaseStore()
    @Published private(set) var cases: [CaseRecord] = []

    private let fm = FileManager.default
    private var dir: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var file: URL { dir.appendingPathComponent("cases.json") }
    var attDir: URL {
        let u = dir.appendingPathComponent("att", isDirectory: true)
        if !fm.fileExists(atPath: u.path) { try? fm.createDirectory(at: u, withIntermediateDirectories: true) }
        return u
    }

    private init() { load() }

    private func load() {
        guard let d = try? Data(contentsOf: file) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        cases = (try? dec.decode([CaseRecord].self, from: d)) ?? []
    }

    private func persist() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(cases) {
            try? d.write(to: file, options: [.atomic, .completeFileProtection])
        }
    }

    func newCase() -> CaseRecord {
        let c = CaseRecord()
        cases.insert(c, at: 0)
        persist()
        return c
    }

    func record(_ id: UUID) -> CaseRecord? { cases.first { $0.id == id } }

    func save(_ c: CaseRecord) {
        var c = c
        c.updated = Date()
        if let i = cases.firstIndex(where: { $0.id == c.id }) { cases[i] = c } else { cases.insert(c, at: 0) }
        cases.sort { $0.updated > $1.updated }
        persist()
    }

    func delete(_ id: UUID) {
        if let c = record(id) {
            for m in c.messages { for f in m.images { try? fm.removeItem(at: attDir.appendingPathComponent(f)) } }
        }
        cases.removeAll { $0.id == id }
        persist()
    }

    func deleteAll() {
        for c in cases { delete(c.id) }
        try? fm.removeItem(at: attDir)
    }

    func saveThumb(_ img: UIImage) -> String {
        let name = UUID().uuidString + ".jpg"
        let maxSide: CGFloat = 900
        let s = img.size
        let k = min(1, maxSide / max(s.width, s.height))
        let size = CGSize(width: s.width * k, height: s.height * k)
        let small = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        if let d = small.jpegData(compressionQuality: 0.7) {
            try? d.write(to: attDir.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        }
        return name
    }

    func image(_ name: String) -> UIImage? { UIImage(contentsOfFile: attDir.appendingPathComponent(name).path) }
}

/// صياغات القاضي المحفوظة لكل نوع دعوى (الأرقام والأوصاف فيها خانات تُعبّأ تلقائياً).
enum SavedWording {
    private static let key = "saved_wordings_v1"
    static func all() -> [String: String] { UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:] }
    static func get(_ type: String) -> String? { all()[type] }
    static func set(_ type: String, _ text: String?) {
        var a = all()
        a[type] = text
        UserDefaults.standard.set(a, forKey: key)
    }
}
