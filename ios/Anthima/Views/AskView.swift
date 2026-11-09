import SwiftUI

/// «اسأل» — design ج: the question, then the answer with a clear «found / not found»,
/// and the article texts it rests on (from the app's own copy).
struct AskView: View {
    @ObservedObject private var nav = AppNav.shared
    @ObservedObject private var store = UserStore.shared
    @State private var question = ""
    @State private var scope: String? = nil
    @State private var current: AskRecord?
    @State private var asked: String?
    @State private var busy = false
    @State private var error: String?
    @State private var copied: String?
    @FocusState private var focused: Bool

    private var hasKey: Bool { KeyStore.key != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    head
                    if !hasKey { keyNotice }
                    if let asked {
                        Text(verbatim: asked)
                            .font(F.ui(15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(T.ink, in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18, bottomTrailingRadius: 6, topTrailingRadius: 18))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if busy {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("يدوّر في المواد…").font(F.ui(14)).foregroundStyle(T.muted)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(radius: 18)
                    }
                    if let error {
                        Text(verbatim: error).font(F.ui(14)).foregroundStyle(T.red)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading).card(radius: 14)
                    }
                    if let current, !busy { answerCard(current) }
                    if current == nil && !busy { suggestions }
                    if !store.history.isEmpty && !busy { historyList }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: busy)
            }
            inputBar
        }
        .background(T.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .keyboardDone()
        .onAppear(perform: takeDraft)
        .onChange(of: nav.askDraft) { _, _ in takeDraft() }
    }

    private func takeDraft() {
        if let d = nav.askDraft {
            question = d
            scope = nav.askScope
            nav.askDraft = nil
            nav.askScope = nil
            focused = true
        }
    }

    private var head: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [Color(hex: 0x6366F1), T.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("اسأل").font(F.title(26)).foregroundStyle(T.ink)
                Text("يجاوب من نصوص مكتبتك فقط، ويذكر المادة").font(F.ui(12)).foregroundStyle(T.muted)
            }
            Spacer()
            Menu {
                Button("كل الأنظمة") { scope = nil }
                ForEach(Library.shared.laws) { l in Button(l.name) { scope = l.id } }
            } label: {
                Text(verbatim: scope.flatMap { Library.shared.law($0)?.name } ?? "كل الأنظمة ▾")
                    .font(F.ui(12))
                    .lineLimit(1)
                    .foregroundStyle(T.accent)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: 140, minHeight: 36)
                    .background(T.accentSoft, in: Capsule())
            }
        }
    }

    private var keyNotice: some View {
        Button { nav.open(.settings) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("يحتاج مفتاح Anthropic").font(F.ui(15, .bold)).foregroundStyle(T.sandInk)
                Text("«اسأل» يكلّم Claude عبر الإنترنت ويُحسب عليك بالسؤال. أضف المفتاح من الإعدادات. البحث والتصفح يشتغلون بدونه.")
                    .font(F.ui(13)).foregroundStyle(T.ink).multilineTextAlignment(.leading)
                Text("افتح الإعدادات").font(F.ui(13, .semibold)).foregroundStyle(T.accent)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(T.sand, radius: 16)
        }
        .buttonStyle(.press)
    }

    private func answerCard(_ r: AskRecord) -> some View {
        let lib = Library.shared
        let cited = r.cites.compactMap { lib.article(key: $0) }
        let related = r.related.compactMap { lib.article(key: $0) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(r.found ? Color(hex: 0x2E8B57) : Color(hex: 0xC9822B)).frame(width: 8, height: 8)
                Text(r.found ? "وجدت نصاً صريحاً" : "ما وجدت نصاً صريحاً")
                    .font(F.ui(12, .semibold))
                    .foregroundStyle(r.found ? T.green : T.sandInk)
            }
            Text(verbatim: r.answer)
                .font(F.text(18))
                .foregroundStyle(T.ink)
                .lineSpacing(8)
                .textSelection(.enabled)
            ForEach(cited) { a in quote(a) }
            if !cited.isEmpty {
                HStack(spacing: 8) {
                    smallButton("نسخ") {
                        Clipboard.copy(r.answer + "\n\n" + cited.map { Clipboard.plain($0, law: lib.law($0.lawID)) }.joined(separator: "\n\n"))
                        copied = "نُسخ"
                    }
                    smallButton("نسخ للتسبيب") {
                        Clipboard.copy(cited.map { Clipboard.forReasoning($0, law: lib.law($0.lawID)) }.joined(separator: "، "))
                        copied = "نُسخ بصيغة التسبيب"
                    }
                }
                if let copied { Text(verbatim: copied).font(F.ui(12, .semibold)).foregroundStyle(T.green) }
            }
            if !related.isEmpty {
                Text(r.found ? "مواد قريبة" : "أقرب المواد لسؤالك").font(F.ui(12, .bold)).foregroundStyle(T.muted).padding(.top, 4)
                ForEach(related.prefix(4)) { a in
                    Button { nav.open(.article(a.key)) } label: { ArticleRow(article: a, showLaw: true) }
                        .buttonStyle(.press)
                }
            }
        }
        .padding(16)
        .card(radius: 18)
    }

    private func quote(_ a: Article) -> some View {
        let law = Library.shared.law(a.lawID)
        return Button { nav.open(.article(a.key)) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "\(law?.name ?? "") — \(a.displayHeading)")
                    .font(F.ui(12, .bold)).foregroundStyle(T.accent)
                Text(verbatim: "«\(a.text)»")
                    .font(F.text(15)).foregroundStyle(T.ink).lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .lineLimit(12)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(T.bg, radius: 14)
        }
        .buttonStyle(.press)
    }

    private func smallButton(_ t: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(F.ui(13)).foregroundStyle(T.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(T.line))
        }
        .buttonStyle(.press)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("جرّب تسأل").font(F.ui(12)).foregroundStyle(T.muted)
            FlowLayout(spacing: 6) {
                ForEach(["متى تعتد المحكمة بالدليل الناقص؟", "مدة الاعتراض بالاستئناف", "شروط قبول الدعوى", "التعويض عن الضرر"], id: \.self) { s in
                    Button { question = s; send() } label: {
                        Text(verbatim: s).font(F.ui(14)).foregroundStyle(T.ink)
                            .padding(.horizontal, 14).frame(minHeight: 40)
                            .background(Capsule().fill(Color.white).shadow(color: Color(hex: 0x111827).opacity(0.05), radius: 6, x: 0, y: 2))
                    }
                    .buttonStyle(.press)
                    .disabled(!hasKey)
                }
            }
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("أسئلتك السابقة").font(F.ui(12, .bold)).foregroundStyle(T.muted).padding(.top, 8)
            ForEach(store.history.prefix(8)) { r in
                Button {
                    current = r
                    asked = r.question
                    error = nil
                } label: {
                    HStack {
                        Text(verbatim: r.question).font(F.ui(14)).foregroundStyle(T.ink).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer()
                        Circle().fill(r.found ? Color(hex: 0x2E8B57) : Color(hex: 0xC9822B)).frame(width: 7, height: 7)
                    }
                    .padding(12)
                    .card(radius: 12)
                }
                .buttonStyle(.press)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("", text: $question, prompt: Text("اكتب سؤالك ولو بأخطاء…").foregroundStyle(T.muted), axis: .vertical)
                .lineLimit(1...4)
                .font(F.ui(15))
                .focused($focused)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(T.field, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(canSend ? T.accent : T.line, in: Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("أرسل")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
    }

    private var canSend: Bool {
        hasKey && !busy && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, hasKey, !busy else { return }
        focused = false
        asked = q
        question = ""
        error = nil
        current = nil
        busy = true
        Task {
            do {
                let r = try await AskService.ask(q, scope: scope)
                await MainActor.run {
                    current = r
                    copied = nil
                    store.remember(r)
                    busy = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    busy = false
                }
            }
        }
    }
}
