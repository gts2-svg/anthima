import Foundation

/// One question and its answer, kept in the history.
struct AskRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    let question: String
    let scope: String?
    let found: Bool
    /// The direct answer, drawn from the texts.
    let answer: String
    /// Applying the texts to the question — the model's reasoning, shown apart from what the texts say.
    var application: String? = nil
    /// Article keys (lawID|n) the answer rests on.
    let cites: [String]
    /// Close articles shown when no text answers the question.
    let related: [String]
    let date: Date
    var model: String? = nil
}

enum AskError: LocalizedError {
    case noKey, offline, network(String), badReply

    var errorDescription: String? {
        switch self {
        case .noKey: return "أضف مفتاح Anthropic من الإعدادات أولاً."
        case .offline: return "انقطع الاتصال بالإنترنت. سؤالك رجع لخانة الكتابة، جرّب مرة ثانية."
        case .network(let m): return "تعذّر الاتصال: \(m)"
        case .badReply: return "وصل رد غير مفهوم، جرّب مرة ثانية."
        }
    }
}

/// The answer model, chosen in Settings.
enum AskModel: String, CaseIterable, Identifiable {
    case sonnet = "claude-sonnet-5-5"
    case opus = "claude-opus-5-5"

    var id: String { rawValue }
    var name: String { self == .sonnet ? "Sonnet" : "Opus" }
    var note: String {
        self == .sonnet ? "سريع ورخيص، مناسب لأغلب الأسئلة"
                        : "أذكى وأدق في التكييف، أبطأ قليلاً وتكلفته تقارب الضعف"
    }

    static var current: AskModel {
        get { AskModel(rawValue: UserDefaults.standard.string(forKey: "askModel") ?? "") ?? .sonnet }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "askModel") }
    }
}

/// «اسأل»: Claude first works out what the question is legally about (التكييف), searches the
/// library on the phone as many times as it needs through tools, then answers — keeping what
/// the texts say apart from how they apply. The texts shown are always the app's own copies.
enum AskService {
    static let helperModel = "claude-haiku-5-5"

    // MARK: - HTTP

