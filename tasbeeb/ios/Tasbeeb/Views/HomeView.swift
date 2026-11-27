import SwiftUI

/// «قضاياي»: قائمة القضايا كالمحادثات، مع تصفية بالقسم وزر قضية جديدة.
struct HomeView: View {
    /// في الآيباد: القضية المختارة تُعرض بجانب القائمة؛ وفي الجوال nil فتُفتح بالتنقل
    var selection: Binding<UUID?>?
    @ObservedObject private var store = CaseStore.shared
    @State private var filter = ""
    @State private var query = ""
    @State private var openID: UUID?
    @State private var showSettings = false
    @State private var confirmDelete: UUID?

    private let filters: [(String, String)] = [("", "الكل"), ("huquqi", "حقوقي"), ("murori", "مروري"), ("ahwal", "أحوال"), ("jazai", "جزائي")]

    private var shown: [CaseRecord] {
        var r = filter.isEmpty ? store.cases : store.cases.filter { $0.cat == filter }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            r = r.filter { $0.title.contains(q) || $0.minutes.contains(q) || $0.lastLine.contains(q) }
        }
        return r
    }

    /// القضايا مجمّعة بالأيام: اليوم، أمس، ثم التاريخ
    private var grouped: [DayGroup] {
        let cal = Calendar.current
        var out: [DayGroup] = []
        for c in shown {
            let k: String
            if cal.isDateInToday(c.updated) { k = "اليوم" }
            else if cal.isDateInYesterday(c.updated) { k = "أمس" }
            else { k = Self.dayFmt.string(from: c.updated) }
            if let i = out.firstIndex(where: { $0.id == k }) { out[i].cases.append(c) } else { out.append(DayGroup(id: k, cases: [c])) }
        }
        return out
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()

    private var selectedID: UUID? { selection?.wrappedValue ?? nil }

    private func open(_ id: UUID) {
        if let sel = selection { sel.wrappedValue = id } else { openID = id }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("قضاياي").font(F.title(30)).foregroundStyle(T.ink)
                    Spacer()
                    Button { showSettings = true } label: { RoundIcon(system: "gearshape") }
                        .buttonStyle(.press)
                        .accessibilityLabel("الإعدادات")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(T.muted)
                    TextField("", text: $query, prompt: Text("ابحث باسم الدعوى أو كلمة من المحضر").foregroundStyle(T.muted))
                        .font(F.ui(14))
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(T.muted) }
                            .accessibilityLabel("مسح البحث")
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 42)
                .background(T.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(T.line))
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters.indices, id: \.self) { i in
                            let f = filters[i]
                            Button { filter = f.0 } label: {
                                Text(f.1)
                                    .font(F.ui(13, filter == f.0 ? .semibold : .regular))
                                    .foregroundStyle(filter == f.0 ? Color.white : T.ink)
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 34)
                                    .background(filter == f.0 ? T.accent : T.card, in: Capsule())
                                    .overlay(Capsule().strokeBorder(filter == f.0 ? Color.clear : T.line))
                            }
                            .buttonStyle(.press)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)

                if shown.isEmpty {
                    if query.isEmpty { empty } else {
                        Text("لا نتائج لـ«\(query)»").font(F.ui(15)).foregroundStyle(T.muted)
                            .frame(maxWidth: .infinity).padding(.top, 40)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(grouped) { g in
                            Section {
                                ForEach(g.cases) { c in
                                    Button { open(c.id) } label: { CaseRow(rec: c, selected: selectedID == c.id) }
                                        .buttonStyle(.plain)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                        .listRowBackground(selectedID == c.id ? T.accentSoft : T.card)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) { confirmDelete = c.id } label: { Label("حذف", systemImage: "trash") }
                                        }
                                }
                            } header: {
                                Text(verbatim: g.id).font(F.ui(13, .semibold)).foregroundStyle(T.muted)
                            }
                        }
                        Color.clear.frame(height: 80).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(T.card)
                }
            }

            HStack(spacing: 10) {
                Button {
                    let c = store.newCase()
                    open(c.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 20, weight: .bold))
                        Text("قضية جديدة").font(F.ui(16, .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 58)
                    .background(T.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: T.accent.opacity(0.35), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.press)
                // لصق المحضر مباشرة: قضية جديدة وفيها المحضر المنسوخ
                Button { pasteNew() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.clipboard").font(.system(size: 17, weight: .semibold))
                        Text("الصق محضراً").font(F.ui(14, .bold))
                    }
                    .foregroundStyle(T.accent)
                    .padding(.horizontal, 16)
                    .frame(height: 58)
                    .background(T.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(T.accent, lineWidth: 1.5))
                }
                .buttonStyle(.press)
                .accessibilityLabel("لصق محضر في قضية جديدة")
            }
            .padding(.leading, 20)
            .padding(.bottom, 24)
        }
        .background(T.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $openID) { id in
            CaseLoader(id: id, inSplit: false)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .confirmationDialog("حذف القضية نهائياً؟", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            Button("حذف", role: .destructive) {
                if let id = confirmDelete {
                    if selectedID == id { selection?.wrappedValue = nil }
                    store.delete(id)
                }
                confirmDelete = nil
            }
            Button("إلغاء", role: .cancel) { confirmDelete = nil }
        } message: { Text("تُحذف المحادثة ومرفقاتها من هذا الجهاز، ولا يمكن استرجاعها.") }
    }

    private func pasteNew() {
        guard let t = UIPasteboard.general.string, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let c = store.newCase()
            open(c.id)
            return
        }
        let c = store.newCase()
        store.pendingPaste[c.id] = t
        open(c.id)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "text.bubble").font(.system(size: 46, weight: .light)).foregroundStyle(T.accent)
            Text("لا توجد قضايا بعد").font(F.ui(18, .bold)).foregroundStyle(T.ink)
            Text("اضغط «قضية جديدة»، والصق المحضر\nأو أرفق صور البينات").font(F.ui(14)).foregroundStyle(T.muted)
                .multilineTextAlignment(.center)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct DayGroup: Identifiable {
    let id: String
    var cases: [CaseRecord]
}

struct CaseRow: View {
    let rec: CaseRecord
    var selected = false
    var body: some View {
        let c = T.cat(rec.cat)
        HStack(spacing: 12) {
            Text(verbatim: rec.cat.isEmpty ? "؟" : c.letter)
                .font(F.title(18))
                .foregroundStyle(c.ink)
                .frame(width: 50, height: 50)
                .background(c.soft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: rec.title).font(F.ui(16, .bold)).foregroundStyle(T.ink).lineLimit(1)
                    Spacer()
                    Text(rec.updated, format: .dateTime.hour().minute()).font(F.ui(12)).foregroundStyle(T.muted)
                }
                HStack(spacing: 6) {
                    if rec.ready {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(T.accent)
                    }
                    Text(verbatim: rec.lastLine.isEmpty ? "لم يبدأ بعد" : rec.lastLine)
                        .font(F.ui(14)).foregroundStyle(T.muted).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// يفتح القضية بجلسة خاصة بها.
struct CaseLoader: View {
    let id: UUID
    var inSplit = false
    var body: some View {
        if let r = CaseStore.shared.record(id) {
            CaseView(rec: r, inSplit: inSplit)
        } else {
            Text("القضية غير موجودة").font(F.ui(16)).foregroundStyle(T.muted)
        }
    }
}
