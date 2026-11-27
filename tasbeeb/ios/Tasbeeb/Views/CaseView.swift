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
    @FocusState private var focused: Bool

    init(rec: CaseRecord) {
        _s = StateObject(wrappedValue: CaseSession(rec))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if s.rec.messages.isEmpty { welcome }
                        ForEach(s.rec.messages) { m in
                            MessageView(m: m, s: s,
                                        onAlerts: { showAlerts = true },
                                        onEdit: { editing = m },
                                        onDetails: { showDetails = true })
                                .id(m.id)
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
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
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

    // MARK: الشريط العلوي

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.backward").font(.system(size: 18, weight: .semibold)).foregroundStyle(T.ink)
                    .frame(width: 40, height: 44)
            }
            .accessibilityLabel("رجوع")
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 17)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(T.accent, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: s.rec.title).font(F.ui(16, .bold)).foregroundStyle(T.ink).lineLimit(1)
                Text(verbatim: s.busy ? "يقرأ المرفقات…" : (s.view.catName.isEmpty ? "يقرأ على جهازك" : s.view.catName))
                    .font(F.ui(12)).foregroundStyle(T.accent)
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
        .background(Color.white)
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .background(Color.white)
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