    private static func post(_ body: [String: Any]) async throws -> [String: Any] {
        guard let key = KeyStore.key else { throw AskError.noKey }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost,
                 .cannotFindHost, .dataNotAllowed, .internationalRoamingOff:
                throw AskError.offline
            default:
                throw AskError.network(e.localizedDescription)
            }
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let text = String(data: data, encoding: .utf8) ?? ""
            switch http.statusCode {
            case 401: throw AskError.network("المفتاح غير صحيح")
            case 429: throw AskError.network("طلبات كثيرة، انتظر دقيقة")
            case 529, 503: throw AskError.network("خوادم Anthropic مشغولة الحين، جرّب بعد شوي")
            default: throw AskError.network("\(http.statusCode) \(text.prefix(120))")
            }
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw AskError.badReply }
        return obj
    }

    /// A quick check of the saved key.
    static func testKey() async -> String {
        do {
            _ = try await post(["model": helperModel, "max_tokens": 10, "system": "أجب بكلمة واحدة.",
                                "messages": [["role": "user", "content": "قل: تمام"]]])
            return "المفتاح يعمل ✓"
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Tools the model calls (run on the phone)

    private static let tools: [[String: Any]] = [
        [
            "name": "search_laws",
            "description": "يبحث في نصوص الأنظمة واللوائح المحفوظة في جوال القاضي، ويعيد أقرب المواد مع نصوصها. ابحث بالمصطلح النظامي الذي يرد في النصوص (مثل: محرر عادي، حجية الورقة، الضرر، التعويض، الخبرة) لا بالعامية. يمكنك حصر البحث في نظام واحد بمعرّفه.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "كلمات البحث، عبارة قصيرة بالصياغة النظامية"],
                    "law_id": ["type": "string", "description": "اختياري: معرّف النظام أو اللائحة من القائمة"],
                ],
                "required": ["query"],
            ],
        ],
        [
            "name": "open_article",
            "description": "يفتح مادة معيّنة برقمها من نظام أو لائحة، مع المادتين قبلها وبعدها. استعمله حين تعرف المادة المطلوبة أو تحتاج سياقها.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "law_id": ["type": "string"],
                    "number": ["type": "string", "description": "رقم المادة بالأرقام، مثل 30 أو 1/30"],
                ],
                "required": ["law_id", "number"],
            ],
        ],
        [
            "name": "final_answer",
            "description": "يسلّم الجواب النهائي. استدعه مرة واحدة في النهاية.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "found": ["type": "boolean", "description": "هل وُجد في المواد نص يحكم المسألة (صراحة أو بتطبيق مباشر)"],
                    "answer": ["type": "string", "description": "الجواب المباشر عن السؤال، وما تقرره النصوص، بإيجاز وبعربية فصيحة"],
                    "application": ["type": "string", "description": "تكييف المسألة وتطبيق النصوص على السؤال، مع بيان ما هو استنتاج لا نص. اتركه فارغاً إن كان النص صريحاً لا يحتاج تطبيقاً"],
                    "cites": ["type": "array", "items": ["type": "string"], "description": "مفاتيح المواد المعتمد عليها كما وردت في نتائج البحث، مثل ithbat|30"],
                ],
                "required": ["found", "answer", "cites"],
            ],
        ],
    ]

    /// Articles the model has seen, in the order it saw them.
    private final class Pool {
        private(set) var order: [String] = []
        private var keys = Set<String>()
        func add(_ list: [Article]) { for a in list where !keys.contains(a.key) { keys.insert(a.key); order.append(a.key) } }
        func has(_ k: String) -> Bool { keys.contains(k) }
    }

    private static func describe(_ list: [Article], limit: Int = 1400) -> String {
        let lib = Library.shared
        if list.isEmpty { return "لا نتائج. جرّب مصطلحاً نظامياً آخر أو نظاماً آخر." }
        return list.map { a in
            let law = lib.law(a.lawID)?.name ?? ""
            let title = a.title.map { " (\($0))" } ?? ""
            let text = a.text.count > limit ? String(a.text.prefix(limit)) + "…" : a.text
            return "[\(a.key)] \(law) — \(a.displayHeading)\(title)\n\(text)"
        }.joined(separator: "\n\n")
    }

    private static func runSearch(_ query: String, lawID: String?, scope: String?, seen: Pool) -> String {
        let lib = Library.shared
        let s = (lawID.flatMap { lib.law($0) != nil ? $0 : nil }) ?? scope
        var out: [Article] = lib.index.numberLookup(query, in: s)
        for h in lib.index.search(query, in: s, limit: 10) where !out.contains(where: { $0.id == h.article.id }) {
            out.append(h.article)
        }
        out = Array(out.prefix(8))
        seen.add(out)
        return describe(out)
    }

    private static func runOpen(lawID: String, number: String, seen: Pool) -> String {
        let lib = Library.shared
        guard let law = lib.law(lawID) else { return "لا يوجد نظام بهذا المعرّف." }
        let num = ArabicText.fold(number).trimmingCharacters(in: .whitespaces)
        guard let i = law.articles.firstIndex(where: { $0.n == num || $0.label == num || $0.n == number || $0.label == number }) else {
            return "لا توجد مادة برقم \(number) في \(law.name)."
        }
        let range = max(0, i - 1)...min(law.articles.count - 1, i + 1)
        let list = Array(law.articles[range])
        seen.add(list)
        return describe(list, limit: 2500)
    }

    private static func catalog() -> String {
        Library.shared.laws.map { "\($0.id): \($0.name)" }.joined(separator: "\n")
    }

    // MARK: - Ask

    /// `step` reports what is happening (e.g. «يبحث: محرر عادي») so the screen isn't silent.
    static func ask(_ question: String, scope: String?,
                    step: @escaping @MainActor (String) -> Void = { _ in }) async throws -> AskRecord {
        let lib = Library.shared
        while !lib.indexReady { try? await Task.sleep(nanoseconds: 100_000_000) }
        let model = AskModel.current

        let seen = Pool()
        // A first look with the question's own words, so the model starts with something in hand.
        let first = runSearch(question, lawID: nil, scope: scope, seen: seen)

        let scopeLine = scope.flatMap { lib.law($0)?.name }.map { "السؤال محصور في: \($0)." } ?? ""
        let system = """
        أنت مساعد لقاضٍ سعودي، تجيب من نصوص الأنظمة واللوائح المحفوظة في جواله فقط، وتصل إليها بأداتي البحث وفتح المادة.
        طريقة العمل:
        ١. كيّف المسألة أولاً تكييفاً نظامياً: ما طبيعة الشيء المسؤول عنه في لغة الأنظمة؟ (مثلاً: الفاتورة الصادرة من الغير = محرر عادي / دليل كتابي، وأجرة نقل المركبة = من عناصر الضرر الفعلي). ثم ابحث بهذه المصطلحات لا بألفاظ السائل.
        ٢. ابحث أكثر من مرة وفي أكثر من نظام إن احتاج السؤال ذلك (الإثبات، المرافعات، المعاملات المدنية، المرور… حسب المسألة). افتح المادة إذا احتجت نصها كاملاً أو ما حولها.
        ٣. إن كان في السؤال أكثر من شق فأجب عن كل شق.
        ٤. سلّم الجواب بأداة final_answer: في answer الجواب المباشر وما تقرره النصوص، وفي application تطبيقها على السؤال مع التصريح بما هو استنتاج منك لا نص. لا تنسب إلى نص ما لم يقله، ولا تعتمد على معلومة من خارج المواد في تقرير حكم. إن لم تجد ما يحكم المسألة فقل ذلك بوضوح واجعل found=false.
        ٥. اكتب بعربية فصيحة موجزة، بلا عناوين ولا نقاط، ولا تنقل نص المادة حرفياً فهو يُعرض للقارئ تحته. استشهد في cites بمفاتيح المواد كما وردت بين المعقوفين.
        \(scopeLine)
        الأنظمة واللوائح المتاحة (المعرّف: الاسم):
        \(catalog())
        """

        var messages: [[String: Any]] = [[
            "role": "user",
            "content": "السؤال: \(question)\n\nنتائج بحث أولي بألفاظ السؤال (قد لا تكون هي المطلوبة):\n\(first)",
        ]]

        await step("يكيّف السؤال…")
        var final: [String: Any]?
        for round in 0..<7 {
            var body: [String: Any] = ["model": model.rawValue, "max_tokens": 2000, "system": system,
                                       "tools": tools, "messages": messages]
            if round == 6 { body["tool_choice"] = ["type": "tool", "name": "final_answer"] }
            let reply = try await post(body)
            guard let content = reply["content"] as? [[String: Any]] else { throw AskError.badReply }
            messages.append(["role": "assistant", "content": content])

            var results: [[String: Any]] = []
            for block in content where block["type"] as? String == "tool_use" {
                let id = block["id"] as? String ?? ""
                let name = block["name"] as? String ?? ""
                let input = block["input"] as? [String: Any] ?? [:]
                switch name {
                case "final_answer":
                    final = input
                case "search_laws":
                    let q = input["query"] as? String ?? ""
                    await step("يبحث: \(q)")
                    let r = runSearch(q, lawID: input["law_id"] as? String, scope: scope, seen: seen)
                    results.append(["type": "tool_result", "tool_use_id": id, "content": r])
                case "open_article":
                    let lawID = input["law_id"] as? String ?? ""
                    let num = input["number"] as? String ?? ""
                    await step("يقرأ المادة \(num) من \(lib.law(lawID)?.name ?? "")")
                    let r = runOpen(lawID: lawID, number: num, seen: seen)
                    results.append(["type": "tool_result", "tool_use_id": id, "content": r])
                default:
                    results.append(["type": "tool_result", "tool_use_id": id, "content": "أداة غير معروفة", "is_error": true])
                }
            }
            if final != nil { break }
            if results.isEmpty {
                // Answered in plain text instead of the tool: ask it to hand the answer over properly.
                messages.append(["role": "user", "content": "سلّم الجواب بأداة final_answer."])
            } else {
                messages.append(["role": "user", "content": results])
            }
            await step("يراجع المواد…")
        }
        guard let f = final else { throw AskError.badReply }

        let found = f["found"] as? Bool ?? false
        let answer = clean(f["answer"] as? String ?? "")
        let application = clean(f["application"] as? String ?? "")
        let cites = (f["cites"] as? [Any] ?? []).compactMap { "\($0)" }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "[] ")) }
            .filter { seen.has($0) || lib.article(key: $0) != nil }
        var unique: [String] = []
        for c in cites where !unique.contains(c) { unique.append(c) }
        let related = seen.order.filter { !unique.contains($0) }.prefix(found ? 3 : 5)
        return AskRecord(question: question, scope: scope, found: found && !unique.isEmpty,
                         answer: answer.isEmpty ? "ما وجدت نصاً يحكم سؤالك في مكتبتك." : answer,
                         application: application.isEmpty ? nil : application,
                         cites: unique, related: Array(related), date: Date(), model: model.name)
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: #"\s*\[[^\]\n]{1,40}\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
