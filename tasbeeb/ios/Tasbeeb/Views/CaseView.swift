import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// محادثة القضية.
struct CaseView: View {
    @StateObject private var s: CaseSession
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showFiles = false
    @State private var showAlerts = false
    @State private var showDetails = false
    @State private var editing: Msg?
    @State private var showHistory = false
    @State private var copiedAll = false
    @FocusState private var focused: Bool
    let inSplit: Bool

    init(rec: CaseRecord, inSplit: Bool = false) {
        _s = StateObject(wrappedValue: CaseSession(rec))
        self.inSplit = inSplit
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if s.rec.messages.isEmpty { welcome }
                        let st = s.outputStart
                        let all = s.rec.messages
                        if let st, st > 0, !showHistory {
                            historyRow(count: st)
                        } else {
                            ForEach(Array(all.prefix(st ?? all.count))) { m in row(m) }
                            if let st, st > 0 {
                                Button { withAnimation { showHistory = false } } label: {
                                    Label("طيّ الخطوات السابقة", systemImage: "chevron.up").font(F.ui(13, .semibold)).foregroundStyle(T.accent)
                                }
                                .buttonStyle(.press)
                            }
                        }
                        if let st {
                            outputBar.id("out")
                            // التنبيهات صارت في الشريط فوق الناتج، فلا تتكرر فقاعتها بعده
                            ForEach(Array(all.suffix(from: st)).filter { $0.kind != .alerts }) { m in row(m) }
                        }
                        Color.clear.frame(height: 6).id("bottom")
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    // iPad: عرض مقروء لنص التسبيب بدل امتداده على عرض الشاشة كله
                    .frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: s.rec.messages.count) { _, _ in
                    // بعد الصياغة: إلى أول الناتج (التنبيهات ثم البينة) لا إلى آخره
                    let lastKind = s.rec.messages.last?.kind
                    if s.outputStart != nil && (lastKind == .tasbeeb || lastKind == .alerts) {
                        showHistory = false
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("out", anchor: .top) }
                    } else {
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                .onAppear {
                    if s.outputStart != nil { proxy.scrollTo("out", anchor: .top) } else { proxy.scrollTo("bottom", anchor: .bottom) }
                    if let t = CaseStore.shared.pendingPaste.removeValue(forKey: s.rec.id) { s.send(t) }
                }
            }
            composer
        }
        .background(T.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var imgs: [UIImage] = []
                for it in items {
                    if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { imgs.append(img) }
                }
                photoItems = []
                s.addImages(imgs)
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            var imgs: [UIImage] = []
            for u in urls {
                if u.pathExtension.lowercased() == "pdf" { s.addPDF(u); continue }
                let acc = u.startAccessingSecurityScopedResource()
                if let d = try? Data(contentsOf: u), let img = UIImage(data: d) { imgs.append(img) }
                if acc { u.stopAccessingSecurityScopedResource() }
            }
            s.addImages(imgs)
        }
        .sheet(isPresented: $s.showTypePicker, onDismiss: { s.typePickerClosed() }) { TypePicker(s: s) }
        .sheet(isPresented: $showAlerts) { AlertsSheet(s: s) }
        .sheet(isPresented: $showDetails) { DetailsSheet(s: s) }
        .sheet(item: $editing) { m in EditSheet(s: s, msg: m) }
        .onDisappear { s.discardIfEmpty() }
    }

    private var subtitle: String {
        if s.busy { return "يقرأ المرفقات…" }
        if let p = s.progress { return (s.view.catName.isEmpty ? "" : s.view.catName + " · ") + "سؤال \(p.current) من \(p.total)" }
        return s.view.catName.isEmpty ? "يقرأ على جهازك" : s.view.catName
    }

    @ViewBuilder private func row(_ m: Msg) -> some View {
        MessageView(m: m, s: s,
                    onAlerts: { showAlerts = true },
                    onEdit: { editing = m },
                    onDetails: { showDetails = true })
            .id(m.id)
    }

    /// ما قبل الناتج مطويّ في سطر واحد
    private func historyRow(count: Int) -> some View {
        Button { withAnimation { showHistory = true } } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(T.accent)
                Text(verbatim: "تم: المحضر والأسئلة (\(count) رسالة)").font(F.ui(13, .semibold)).foregroundStyle(T.ink)
                Spacer()
                Text("عرض").font(F.ui(13, .bold)).foregroundStyle(T.accent)
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold)).foregroundStyle(T.accent)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(T.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(T.line))
        }
        .buttonStyle(.press)
    }

    /// فوق الناتج: شريط التنبيهات، ونسخ الأجزاء كلها
    private var outputBar: some View {
        let a = s.view.alerts
        let red = a.contains { $0.lvl == "red" }
        return VStack(spacing: 8) {
            if !a.isEmpty {
                Button { showAlerts = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: red ? "exclamationmark.triangle.fill" : "bell.fill")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: "\(a.count) " + (a.count == 1 ? "تنبيه" : (a.count <= 10 ? "تنبيهات" : "تنبيهاً")) + " · للتذكير لا للضبط")
                                .font(F.ui(13, .bold))
                            Text(verbatim: (a.first(where: { $0.lvl == "red" }) ?? a[0]).title).font(F.ui(13)).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(red ? T.red : T.amber)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(red ? T.redSoft : T.amberSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(red ? T.redLine : T.amberLine))
                }
                .buttonStyle(.press)
            }
            if s.currentParts.count > 1 {
                Button {
                    UIPasteboard.general.string = s.currentParts.map { $0.text }.joined(separator: "\n\n")
                    copiedAll = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copiedAll = false }
                } label: {
                    Label(copiedAll ? "نُسخت الأجزاء كلها" : "نسخ الكل (\(s.currentParts.count) أجزاء)", systemImage: copiedAll ? "checkmark" : "doc.on.doc.fill")
                        .font(F.ui(13, .bold)).foregroundStyle(T.accent)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(T.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.press)
                .sensoryFeedback(.success, trigger: copiedAll) { _, now in now }
            }
        }
    }

    // MARK: الشريط العلوي

    private var header: some View {
        HStack(spacing: 10) {
            if !inSplit {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.backward").font(.system(size: 18, weight: .semibold)).foregroundStyle(T.ink)
                        .frame(width: 40, height: 44)
                }
                .accessibilityLabel("رجوع")
            }
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 17)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(T.accent, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: s.rec.title).font(F.ui(16, .bold)).foregroundStyle(T.ink).lineLimit(1)
                Text(verbatim: subtitle)
                    .font(F.ui(12)).foregroundStyle(s.progress == nil ? T.accent : T.amber)
            }
            Spacer()
            if !s.view.type.isEmpty {
                Button { showDetails = true } label: {
                    Image(systemName: "list.bullet.rectangle").font(.system(size: 18)).foregroundStyle(T.ink).frame(width: 40, height: 44)
                }
                .accessibilityLabel("البيانات")
                Button { showAlerts = true } label: {
                    ZStack(alignment: .topLeading) {
                        Image(systemName: "bell").font(.system(size: 18)).foregroundStyle(T.ink).frame(width: 40, height: 44)
                        if !s.view.alerts.isEmpty {
                            Text(verbatim: "\(s.view.alerts.count)").font(F.ui(10, .bold)).foregroundStyle(.white)
                                .frame(minWidth: 17, minHeight: 17).background(s.view.conflicts.isEmpty ? T.amber : T.red, in: Circle())
                                .offset(x: 2, y: 4)
                        }
                    }
                }
                .accessibilityLabel("التنبيهات")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(T.card)
        .overlay(alignment: .bottom) { Rectangle().fill(T.line).frame(height: 1) }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("الصق نص المحضر في الأسفل، وأرفق صور البينات من زر «+».")
                .font(F.ui(15)).foregroundStyle(T.ink)
            Text("أصنّف الدعوى، وأقرأ المرفقات على جهازك، وأسألك عن الناقص فقط، ثم أعطيك التسبيب جاهزاً.")
                .font(F.ui(13)).foregroundStyle(T.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(T.line))
    }

    // MARK: شريط الكتابة

    private var composer: some View {
        VStack(spacing: 6) {
            if let q = s.pendingTextQuestion {
                Text(verbatim: "تكتب الآن: " + (q.text.components(separatedBy: "\n").first ?? ""))
                    .font(F.ui(12)).foregroundStyle(T.amber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
            }
            HStack(alignment: .bottom, spacing: 8) {
                Menu {
                    Button { showPhotos = true } label: { Label("من الصور", systemImage: "photo.on.rectangle") }
                    Button { showFiles = true } label: { Label("ملف PDF أو صورة", systemImage: "doc") }
                    Button { pasteImage() } label: { Label("لصق صورة منسوخة", systemImage: "doc.on.clipboard") }
                } label: {
                    Image(systemName: "plus").font(.system(size: 20, weight: .semibold)).foregroundStyle(T.ink)
                        .frame(width: 44, height: 44).background(T.bg, in: Circle())
                }
                .accessibilityLabel("إرفاق")

                TextField("", text: $draft, prompt: Text(s.rec.minutes.isEmpty ? "الصق المحضر هنا…" : "اكتب ردّاً أو ملاحظة…").foregroundStyle(T.muted), axis: .vertical)
                    .font(F.ui(15))
                    .lineLimit(1...6)
                    .focused($focused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(T.bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                if draft.isEmpty && s.rec.minutes.isEmpty {
                    Button { pasteText() } label: {
                        Text("لصق").font(F.ui(14, .bold)).foregroundStyle(.white)
                            .frame(width: 56, height: 44).background(T.accent, in: Capsule())
                    }
                    .accessibilityLabel("لصق المحضر")
                } else {
                    Button {
                        let t = draft; draft = ""
                        s.send(t)
                    } label: {
                        Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 44, height: 44).background(draft.isEmpty ? T.muted : T.accent, in: Circle())
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("إرسال")
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(T.card)
        .overlay(alignment: .top) { Rectangle().fill(T.line).frame(height: 1) }
    }

    private func pasteText() {
        if let t = UIPasteboard.general.string, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            s.send(t)
        } else if UIPasteboard.general.hasImages {
            pasteImage()
        }
    }

    private func pasteImage() {
        let imgs = UIPasteboard.general.images ?? []
        if !imgs.isEmpty { s.addImages(imgs) }
    }
}
