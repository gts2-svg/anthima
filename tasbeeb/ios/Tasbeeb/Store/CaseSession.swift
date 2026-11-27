import SwiftUI

/// يدير محادثة القضية: يحلّل المحضر، يقرأ المرفقات، يسأل عن الناقص بأزرار، ثم يصيغ التسبيب.
@MainActor
final class CaseSession: ObservableObject {
    @Published var rec: CaseRecord
    @Published var view: EngineView = .empty
    @Published var busy = false
    @Published var showTypePicker = false

    private let engine = Engine.shared
    private let store = CaseStore.shared

    init(_ rec: CaseRecord) {
        var r = rec
        // فقاعة «أقرأ المرفق…» محفوظة من جلسة انقطعت أثناء القراءة: لا قراءة جارية الآن
        r.messages.removeAll { $0.kind == .working }
        self.rec = r
        refresh()
    }

    /// عدد المرفقات قيد القراءة (صور وملفات PDF قد تُقرأ في الوقت نفسه)
    private var reading = 0

    // MARK: أدوات

    private func refresh() {
        if rec.minutes.isEmpty && rec.state == "{}" {
            view = .empty
        } else {
            let v = engine.view(rec.state)
            // تعذّر فك ما أعاده المحرك: أبقِ آخر عرض سليم بدل مسح النوع والتصنيف
            if v.type.isEmpty && !view.type.isEmpty { return }
            view = v
        }
        rec.cat = view.cat
        rec.typeName = view.typeName
    }

    private func save() {
        refresh()
        if let last = rec.messages.last(where: { $0.role == .bot && $0.kind != .working }) {
            rec.lastLine = last.kind == .tasbeeb ? "التسبيب جاهز" : String(last.text.prefix(80))
        }
        store.save(rec)
    }

    private func post(_ m: Msg) { rec.messages.append(m) }

    private func bot(_ text: String, level: String = "", lines: [String] = []) {
        post(Msg(role: .bot, kind: .info, text: text, level: level, lines: lines))
    }

    /// بداية الناتج الحالي في المحادثة: أول بطاقة من آخر صياغة (ما قبلها يُطوى)
    var outputStart: Int? {
        let ms = rec.messages
        guard let last = ms.lastIndex(where: { $0.kind == .tasbeeb && $0.answered != "old" }) else { return nil }
        var i = last
        while i > 0 && ms[i - 1].kind == .tasbeeb && ms[i - 1].answered != "old" { i -= 1 }
        return i
    }

    /// بطاقات الناتج الحالي
    var currentParts: [Msg] {
        guard let st = outputStart else { return [] }
        return rec.messages[st...].filter { $0.kind == .tasbeeb && $0.answered != "old" }
    }

    /// «سؤال ٢ من ٣» قبل الصياغة
    var progress: (current: Int, total: Int)? {
        guard rec.typeConfirmed, !rec.ready, !view.type.isEmpty else { return nil }
        let remaining = view.fields.filter { $0.needsAnswer && !rec.skipped.contains($0.k) }.count
            + ((!rec.evidenceDone && !view.chips.isEmpty) ? 1 : 0)
        guard remaining > 0 else { return nil }
        let asked = rec.messages.filter { ($0.kind == .question || $0.kind == .evidence) && $0.answered != nil && $0.key != "__type" }.count
        return (asked + 1, asked + remaining)
    }

    /// سؤال ما زال ينتظر رداً مكتوباً
    var pendingTextQuestion: Msg? {
        rec.messages.last { $0.kind == .question && $0.expectsText && $0.answered == nil }
    }

