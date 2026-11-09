import SwiftUI

/// «المحفوظات» — saved articles, newest first.
struct SavedView: View {
    @ObservedObject private var store = UserStore.shared
    @ObservedObject private var nav = AppNav.shared

    var body: some View {
        let items = store.saved.compactMap { Library.shared.article(key: $0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(T.amber)
                            .frame(width: 72, height: 72)
                            .background(T.amberSoft, in: Circle())
                        Text("ما حفظت مواد بعد").font(F.ui(16, .bold)).foregroundStyle(T.ink)
                        Text("اضغط علامة الحفظ في أي مادة، وتلقاها هنا.")
                            .font(F.ui(14)).foregroundStyle(T.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }
                Text("المحفوظات").font(F.title(28)).foregroundStyle(T.ink).padding(.top, 4).padding(.bottom, 6)
                ForEach(items) { a in
                    Button { nav.open(.article(a.key)) } label: { ArticleRow(article: a, showLaw: true) }
                        .buttonStyle(.press)
                        .softScroll()
                        .contextMenu {
                            Button("إلغاء الحفظ", systemImage: "bookmark.slash", role: .destructive) { store.toggleSave(a) }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(T.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Key for «اسأل», reading size, and where the texts come from.
struct SettingsView: View {
    @ObservedObject private var store = UserStore.shared
    @State private var key = ""
    @State private var hasKey = KeyStore.key != nil
    @State private var status: String?
    @State private var testing = false
    @State private var model = AskModel.current

    var body: some View {
        Form {
            Section {
                if hasKey {
                    HStack {
                        Label("المفتاح محفوظ في جوالك", systemImage: "checkmark.seal.fill").foregroundStyle(T.green)
                        Spacer()
                    }
                    Button(testing ? "يجرّب…" : "جرّب المفتاح") {
                        testing = true
                        Task {
                            let s = await AskService.testKey()
                            await MainActor.run { status = s; testing = false }
                        }
                    }
                    .disabled(testing)
                    Button("احذف المفتاح", role: .destructive) {
                        KeyStore.set(nil)
                        hasKey = false
                        status = nil
                    }
                } else {
                    SecureField("sk-ant-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .environment(\.layoutDirection, .leftToRight)
                    Button("احفظ المفتاح") {
                        KeyStore.set(key.trimmingCharacters(in: .whitespacesAndNewlines))
                        key = ""
                        hasKey = KeyStore.key != nil
                        status = hasKey ? "انحفظ. جرّبه الحين." : nil
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).count < 20)
                }
            } header: {
                Text("مفتاح «اسأل»")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    if let status { Text(verbatim: status).foregroundStyle(T.accent) }
                    Text("من console.anthropic.com ← API Keys. يُحفظ في سلسلة مفاتيح الآيفون فقط، ويُحسب عليك بالسؤال. لا ترسله لأحد.")
                }
            }

            Section {
                Picker("نموذج الجواب", selection: $model) {
                    ForEach(AskModel.allCases) { m in Text(verbatim: m.name).tag(m) }
                }
                .pickerStyle(.segmented)
                .onChange(of: model) { _, m in AskModel.current = m }
            } header: {
                Text("نموذج «اسأل»")
            } footer: {
                Text(verbatim: model.note)
            }

            Section("حجم نص المادة") {
                HStack {
                    Text("أ").font(F.text(14))
                    Slider(value: $store.textSize, in: 14...30, step: 1)
                    Text("أ").font(F.text(26))
                }
                Text("تطبق المحاكم على القضايا المعروضة أمامها أحكام الشريعة الإسلامية.")
                    .font(F.text(store.textSize))
            }

            Section("المكتبة") {
                LabeledContent("الأنظمة واللوائح", value: "\(Library.shared.laws.count)")
                LabeledContent("المواد", value: "\(Library.shared.articleCount)")
                LabeledContent("الإصدار", value: Self.version)
            }
        }
        .navigationTitle("الإعدادات")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDone()
    }

    static var version: String {
        let i = Bundle.main.infoDictionary ?? [:]
        let v = i["CFBundleShortVersionString"] as? String ?? ""
        let b = i["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) · نسخة \(b)"
    }
}
