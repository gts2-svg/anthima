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
}