    // MARK: إدخال المستخدم

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if rec.minutes.isEmpty {
            post(Msg(role: .user, kind: .text, text: text))
            rec.minutes = text
            rec.state = engine.analyze(text, state: rec.state)
            refresh()
            askType()
        } else if let q = pendingTextQuestion, let k = q.key, text.count <= 300, !text.contains("\n") {
            answerMark(q.id, text)
            let field = k.hasPrefix("__confirm:") ? String(k.dropFirst(10)) : k
            rec.state = engine.setField(rec.state, field, text)
            refresh()
            advance()
        } else if text.count <= 60, !text.contains("\n"),
                  let q = rec.messages.last(where: { $0.kind == .question && $0.answered == nil }),
                  let key = q.key, !key.hasPrefix("__") || key.hasPrefix("__confirm:") {
            // ردّ مكتوب على سؤال بأزرار: إن طابق زراً («نعم»، «حضر وأقر») فهو ضغطه
            if let v = matchOption(q, text) { answer(q.id, v); return }
            // وإلا فهو قيمة للحقل إن قبلها المحرك (مثل «بيع» ← «عقد بيع»)، وإلا فهو كلام للمحضر
            let k = key.hasPrefix("__confirm:") ? String(key.dropFirst(10)) : key
            let next = engine.setField(rec.state, k, text)
            if engine.view(next).fields.first(where: { $0.k == k })?.status == "user" {
                answerMark(q.id, text)
                rec.state = next
                refresh()
                advance()
            } else {
                appendToMinutes(text, note: "«\(text)» ليس من خيارات السؤال، فأضفته إلى المحضر وأعدت تحليله. أجب السؤال بالأزرار.")
            }
        } else {
            appendToMinutes(text, note: "أضفت كلامك إلى المحضر وأعدت تحليله.")
        }
        save()
    }

    private func appendToMinutes(_ text: String, note: String) {
        post(Msg(role: .user, kind: .text, text: text))
        rec.minutes += "\n" + text
        rec.state = engine.analyze(rec.minutes, state: rec.state)
        refresh()
        bot(note)
        advance()
    }

    /// يطابق الرد المكتوب أحد أزرار السؤال (بالنص الظاهر أو بالقيمة)؛ عند الالتباس لا شيء
    private func matchOption(_ q: Msg, _ text: String) -> String? {
        let t = text.trimmingCharacters(in: .whitespaces)
        let pairs = q.options.indices.map { (q.options[$0], q.label(at: $0)) }
        if let p = pairs.first(where: { $0.0 == t || $0.1 == t }) { return p.0 }
        if t.count >= 2 {
            let a = pairs.filter { $0.1.contains(t) }
            if a.count == 1 { return a[0].0 }
        }
        let b = pairs.filter { $0.1.count >= 2 && t.contains($0.1) }
        return b.count == 1 ? b[0].0 : nil
    }

    private func askType() {
        guard !view.type.isEmpty else { return }
        let conf = view.conf == "high" ? "ثقة عالية" : (view.conf == "mid" ? "ثقة متوسطة، فتأكد" : "غير مؤكد، فاختره بنفسك")
        var lines: [String] = []
        if !view.docs.isEmpty { lines.append("وقرأت \(view.docs.count) مرفقاً.") }
        post(Msg(role: .bot, kind: .question, text: "صنّفتها: \(view.catName) — \(view.typeName)\n(\(conf))",
                 options: ["ok", "change"], labels: ["التصنيف صحيح", "غيّره"], key: "__type", lines: lines))
    }

    func answer(_ msgID: UUID, _ value: String) {
        guard let i = rec.messages.firstIndex(where: { $0.id == msgID }) else { return }
        let m = rec.messages[i]
        guard let key = m.key else { return }
        let shown = m.options.firstIndex(of: value).map { m.label(at: $0) } ?? value
        answerMark(msgID, shown)

        switch key {
        case "__type":
            if value == "change" { showTypePicker = true }
            else { rec.typeConfirmed = true; advance() }
        case "__alerts":
            break
        default:
            if key.hasPrefix("__confirm:") {
                let k = String(key.dropFirst(10))
                if value == "yes" {
                    if let current = view.fields.first(where: { $0.k == k })?.value, !current.isEmpty {
                        rec.state = engine.setField(rec.state, k, current)
                    }
                    refresh(); advance()
                } else {
                    askField(k, forceEdit: true)
                }
            } else if value == "__skip" {
                rec.skipped.append(key)
                advance()
            } else {
                rec.state = engine.setField(rec.state, key, value)
                refresh(); advance()
            }
        }
        save()
    }

    private func answerMark(_ id: UUID, _ shown: String) {
        if let i = rec.messages.firstIndex(where: { $0.id == id }) {
            rec.messages[i].answered = shown
            post(Msg(role: .user, kind: .text, text: shown))
        }
    }

    /// أُغلقت قائمة الأنواع دون اختيار: نكمل على التصنيف الحالي
    func typePickerClosed() {
        guard !rec.typeConfirmed, !view.type.isEmpty else { return }
        rec.typeConfirmed = true
        advance()
        save()
    }

    func chooseType(_ key: String) {
        closeOpenPrompts()
        rec.state = engine.setType(rec.state, key)
        rec.typeConfirmed = true
        rec.evidenceDone = false
        rec.skipped = []
        refresh()
        post(Msg(role: .user, kind: .text, text: view.typeName))
        bot("تمام، صارت: \(view.catName) — \(view.typeName).")
        advance()
        save()
    }

    // MARK: المرفقات

    func addImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let names = images.map { store.saveThumb($0) }
        post(Msg(role: .user, kind: .images, images: names))
        let work = Msg(role: .bot, kind: .working, text: images.count == 1 ? "أقرأ المرفق…" : "أقرأ \(images.count) مرفقات…")
        post(work); save()
        busy = true
        reading += 1
        Task {
            for (i, img) in images.enumerated() {
                let r = await OCR.read(image: img)
                ingest(r, name: "صورة \(i + 1)")
            }
            finishReading(work.id)
        }
    }

    func addPDF(_ url: URL) {
        post(Msg(role: .user, kind: .text, text: "📄 " + url.lastPathComponent))
        let work = Msg(role: .bot, kind: .working, text: "أقرأ الملف…")
        post(work); save()
        busy = true
        reading += 1
        Task {
            let accessing = url.startAccessingSecurityScopedResource()
            let r = await OCR.read(pdf: url)
            if accessing { url.stopAccessingSecurityScopedResource() }
            ingest(r, name: url.lastPathComponent)
            finishReading(work.id)
        }
    }

    private func ingest(_ r: OCR.Result, name: String) {
        if r.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bot("ما قدرت أقرأ نصاً من \(name). جرّب صورة أوضح أو لقطة شاشة.", level: "warn")
            return
        }
        let before = Set(view.conflicts.map { $0.title + $0.body })
        rec.state = engine.addDoc(rec.state, text: r.text, ocr: r.ocr, conf: r.confidence, name: name)
        refresh()
        guard let d = view.docs.last else { return }
        var lines = d.items.map { "\($0.label): \($0.v)" }
        let newConf = view.conflicts.filter { !before.contains($0.title + $0.body) }
        lines += newConf.map { "⚠︎ \($0.title): \($0.body)" }
        var m = Msg(role: .bot, kind: .doc, text: "قرأت: \(d.label)", level: newConf.isEmpty ? "" : "red", lines: lines)
        m.answered = d.weak ? "weak" : nil
        post(m)
    }

    private func finishReading(_ workID: UUID) {
        rec.messages.removeAll { $0.id == workID }
        reading = max(0, reading - 1)
        // عدة ملفات معاً: لا نصيغ إلا بعد انتهاء آخرها، وإلا تكررت بطاقات التسبيب
        guard reading == 0 else { save(); return }
        busy = false
        if !rec.minutes.isEmpty && rec.typeConfirmed { advance() }
        else if rec.minutes.isEmpty { bot("الحين الصق نص المحضر، وأربطه بالمرفقات.") }
        save()
    }

    func removeDoc(at index: Int) {
        rec.state = engine.removeDoc(rec.state, index: index)
        save()
    }

    // MARK: الأسئلة

    private func askField(_ k: String, forceEdit: Bool = false) {
        guard let f = view.fields.first(where: { $0.k == k }) else { return }
        if f.status == "unc" && !forceEdit {
            post(Msg(role: .bot, kind: .question, text: "\(f.label): \(f.shownValue)\nصحيح؟",
                     options: ["yes", "edit"], labels: ["نعم", "لا، أعدّل"], key: "__confirm:\(k)"))
            return
        }
        if f.kind == "choice" {
            let hint = f.status == "mis" ? "ما وجدته في المحضر — " : ""
            post(Msg(role: .bot, kind: .question, text: "\(hint)\(f.label)؟", options: f.options, labels: f.labels, key: k, level: f.status == "mis" ? "red" : "warn"))
        } else {
            let opts = f.req ? [String]() : ["__skip"]
            let labs = f.req ? [String]() : ["تخطَّ"]
            let ph = f.ph.isEmpty ? "" : "\n(\(f.ph))"
            post(Msg(role: .bot, kind: .question, text: "اكتب \(f.label)\(ph)", options: opts, labels: labs, key: k, expectsText: true, level: f.status == "mis" ? "red" : "warn"))
        }
    }

    /// السؤال التالي، أو البينات، أو التسبيب
    func advance() {
        guard rec.typeConfirmed, !view.type.isEmpty else { return }
        // سؤال مفتوح لم يُجب بعد؟ لا نكرر
        if rec.messages.contains(where: { ($0.kind == .question || $0.kind == .evidence) && $0.answered == nil }) { return }
        if let f = view.fields.first(where: { $0.needsAnswer && !rec.skipped.contains($0.k) }) {
            askField(f.k)
            return
        }
        if !rec.evidenceDone && !view.chips.isEmpty {
            post(Msg(role: .bot, kind: .evidence, text: "البينات المحددة من المحضر والمرفقات. عدّل إن احتجت ثم اضغط «تم».", key: "__ev"))
            return
        }
        produce()
    }

    func toggleEvidence(_ id: String) {
        rec.state = engine.toggleEv(rec.state, id)
        save()
    }

    func evidenceDone(_ msgID: UUID) {
        let on = view.chips.filter { $0.on }.map { $0.label }
        answerMark(msgID, on.isEmpty ? "بدون بينات" : on.joined(separator: "، "))
        rec.evidenceDone = true
        produce()
        save()
    }

    private func produce() {
        // البطاقات السابقة غير المعدّلة تُعلَّم بأنها نسخة سابقة، لئلا يُنسخ نص قديم
        for i in rec.messages.indices where rec.messages[i].kind == .tasbeeb && !rec.messages[i].edited {
            rec.messages[i].answered = "old"
        }
        var lines: [String] = []
        if view.generic { lines.append("هذا القسم بهيكل عام؛ عدّل النص ثم احفظه بـ«حفظ صياغتي» ليُستعمل لاحقاً.") }
        if let parts = view.parts, !parts.isEmpty {
            // كل جزء من الضبط في بطاقة مستقلة بزر نسخ خاص
            for p in parts {
                var m = Msg(role: .bot, kind: .tasbeeb, text: p.text)
                m.title = p.title
                post(m)
            }
        } else {
            post(Msg(role: .bot, kind: .tasbeeb, text: view.text, lines: lines))
        }
        rec.ready = true
        let a = view.alerts
        if !a.isEmpty {
            post(Msg(role: .bot, kind: .alerts, text: "عندي لك \(a.count) \(a.count == 1 ? "تنبيه" : (a.count <= 10 ? "تنبيهات" : "تنبيهاً"))", key: "__alerts"))
        }
    }

    /// يعيد الصياغة بعد أي تعديل من شاشة البيانات
    func regenerate(note: String = "حدّثت التسبيب بعد التعديل.") {
        refresh()
        bot(note)
        rec.evidenceDone = true
        closeOpenPrompts()
        produce()
        save()
    }

    /// يغلق الأسئلة وبطاقة البينات المفتوحة، وإلا بقي advance() متوقفاً عندها
    private func closeOpenPrompts() {
        for i in rec.messages.indices
        where (rec.messages[i].kind == .question || rec.messages[i].kind == .evidence) && rec.messages[i].answered == nil {
            rec.messages[i].answered = "—"
        }
    }

    /// حفظ تعديلات شاشة البيانات ولو أُغلقت دون «إعادة الصياغة»
    func commitEdits() { save() }

    /// قضية فُتحت ثم تُركت فارغة: لا تبقى في القائمة
    func discardIfEmpty() {
        if rec.minutes.isEmpty && rec.messages.isEmpty && rec.state == "{}" { store.delete(rec.id) }
    }

    func setFieldDirect(_ k: String, _ v: String) {
        rec.state = engine.setField(rec.state, k, v)
        refresh()
    }

    func toggleEvDirect(_ id: String) {
        rec.state = engine.toggleEv(rec.state, id)
        refresh()
    }

    // MARK: التسبيب

    func updateTasbeeb(_ msgID: UUID, _ text: String) {
        if let i = rec.messages.firstIndex(where: { $0.id == msgID }) {
            rec.messages[i].text = text
            rec.messages[i].edited = true
            save()
        }
    }

    /// مفتاح الصياغة: لكل جزء من الضبط (بينة المدعي، رصد البينات، التسبيب والحكم) صياغته
    private func wordingKey(_ title: String?) -> String {
        guard let t = title, !t.isEmpty else { return view.type }
        return view.type + "|" + t
    }

    func saveWording(_ m: Msg) {
        guard !view.type.isEmpty else { return }
        SavedWording.set(wordingKey(m.title), engine.tokenize(rec.state, m.text))
        let part = m.title.map { " (\($0))" } ?? ""
        bot("حفظت صياغتك\(part) لنوع «\(view.typeName)»، وتقدر تستعملها في القضايا القادمة من نفس النوع.")
        save()
    }

    var hasSavedWording: Bool {
        guard !view.type.isEmpty else { return false }
        let all = SavedWording.all()
        return all[view.type] != nil || all.keys.contains { $0.hasPrefix(view.type + "|") }
    }

    func useSavedWording() {
        guard !view.type.isEmpty else { return }
        let parts = view.parts ?? []
        let saved = parts.map { SavedWording.get(wordingKey($0.title)) }
        if !parts.isEmpty && saved.contains(where: { $0 != nil }) {
            // كل الأجزاء: المحفوظ منها بصياغة القاضي، والباقي كما صاغه المحرك
            for (p, s) in zip(parts, saved) {
                var m = Msg(role: .bot, kind: .tasbeeb, text: s.map { engine.fill(rec.state, $0) } ?? p.text,
                            lines: s == nil ? [] : ["من صياغتك المحفوظة."])
                m.title = p.title
                m.edited = s != nil
                post(m)
            }
        } else if let t = SavedWording.get(view.type) {
            var m = Msg(role: .bot, kind: .tasbeeb, text: engine.fill(rec.state, t), lines: ["من صياغتك المحفوظة."])
            m.edited = true
            post(m)
        } else { return }
        save()
    }

    func setCheck(_ id: String, _ on: Bool) {
        rec.checks[id] = on
        save()
    }
}
