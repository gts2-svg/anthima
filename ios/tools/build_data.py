"""Builds the app's laws file: the site's laws.json plus the uploaded additions,
with every regulation as its own entry (never merged into its law)."""
import json, re, sys, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = os.path.join(ROOT, "laws.json")
EXTRA = sorted(glob.glob(os.path.join(ROOT, "ios", "data", "extra-*.json")))
OUT = os.path.join(ROOT, "ios", "Anthima", "Resources", "laws.json")

CATS = [("qadaa", "القضاء والإجراءات"), ("madani", "المدني"), ("tijari", "التجاري"),
        ("jazai", "الجزائي"), ("muroor", "المرور والتأمين"), ("ahwal", "الأحوال الشخصية"),
        ("aqari", "العقار")]
AR = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
ITEM = re.compile(r"(?m)^\s*([0-9٠-٩]+)\s*/\s*([0-9٠-٩]+)\s*(?:[-–]\s*|\n|$)")
REG_NAME = {
    "murafaat": "اللائحة التنفيذية لنظام المرافعات الشرعية",
    "muroor": "اللائحة التنفيذية لنظام المرور",
    "tanfeethold": "اللائحة التنفيذية لنظام التنفيذ (١٤٣٣هـ) — ملغاة",
}


def kind_of(name):
    if name.startswith(("اللائحة", "لائحة")):
        return "reg"
    if name.startswith(("قواعد", "القواعد", "ضوابط", "الضوابط", "الأدلة", "الوثيقة", "جداول")):
        return "rules"
    return "law"


def clean_article(a):
    out = {k: a[k] for k in ("n", "label", "heading", "title", "part", "chapter", "text", "note") if a.get(k)}
    out.setdefault("n", "")
    out.setdefault("label", out["n"])
    out.setdefault("heading", "")
    out.setdefault("text", "")
    for k in ("amended", "repealed", "added"):
        if a.get(k):
            out[k] = a[k] if isinstance(a[k], (bool, str)) else True
    if out["text"].startswith(("ملغاة", "ملغى")):
        out["repealed"] = True
    return out


def split_regs(law):
    """Moves the «reg» notes of a law into a regulation entry of their own."""
    items = []
    for a in law["articles"]:
        reg = (a.get("reg") or "").strip()
        if not reg:
            continue
        marks = list(ITEM.finditer(reg))
        if not marks:
            items.append({"n": a["n"], "label": a["n"], "heading": "لائحة المادة " + a["label"],
                          "part": a.get("part", ""), "chapter": a.get("chapter", ""), "text": reg, "ref": a["n"]})
            continue
        for i, m in enumerate(marks):
            end = marks[i + 1].start() if i + 1 < len(marks) else len(reg)
            body = reg[m.end():end].strip()
            k, art = m.group(1).translate(AR), m.group(2).translate(AR)
            items.append({"n": f"{art}.{k}", "label": f"{k}/{art}", "heading": f"المادة {k}/{art}",
                          "part": a.get("part", ""), "chapter": a.get("chapter", ""), "text": body, "ref": art})
    return items


def main():
    site = json.load(open(SITE))["laws"]
    site.sort(key=lambda l: float(l.get("order", 999)))
    extra = [l for f in EXTRA for l in json.load(open(f))]
    have = {l["id"] for l in site}
    out = []

    def add(l, parent=None):
        arts = [clean_article(a) for a in l["articles"]]
        entry = {"id": l["id"], "name": l["name"], "cat": l.get("cat", "qadaa"), "kind": kind_of(l["name"]),
                 "decree": l.get("decree", ""), "source": l.get("source", ""), "articles": arts}
        if parent:
            entry["parent"] = parent
        out.append(entry)

    for l in site:
        add(l)
        regs = split_regs(l)
        if regs:
            out.append({"id": l["id"] + "_reg", "name": REG_NAME.get(l["id"], "اللائحة التنفيذية لـ" + l["name"]),
                        "cat": l.get("cat", "qadaa"), "kind": "reg", "decree": "", "source": l.get("source", ""),
                        "parent": l["id"], "articles": regs})
    for l in extra:
        if l["id"] in have:
            continue
        add(l)

    # link each regulation / rules entry to its law by name
    by_name = {l["name"]: l["id"] for l in out if l["kind"] == "law"}
    for l in out:
        if l["kind"] != "law" and "parent" not in l:
            for nm, lid in by_name.items():
                if nm.split(" (")[0] in l["name"]:
                    l["parent"] = lid
                    break

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    data = {"version": 1, "categories": [{"id": c, "name": n} for c, n in CATS], "laws": out}
    json.dump(data, open(OUT, "w"), ensure_ascii=False, separators=(",", ":"))
    total = sum(len(l["articles"]) for l in out)
    print(len(out), "entries,", total, "articles,", os.path.getsize(OUT) // 1024, "KB")
    for l in out:
        print(f"  {l['kind']:5} {l['cat']:7} {len(l['articles']):4}  {l['name']}" + (f"  ← {l['parent']}" if l.get("parent") else ""))


if __name__ == "__main__":
    main()
