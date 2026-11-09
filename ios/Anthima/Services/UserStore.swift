import Foundation
import Security
import UIKit

/// Saved articles, the last article read, reading size and «اسأل» history — all on the phone.
final class UserStore: ObservableObject {
    static let shared = UserStore()
    private let d = UserDefaults.standard

    @Published var saved: [String] { didSet { d.set(saved, forKey: "saved") } }
    @Published var lastRead: String? { didSet { d.set(lastRead, forKey: "lastRead") } }
    @Published var textSize: Double { didSet { d.set(textSize, forKey: "textSize") } }
    @Published var history: [AskRecord] { didSet { saveHistory() } }
    @Published var recentSearches: [String] { didSet { d.set(recentSearches, forKey: "recentSearches") } }

    private init() {
        saved = d.stringArray(forKey: "saved") ?? []
        lastRead = d.string(forKey: "lastRead")
        textSize = d.object(forKey: "textSize") as? Double ?? 19
        recentSearches = d.stringArray(forKey: "recentSearches") ?? []
        if let data = d.data(forKey: "askHistory"), let h = try? JSONDecoder().decode([AskRecord].self, from: data) {
            history = h
        } else {
            history = []
        }
    }

    func isSaved(_ a: Article) -> Bool { saved.contains(a.key) }

    func toggleSave(_ a: Article) {
        if let i = saved.firstIndex(of: a.key) { saved.remove(at: i) } else { saved.insert(a.key, at: 0) }
    }

    func rememberSearch(_ q: String) {
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 2 else { return }
        recentSearches.removeAll { $0 == t }
        recentSearches.insert(t, at: 0)
        if recentSearches.count > 8 { recentSearches = Array(recentSearches.prefix(8)) }
    }

    func remember(_ record: AskRecord) {
        history.removeAll { $0.question == record.question }
        history.insert(record, at: 0)
        if history.count > 30 { history = Array(history.prefix(30)) }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) { d.set(data, forKey: "askHistory") }
    }
}

/// The Anthropic API key, kept in the iPhone Keychain.
enum KeyStore {
    private static let service = "com.gts2svg.anthima.apikey"

    static var key: String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (s?.isEmpty ?? true) ? nil : s
    }

    static func set(_ value: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

enum Clipboard {
    static func copy(_ s: String) {
        UIPasteboard.general.string = s
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// «نصت المادة (الثلاثون) من نظام المرافعات الشرعية على أن: «…»».
    static func forReasoning(_ a: Article, law: Law?) -> String {
        let lawName = law?.name ?? ""
        let text = a.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var which = a.heading.replacingOccurrences(of: "المادة ", with: "")
        if which.isEmpty { which = a.label }
        return "وحيث نصت المادة (\(which)) من \(lawName) على أن: «\(text)»"
    }

    static func plain(_ a: Article, law: Law?) -> String {
        "\(law?.name ?? "") — \(a.displayHeading)\n\(a.text)"
    }
}
