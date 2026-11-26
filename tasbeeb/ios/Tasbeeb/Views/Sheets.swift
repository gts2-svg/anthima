import SwiftUI

/// رأس موحّد للنوافذ المنبثقة.
struct SheetHeader: View {
    let title: String
    var sub: String = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(F.title(19)).foregroundStyle(T.ink)
                if !sub.isEmpty { Text(verbatim: sub).font(F.ui(13)).foregroundStyle(T.muted) }
            }
            Spacer()
            Button { dismiss() } label: { RoundIcon(system: "xmark", size: 38) }
                .buttonStyle(.press)
                .accessibilityLabel("إغلاق")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

// MARK: تغيير التصنيف

struct TypePicker: View {
    @ObservedObject var s: CaseSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let cat = Engine.shared.catalog
        VStack(spacing: 0) {
            SheetHeader(title: "اختر نوع الدعوى")
            List {
                ForEach(cat.cats, id: \.self) { c in
                    Section {
                        ForEach(cat.types.filter { $0.cat == c.key }, id: \.self) { t in
                            Button {
                                s.chooseType(t.key)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(verbatim: t.name).font(F.ui(15)).foregroundStyle(T.ink)
                                    Spacer()
                                    if t.key == s.view.type { Image(systemName: "checkmark").foregroundStyle(T.accent) }
                                }
                            }
                        }
                    } header: {
                        Text(verbatim: c.name).font(F.ui(13, .bold)).foregroundStyle(T.cat(c.key).ink)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(T.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .appEnvironment()
    }
}

// MARK: تنبيهات القاضي

struct AlertsSheet: View {
    @ObservedObject var s: CaseSession
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "تنبيهات القاضي", sub: "للتذكير فقط، ولا تدخل في الضبط")
            ScrollView {
                VStack(spacing: 10) {
                    if s.view.alerts.isEmpty {
                        Text("لا تنبيهات لهذه القضية.").font(F.ui(15)).foregroundStyle(T.muted).padding(.top, 30)
                    }
                    ForEach(Array(s.view.alerts.enumerated()), id: \.offset) { i, a in
                        let c = T.level(a.lvl)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: a.title).font(F.ui(15, .bold)).foregroundStyle(c.ink)
                            if !a.body.isEmpty { Para(text: a.body, size: 14, spacing: 4) }
                            ForEach(Array(a.checks.enumerated()), id: \.offset) { j, q in
                                let id = "\(s.view.type)_\(i)_\(j)"
                                Button {
                                    s.setCheck(id, !(s.rec.checks[id] ?? false))
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: (s.rec.checks[id] ?? false) ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 20)).foregroundStyle(T.accent)
                                        Text(verbatim: q).font(F.ui(14)).foregroundStyle(T.ink).lineSpacing(4)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(c.soft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .appEnvironment()
    }
}

// MARK: مراجعة البيانات (بديل المحادثة لتعديل أي شيء)

struct DetailsSheet: View {
    @ObservedObject var s: CaseSession
    @Environment(\.dismiss) private var dismiss
    @State private var changed = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "بيانات القضية", sub: s.view.catName + (s.view.typeName.isEmpty ? "" : " — " + s.view.typeName))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { s.showTypePicker = true } } label: { ReplyChip(text: "تغيير نوع الدعوى") }
                        .buttonStyle(.press)
                    ForEach(s.view.fields, id: \.k) { f in
                        FieldEditor(f: f) { v in s.setFieldDirect(f.k, v); changed = true }
                    }
                    if !s.view.chips.isEmpty {
                        Text("البينات").font(F.ui(15, .bold)).foregroundStyle(T.ink).padding(.top, 4)
                        FlowToggles(chips: s.view.chips) { id in s.toggleEvDirect(id); changed = true }
                    }
                    if !s.view.docs.isEmpty {
                        Text("المرفقات").font(F.ui(15, .bold)).foregroundStyle(T.ink).padding(.top, 4)
                        ForEach(Array(s.view.docs.enumerated()), id: \.offset) { i, d in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: d.label).font(F.ui(14, .bold))
                                    Text(verbatim: d.items.map { "\($0.label): \($0.v)" }.joined(separator: " · "))
                                        .font(F.ui(12)).foregroundStyle(T.muted).lineLimit(2)
                                }
                                Spacer()
                                Button(role: .destructive) { s.removeDoc(at: i); changed = true } label: {
                                    Image(systemName: "trash").foregroundStyle(T.red)
                                }
                                .accessibilityLabel("حذف المرفق")
                            }
                            .padding(12)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            Button {
                s.regenerate()
                dismiss()
            } label: {
                Text("إعادة الصياغة").font(F.ui(16, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(T.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.press)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(T.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .appEnvironment()
    }
}

struct FieldEditor: View {
    let f: EngineField
    var set: (String) -> Void
    @State private var text = ""

    private var tag: (String, Color) {
        switch f.status {
        case "ok": return ("مستخرج", T.accent)
        case "unc": return ("للتأكيد", T.amber)
        case "mis": return ("ناقص", T.red)
        case "user": return ("اختيارك", T.accent)
        default: return ("اختياري", T.muted)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(verbatim: f.label).font(F.ui(14, .bold)).foregroundStyle(T.ink)
                Spacer()
                Text(verbatim: tag.0).font(F.ui(12, .semibold)).foregroundStyle(tag.1)
            }
            if f.kind == "choice" {
                WrapLayout(spacing: 6) {
                    ForEach(f.options.indices, id: \.self) { i in
                        let on = f.options[i] == f.value
                        Button { set(f.options[i]) } label: {
                            Text(verbatim: i < f.labels.count ? f.labels[i] : f.options[i])
                                .font(F.ui(13, on ? .semibold : .regular))
                                .foregroundStyle(on ? Color.white : T.ink)
                                .padding(.horizontal, 12).frame(minHeight: 38)
                                .background(on ? T.accent : Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(on ? Color.clear : T.line))
                        }
                        .buttonStyle(.press)
                    }
                }
            } else {
                TextField("", text: $text, prompt: Text(verbatim: f.ph).foregroundStyle(T.muted), axis: .vertical)
                    .font(F.ui(15))
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onAppear { text = f.value }
                    .onSubmit { set(text) }
                    .onChange(of: text) { _, v in if v != f.value { set(v) } }
            }
        }
        .padding(12)
        .background(f.status == "unc" ? T.amberSoft : (f.status == "mis" ? T.redSoft : Color.white.opacity(0.6)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: تعديل نص التسبيب

struct EditSheet: View {
    @ObservedObject var s: CaseSession
    let msg: Msg
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "تعديل التسبيب")
            TextEditor(text: $text)
                .font(F.ui(16))
                .lineSpacing(8)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
            Button {
                s.updateTasbeeb(msg.id, text)
                dismiss()
            } label: {
                Text("حفظ التعديل").font(F.ui(16, .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(T.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.press)
            .padding(20)
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear { text = msg.text }
        .appEnvironment()
    }
}

// MARK: الإعدادات

struct SettingsView: View {
    @ObservedObject private var store = CaseStore.shared
    @State private var gDate = Date()
    @State private var hD = ""
    @State private var hM = ""
    @State private var hY = ""
    @State private var hResult = ""
    @State private var confirmAll = false
    @State private var arabicOK = OCR.arabicSupported

    private var hijriCal: Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.locale = Locale(identifier: "ar_SA@numbers=latn")
        return c
    }

    private var gToH: String {
        let c = hijriCal.dateComponents([.day, .month, .year], from: gDate)
        return String(format: "%02d/%02d/%dهـ", c.day ?? 0, c.month ?? 0, c.year ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "الإعدادات")
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    card {
                        Text("هجري ↔ ميلادي (أم القرى)").font(F.ui(15, .bold))
                        DatePicker("من ميلادي", selection: $gDate, displayedComponents: .date)
                            .font(F.ui(14))
                            .environment(\.calendar, Calendar(identifier: .gregorian))
                        Text(verbatim: gToH).font(F.ui(16, .bold)).foregroundStyle(T.accent)
                        Divider()
                        Text("من هجري").font(F.ui(14))
                        HStack(spacing: 8) {
                            numField("يوم", $hD); numField("شهر", $hM); numField("سنة", $hY)
                            Button("تحويل") { convertH() }.font(F.ui(14, .bold))
                        }
                        if !hResult.isEmpty { Text(verbatim: hResult).font(F.ui(16, .bold)).foregroundStyle(T.accent) }
                    }
                    card {
                        Text("قراءة المرفقات").font(F.ui(15, .bold))
                        HStack {
                            Image(systemName: arabicOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(arabicOK ? T.accent : T.amber)
                            Text(arabicOK ? "هذا الجهاز يقرأ العربية في الصور، والقراءة كلها على الجهاز." :
                                    "هذا الجهاز لا يدعم قراءة العربية في الصور؛ ملفات PDF الرقمية تُقرأ عادي.")
                                .font(F.ui(13)).foregroundStyle(T.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    card {
                        Text("الخصوصية").font(F.ui(15, .bold))
                        Text("المحاضر والمرفقات تبقى على هذا الجهاز فقط، ولا يتصل التطبيق بالإنترنت.")
                            .font(F.ui(13)).foregroundStyle(T.muted).fixedSize(horizontal: false, vertical: true)
                        Button(role: .destructive) { confirmAll = true } label: {
                            Text("حذف كل القضايا").font(F.ui(14, .bold)).foregroundStyle(T.red)
                        }
                        .disabled(store.cases.isEmpty)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(T.bg.ignoresSafeArea())
        .confirmationDialog("حذف كل القضايا نهائياً؟", isPresented: $confirmAll, titleVisibility: .visible) {
            Button("حذف الكل", role: .destructive) { store.deleteAll() }
            Button("إلغاء", role: .cancel) {}
        } message: { Text("تُحذف \(store.cases.count) قضية ومرفقاتها من هذا الجهاز، ولا يمكن استرجاعها.") }
        .appEnvironment()
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { c() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func numField(_ p: String, _ b: Binding<String>) -> some View {
        TextField(p, text: b)
            .keyboardType(.numberPad)
            .font(F.ui(15))
            .multilineTextAlignment(.center)
            .frame(minWidth: 56, minHeight: 40)
            .background(T.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func convertH() {
        guard let d = Int(hD), let m = Int(hM), let y = Int(hY) else { hResult = "أدخل اليوم والشهر والسنة"; return }
        var comps = DateComponents()
        comps.day = d; comps.month = m; comps.year = y
        guard let date = hijriCal.date(from: comps),
              hijriCal.component(.day, from: date) == d else { hResult = "تاريخ غير صحيح في تقويم أم القرى"; return }
        let g = Calendar(identifier: .gregorian).dateComponents([.day, .month, .year], from: date)
        hResult = String(format: "%02d/%02d/%dم", g.day ?? 0, g.month ?? 0, g.year ?? 0)
    }
}
