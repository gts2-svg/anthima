import SwiftUI

/// «قضاياي»: قائمة القضايا كالمحادثات، مع تصفية بالقسم وزر قضية جديدة.
struct HomeView: View {
    @ObservedObject private var store = CaseStore.shared
    @State private var filter = ""
    @State private var openID: UUID?
    @State private var showSettings = false
    @State private var confirmDelete: UUID?

    private let filters: [(String, String)] = [("", "الكل"), ("huquqi", "حقوقي"), ("murori", "مروري"), ("ahwal", "أحوال"), ("jazai", "جزائي")]

    private var shown: [CaseRecord] {
        filter.isEmpty ? store.cases : store.cases.filter { $0.cat == filter }
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
                .padding(.bottom, 12)

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
                                    .background(filter == f.0 ? T.ink : Color.white, in: Capsule())
                                    .overlay(Capsule().strokeBorder(filter == f.0 ? Color.clear : T.line))
                            }
                            .buttonStyle(.press)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 14)

                if shown.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(shown) { c in
                            Button { openID = c.id } label: { CaseRow(rec: c) }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                .listRowBackground(Color.white)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { confirmDelete = c.id } label: { Label("حذف", systemImage: "trash") }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.white)
                }
            }

            Button {
                let c = store.newCase()
                openID = c.id
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
            .padding(.leading, 20)
            .padding(.bottom, 24)
        }
        .background(T.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $openID) { id in
            CaseLoader(id: id)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .confirmationDialog("حذف القضية نهائياً؟", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }), titleVisibility: .visible) {
            Button("حذف", role: .destructive) { if let id = confirmDelete { store.delete(id) }; confirmDelete = nil }
            Button("إلغاء", role: .cancel) { confirmDelete = nil }
        } message: { Text("تُحذف المحادثة ومرفقاتها من هذا الجهاز، ولا يمكن استرجاعها.") }
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

struct CaseRow: View {
    let rec: CaseRecord
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
                    Text(rec.updated, format: .relative(presentation: .named)).font(F.ui(12)).foregroundStyle(T.muted)
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
    var body: some View {
        if let r = CaseStore.shared.record(id) {
            CaseView(rec: r)
        } else {
            Text("القضية غير موجودة").font(F.ui(16)).foregroundStyle(T.muted)
        }
    }
}
