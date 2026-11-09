// Builds «searchindex.dat» on the build machine, with the app's own search code, so the phone
// never has to index the laws itself. Then reads the file back and checks it gives the same
// results as a freshly built index; any difference stops the build.
//
//   buildindex <laws.json> <searchindex.dat>
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 3 else { fail("usage: buildindex <laws.json> <searchindex.dat>") }

guard let data = try? Data(contentsOf: URL(fileURLWithPath: args[1])),
      let file = LibraryFile.prepared(from: data) else { fail("cannot read \(args[1])") }

var t = Date()
let built = SearchIndex(laws: file.laws)
print(String(format: "indexed %d laws in %.2fs", file.laws.count, Date().timeIntervalSince(t)))

let blob = built.serialized(laws: file.laws)
do { try blob.write(to: URL(fileURLWithPath: args[2])) } catch { fail("cannot write \(args[2]): \(error)") }
print("wrote \(args[2]) — \(blob.count / 1024) KB")

t = Date()
guard let loaded = SearchIndex(data: blob, laws: file.laws) else { fail("the written index does not read back") }
print(String(format: "read back in %.2fs", Date().timeIntervalSince(t)))

let checks: [(String, String?)] = [
    ("مدة الاستيناف", nil), ("الماده الثلاثون مرافعات", nil), ("الدليل الناقض", nil),
    ("اليمين الحاسمة", "ithbat"), ("التعويض عن الضرر", nil), ("م 77 اثبات", nil),
    ("الاعتراض على الحكم", "murafaat"), ("شركه ذات مسؤوليه محدوده", nil),
]
for (q, scope) in checks {
    let a = Set(built.search(q, in: scope, limit: 100_000).map(\.article.id))
    let b = Set(loaded.search(q, in: scope, limit: 100_000).map(\.article.id))
    let na = built.numberLookup(q, in: scope).map(\.id)
    let nb = loaded.numberLookup(q, in: scope).map(\.id)
    guard a == b, na == nb else { fail("results differ for «\(q)»") }
    print("ok  «\(q)»: \(a.count) hits, \(na.count) by number")
}
