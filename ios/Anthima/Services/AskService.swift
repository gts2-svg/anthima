import Foundation

/// One question and its answer, kept in the history.
struct AskRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    let question: String
    let scope: String?
    let found: Bool
    let answer: String
    /// Article keys (lawID|n) the answer rests on.
    let cites: [String]
    /// Close articles shown when no text answers the question.
    let related: [String]
    let date: Date
}

enum AskError: LocalizedError {
    case noKey, network(String), badReply

    var errorDescription: String? {
        switch self {
        case .noKey: return "أضف مفتاح Anthropic من الإعدادات أولاً."
        case .network(let m): return "تعذّر الاتصال: \(m)"
        case .badReply: return "وصل رد غير مفهوم، جرّب مرة ثانية."
        }
    }
}

/// «اسأل»: finds the closest articles on the phone, then asks Claude to answer
/// from those texts only and name the article. The texts shown are always the
/// app's own copies, never text written by the model.
enum AskService {
    static let answerModel = "claude-sonnet-5-5"
    static let helperModel = "claude-haiku-5-5"

    private struct Message: Encodable { let role: String; let content: String }
    private struct Request: Encodable {
        let model: String
        let max_tokens: Int
        let system: String
        let messages: [Message]
    }
    private struct Reply: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }

    private static func call(model: String, system: String, user: String, maxTokens: Int) async throws -> String {
        guard let key = KeyStore.key else { throw AskError.noKey }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONEncoder().encode(Request(model: model, max_tokens: maxTokens, system: system,
                                                         messages: [Message(role: "user", content: user)]))
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 { throw AskError.network("المفتاح غير صحيح") }
            if http.statusCode == 429 { throw AskError.network("طلبات كثيرة، انتظر دقيقة") }
            throw AskError.network("\(http.statusCode) \(body.prefix(120))")
        }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        return reply.content.compactMap(\.text).joined()
    }

    /// A quick check of the saved key.
    static func testKey() async -> String {
        do {
            _ = try await call(model: helperModel, system: "أجب بكلمة واحدة.", user: "قل: تمام", maxTokens: 10)
            return "المفتاح يعمل ✓"
        } catch {
            return error.localizedDescription
        }
    }

    /// Turns a question in everyday words into the wording laws use, so the search finds the article.
    private static func searchWords(for question: String) async -> String {
        let system = """
        أنت تساعد في البحث داخل الأنظمة السعودية. حوّل سؤال المستخدم (وقد يكون بالعامية أو فيه أخطاء إملائية) \
        إلى كلمات بحث بالصياغة النظامية التي ترد في نصوص المواد. اكتب سطراً واحداً فيه 6 إلى 12 كلمة أو عبارة \
        قصيرة مفصولة بفواصل، بلا شرح.
        """
        return (try? await call(model: helperModel, system: system, user: question, maxTokens: 120)) ?? ""
    }

    static func ask(_ question: String, scope: String?) async throws -> AskRecord {
        let lib = Library.shared
        let extra = await searchWords(for: question)
        var pool: [Article] = []
        var seen = Set<String>()
        func add(_ list: [Article]) {
            for a in list where !seen.contains(a.key) { seen.insert(a.key); pool.append(a) }
        }
        add(lib.index.numberLookup(question, in: scope))
        add(lib.index.search(question, in: scope, limit: 10).map(\.article))
        if !extra.isEmpty { add(lib.index.search(extra, in: scope, limit: 14).map(\.article)) }
        add(lib.index.search(question + " " + extra, in: scope, limit: 8).map(\.article))
        pool = Array(pool.prefix(22))

        let numbered = pool.enumerated().map { i, a -> String in
            let lawName = lib.law(a.lawID)?.name ?? ""
            let title = a.title.map { " (\($0))" } ?? ""
            return "[\(i + 1)] \(lawName) — \(a.displayHeading)\(title)\n\(a.text)"
        }.joined(separator: "\n\n")

        let system = """
        أنت مساعد قاضٍ سعودي. أجب عن السؤال من نصوص المواد المرفقة فقط، ولا تعتمد على أي معلومة من خارجها.
        - إن وجدت في المواد ما يجيب صراحة: اكتب الجواب بإيجاز وبلغة عربية فصيحة، واذكر أرقام المواد المعتمد عليها بين معقوفين مثل [3].
        - إن لم تجد نصاً يجيب صراحة: قل ذلك بوضوح، ولا تخمّن ولا تستنتج من غير نص.
        - لا تنقل نص المادة في الجواب؛ يكفي معناه، فالنص يُعرض للقارئ تحته.
        أعد JSON فقط بهذا الشكل دون أي نص آخر:
        {"found": true أو false, "answer": "الجواب", "cites": [أرقام المواد المعتمد عليها]}
        """
        let user = "السؤال: \(question)\n\nالمواد:\n\(numbered)"
        let raw = try await call(model: answerModel, system: system, user: user, maxTokens: 900)

        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"),
              let data = String(raw[start...end]).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AskError.badReply }
        let found = obj["found"] as? Bool ?? false
        let answer = (obj["answer"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nums = (obj["cites"] as? [Any] ?? []).compactMap { ($0 as? Int) ?? Int("\($0)") }
        let cites = nums.compactMap { pool.indices.contains($0 - 1) ? pool[$0 - 1].key : nil }
        let related = pool.prefix(5).map(\.key).filter { !cites.contains($0) }
        let clean = answer.replacingOccurrences(of: #"\s*\[\d+(\s*[،,]\s*\d+)*\]"#, with: "", options: .regularExpression)
        return AskRecord(question: question, scope: scope, found: found && !cites.isEmpty,
                         answer: clean.isEmpty ? "ما وجدت نصاً صريحاً يجيب عن سؤالك في مكتبتك." : clean,
                         cites: cites, related: Array(related), date: Date())
    }
}
