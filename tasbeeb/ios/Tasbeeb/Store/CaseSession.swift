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
        self.rec = rec
        refresh()
    }

    // MARK: أدوات

    private func refresh() {
        view = rec.minutes.isEmpty && rec.state == "{}" ? .empty : engine.view(rec.state)
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
        } else if let q = pendingTextQuestion, let k = q.key {
            answerMark(q.id, text)
            let field = k.hasPrefix("__confirm:") ? String(k.dropFirst(10)) : k
            rec.state = engine.setField(rec.state, field, text)
            refresh()
            advance()
        } else if text.count <= 60, !text.contains("\n"),
                  let q = rec.messages.last(where: { $0.kind == .question && $0.answered == nil }),
                  let key = q.key, !key.hasPrefix("__") || key.hasPrefix("__confirm:") {
            let k = key.hasPrefix("__confirm:") ? String(key.dropFirst(10)) : key
            // ردّ مكتوب على سؤال بأزرار (مثل «بيع» بدل الخيارات المعروضة): يُعدّ جواباً لا إضافةً للمحضر
            answerMark(q.id, text)
            rec.state = engine.setField(rec.state, k, text)
            refresh()
            advance()
        } else {
            post(Msg(role: .user, kind: .text, text: text))
            rec.minutes += "\n" + text
            rec.state = engine.analyze(rec.minutes, state: rec.state)
            refresh()
            bot("أضفت كلامك إلى المحضر وأعدت تحليله.")
            advance()
        }
        save()
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
                    let current = view.fields.first { $0.k == k }?.value ?? ""
                    rec.state = engine.setField(rec.state, k, current)
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
        if rec.messages.contains(where: { ($0.kind == .question) && $0.answered == nil }) {
            for i in rec.messages.indices where rec.messages[i].kind == .question && rec.messages[i].answered == nil {
                rec.messages[i].answered = "—"
            }
        }
        produce()
        save()
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

    func saveWording(_ text: String) {
        guard !view.type.isEmpty else { return }
        SavedWording.set(view.type, engine.tokenize(rec.state, text))
        bot("حفظت صياغتك لنوع «\(view.typeName)»، وتقدر تستعملها في القضايا القادمة من نفس النوع.")
        save()
    }

    var hasSavedWording: Bool { !view.type.isEmpty && SavedWording.get(view.type) != nil }

    func useSavedWording() {
        guard let t = SavedWording.get(view.type) else { return }
        var m = Msg(role: .bot, kind: .tasbeeb, text: engine.fill(rec.state, t), lines: ["من صياغتك المحفوظة."])
        m.edited = true
        post(m)
        save()
    }

    func setCheck(_ id: String, _ on: Bool) {
        rec.checks[id] = on
        save()
    }
}
