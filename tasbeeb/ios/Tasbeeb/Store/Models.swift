import Foundation

enum Role: String, Codable { case user, bot }

enum MsgKind: String, Codable {
    case text        // نص عادي
    case images      // صور المرفقات (المستخدم)
    case info        // معلومة من التطبيق
    case doc         // ملخص قراءة مرفق
    case question    // سؤال بأزرار رد
    case evidence    // اختيار البينات
    case tasbeeb     // التسبيب الجاهز
    case alerts      // تنبيهات القاضي
    case working     // جارٍ القراءة…
}

struct Msg: Codable, Identifiable, Hashable {
    var id = UUID()
    var role: Role
    var kind: MsgKind
    var text: String = ""
    var images: [String] = []          // أسماء ملفات في مجلد المرفقات
    var options: [String] = []         // قيم أزرار الرد
    var labels: [String] = []          // ما يظهر على الأزرار (إن اختلف عن القيمة)
    var key: String? = nil             // ما يجيب عنه السؤال
    var answered: String? = nil        // الرد المختار
    var expectsText = false            // ينتظر ردّاً مكتوباً
    var level: String = ""             // للمعلومات الملونة: red | warn
    var lines: [String] = []           // سطور إضافية (بيانات مرفق، تعارضات)
    var edited = false                 // عدّل القاضي نص التسبيب
    var title: String? = nil           // عنوان جزء الضبط (رصد البينات، التسبيب والحكم…)
    var date = Date()

    func label(at i: Int) -> String { i < labels.count ? labels[i] : options[i] }

    enum CodingKeys: String, CodingKey {
        case id, role, kind, text, images, options, labels, key, answered, expectsText, level, lines, edited, title, date
    }
}

struct CaseRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var created = Date()
    var updated = Date()
    var state: String = "{}"
    var minutes: String = ""
    var messages: [Msg] = []
    var cat: String = ""
    var typeName: String = ""
    var ready = false
    var lastLine: String = ""
    var skipped: [String] = []
    var evidenceDone = false
    var typeConfirmed = false
    var checks: [String: Bool] = [:]

    var title: String { typeName.isEmpty ? "قضية جديدة" : typeName }

    enum CodingKeys: String, CodingKey {
        case id, created, updated, state, minutes, messages, cat, typeName, ready, lastLine, skipped, evidenceDone, typeConfirmed, checks
    }
}

// MARK: فك متسامح لملف القضايا
// الفك المُركَّب تلقائياً يفشل إذا غاب أي مفتاح غير اختياري (حقل أضيف في إصدار لاحق)،
// فيضيع الملف كله؛ هنا يأخذ كل حقل غائب قيمته الافتراضية.
extension Msg {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        role = (try? c.decode(Role.self, forKey: .role)) ?? .bot
        kind = (try? c.decode(MsgKind.self, forKey: .kind)) ?? .info
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        images = (try? c.decode([String].self, forKey: .images)) ?? []
        options = (try? c.decode([String].self, forKey: .options)) ?? []
        labels = (try? c.decode([String].self, forKey: .labels)) ?? []
        key = try? c.decodeIfPresent(String.self, forKey: .key)
        answered = try? c.decodeIfPresent(String.self, forKey: .answered)
        expectsText = (try? c.decode(Bool.self, forKey: .expectsText)) ?? false
        level = (try? c.decode(String.self, forKey: .level)) ?? ""
        lines = (try? c.decode([String].self, forKey: .lines)) ?? []
        edited = (try? c.decode(Bool.self, forKey: .edited)) ?? false
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
    }
}

extension CaseRecord {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        created = (try? c.decode(Date.self, forKey: .created)) ?? Date()
        updated = (try? c.decode(Date.self, forKey: .updated)) ?? created
        state = (try? c.decode(String.self, forKey: .state)) ?? "{}"
        minutes = (try? c.decode(String.self, forKey: .minutes)) ?? ""
        messages = (try? c.decode([Msg].self, forKey: .messages)) ?? []
        cat = (try? c.decode(String.self, forKey: .cat)) ?? ""
        typeName = (try? c.decode(String.self, forKey: .typeName)) ?? ""
        ready = (try? c.decode(Bool.self, forKey: .ready)) ?? false
        lastLine = (try? c.decode(String.self, forKey: .lastLine)) ?? ""
        skipped = (try? c.decode([String].self, forKey: .skipped)) ?? []
        evidenceDone = (try? c.decode(Bool.self, forKey: .evidenceDone)) ?? false
        typeConfirmed = (try? c.decode(Bool.self, forKey: .typeConfirmed)) ?? false
        checks = (try? c.decode([String: Bool].self, forKey: .checks)) ?? [:]
    }
}
