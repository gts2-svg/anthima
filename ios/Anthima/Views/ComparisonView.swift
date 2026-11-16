import SwiftUI

/// «المقارنة»: the old law against the new — the report, then article by article.
struct ComparisonView: View {
    let key: String
    @ObservedObject private var nav = AppNav.shared
    @State private var tab = 0
    @State private var open: Set<String> = ["summary"]

    private var cmp: Comparison? { Comparisons.all.first { $0.key == key } }

    var body: some View {
        if let c = cmp {
            let lib = Library.shared
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("مقارنة").font(F.ui(13, .semibold)).foregroundStyle(T.accent)
                    Text(verbatim: "\(lib.law(c.oldLaw)?.name ?? "") ← \(lib.law(c.newLaw)?.name ?? "")")
                        .font(F.title(22)).foregroundStyle(T.ink)
                    Text("تقرير أُعدّ مرة واحدة من نصوص النظامين ولائحتيهما. ارجع للنص قبل الاعتماد عليه.")
                        .font(F.ui(13)).foregroundStyle(T.muted)
                    Picker("", selection: $tab) {
                        Text("التقرير").tag(0)
                        Text("مادة بمادة").tag(1)
                    }
                    .pickerStyle(.segmented)
                    if tab == 0 { report(c) } else { mapList(c) }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .background(T.bg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        } else {
            Text("ما لقيت هذه المقارنة").font(F.ui(15)).foregroundStyle(T.muted)
        }
    }

    @ViewBuilder
    private func report(_ c: Comparison) -> some View {
        ForEach(c.sections) { s in
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if open.contains(s.key) { open.remove(s.key) } else { open.insert(s.key) }
                    }
                } label: {
                    HStack {
                        Text(verbatim: s.title).font(F.ui(17, .bold)).foregroundStyle(T.ink)
                        Spacer()
                        Image(systemName: open.contains(s.key) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(T.muted)
                    }
                }
                .buttonStyle(.plain)
                if open.contains(s.key) {
                    Text(verbatim: Comparison.readable(s.text))
                        .font(F.text(16)).foregroundStyle(T.ink).lineSpacing(7)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(radius: 18)
        }
    }

    @ViewBuilder
    private func mapList(_ c: Comparison) -> some View {
        if !c.lawMap.isEmpty {
            Text("مواد النظام").font(F.ui(15, .bold)).foregroundStyle(T.muted).padding(.top, 6)
            ForEach(c.lawMap) { r in row(c, r) }
        }
        if !c.regMap.isEmpty {
            Text("مواد اللائحة").font(F.ui(15, .bold)).foregroundStyle(T.muted).padding(.top, 6)
            ForEach(c.regMap) { r in row(c, r) }
        }
    }

    private func row(_ c: Comparison, _ r: Comparison.Row) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                chip(r.new, key: c.articleKey(r.new), strong: true)
                Image(systemName: "arrow.left").font(.system(size: 12)).foregroundStyle(T.muted)
                if r.old.isEmpty {
                    Text("لا مقابل").font(F.ui(13)).foregroundStyle(T.muted)
                } else {
                    ForEach(r.old, id: \.self) { o in chip(o, key: c.articleKey(o), strong: false) }
                }
                Spacer(minLength: 0)
                StatusPill(text: r.status == "معدّلة" ? "معدّلة" : r.status)
            }
            if let n = r.note, !n.isEmpty {
                Text(verbatim: n).font(F.ui(14)).foregroundStyle(T.ink).lineSpacing(4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(radius: 16)
    }

    private func chip(_ text: String, key: String?, strong: Bool) -> some View {
        Button {
            if let key { nav.open(.article(key)) }
        } label: {
            Text(verbatim: text)
                .font(F.ui(13, .semibold))
                .foregroundStyle(strong ? T.accent : T.amberInk)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(strong ? T.accentSoft : T.amberSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(key == nil)
    }
}
