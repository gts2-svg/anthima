"""Turn an uploaded Word file of Saudi laws (copied from the BOE site) into
laws.json-style entries: one entry per law, regulation or rules document."""
import json, re, sys
import docx
from docx.table import Table
from docx.text.paragraph import Paragraph

DOCS = {
    "نظام التحكيم": ("tahkeem", "qadaa"),
    "اللائحة التنفيذية لنظام التحكيم": ("tahkeemreg", "qadaa"),
    "نظام الإفلاس": ("iflas", "tijari"),
    "اللائحة التنفيذية لنظام الإفلاس": ("iflasreg", "tijari"),
    "القواعد المنظمة لإجراءات قضايا الإفلاس في المحاكم التجارية": ("iflasrules", "tijari"),
    "قواعد تحديد أتعاب الخبراء والأمناء في نظام الإفلاس": ("iflasfees", "tijari"),
    "القواعد المنظمة لإجراءات الإفلاس العابرة للحدود": ("iflascross", "tijari"),
    "نظام التسجيل العيني للعقار": ("tasjeel", "aqari"),
    "اللائحة التنفيذية لنظام التسجيل العيني للعقار": ("tasjeelreg", "aqari"),
    "نظام الشركات": ("sharikat", "tijari"),
}
NOISE = {"آخر تعديل", "النص الأصلي والتعديلات السابقة", "المادة الأصلية"}

UNITS = {"الأولى": 1, "الأول": 1, "الحادية": 1, "الحادي": 1, "الثانية": 2, "الثاني": 2,
         "الثالثة": 3, "الثالث": 3, "الرابعة": 4, "الرابع": 4, "الخامسة": 5, "الخامس": 5,
         "السادسة": 6, "السادس": 6, "السابعة": 7, "السابع": 7, "الثامنة": 8, "الثامن": 8,
         "التاسعة": 9, "التاسع": 9, "العاشرة": 10, "العاشر": 10}
TENS = {"العشرون": 20, "العشرين": 20, "الثلاثون": 30, "الثلاثين": 30, "الأربعون": 40, "الأربعين": 40,
        "الخمسون": 50, "الخمسين": 50, "الستون": 60, "الستين": 60, "السبعون": 70, "السبعين": 70,
        "الثمانون": 80, "الثمانين": 80, "التسعون": 90, "التسعين": 90}
WORDS = {"المائة": 100, "المئة": 100, "المائتين": 200, "المئتين": 200, "المائتان": 200,
         "الثلاثمائة": 300}
ORD_TOKENS = set(UNITS) | set(TENS) | set("و" + k for k in TENS) | set(WORDS) | {"عشرة", "عشر", "بعد"}


def split_heading(words):
    """«العشرون إنهاء الإجراء» → («العشرون», «إنهاء الإجراء»)."""
    toks = words.split()
    k = 0
    while k < len(toks) and toks[k] in ORD_TOKENS:
        k += 1
    return " ".join(toks[:k]), " ".join(toks[k:])


def ordinal(words):
    s = words.replace("ـ", "").strip()
    total = 0
    hundreds = 0
    m = re.search(r"بعد\s+(\S+)", s)
    if m:
        hundreds = WORDS.get(m.group(1), 0)
        s = s[:m.start()].strip()
    elif s in WORDS:
        return WORDS[s]
    for tok in re.split(r"\s+و?|\s+", s):
        tok = tok.strip()
        if tok.startswith("و") and tok[1:] in TENS:
            tok = tok[1:]
        if tok in UNITS:
            total += UNITS[tok]
        elif tok in TENS:
            total += TENS[tok]
        elif tok in ("عشرة", "عشر"):
            total += 10
    return total + hundreds if total or hundreds else None


def blocks(doc):
    body = doc.element.body
    for child in body.iterchildren():
        tag = child.tag.split('}')[-1]
        if tag == "p":
            yield Paragraph(child, doc)
        elif tag == "tbl":
            yield Table(child, doc)


def table_text(t):
    rows = []
    for r in t.rows:
        cells = []
        for c in r.cells:
            v = re.sub(r"[​\xa0]+", " ", c.text).strip()
            v = re.sub(r"\s+", " ", v)
            if not cells or cells[-1] != v:
                cells.append(v)
        rows.append(" | ".join(cells))
    return "\n".join(rows)


def parse(path):
    doc = docx.Document(path)
    laws, cur, art = [], None, None
    part = chapter = ""
    has_bab = False

    def close_article():
        nonlocal art
        if art and cur is not None:
            art["text"] = art["text"].strip()
            cur["articles"].append(art)
        art = None

    items = []
    for b in blocks(doc):
        if isinstance(b, Table):
            items.append(("table", table_text(b)))
            continue
        t = re.sub(r"[\u200b]+", "", b.text).replace("\xa0", " ").strip()
        if t and t not in NOISE:
            items.append(("p", t))

    def is_heading(t):
        m = re.match(r"^(?:المادة|مادة)\s+([^:：]+?)\s*(?:[:：]\s*(.*))?$", t)
        if not m or len(t) >= 160 or "\n" in t:
            return None
        ordw, rest = split_heading(m.group(1))
        n = ordinal(ordw) if ordw else None
        if n is None:
            return None
        sub = " ".join(x for x in [rest, (m.group(2) or "").strip()] if x)
        return n, ordw, sub

    def next_is_heading(k):
        for kind, t in items[k + 1:k + 3]:
            if kind == "p":
                return bool(is_heading(t)) or bool(re.match(r"^(الباب|الفصل)\s", t))
        return False

    for k, (kind, t) in enumerate(items):
        if kind == "table":
            if art is not None:
                art["text"] += ("\n" if art["text"] else "") + t
            continue
        title = t.rstrip(".").strip()
        if title in DOCS:
            close_article()
            lid, cat = DOCS[title]
            cur = {"id": lid, "name": title, "cat": cat, "decree": "", "partial": False,
                   "source": "من الملف المرفوع (نص هيئة الخبراء بمجلس الوزراء) بالنص الساري وآخر تعديلاته",
                   "articles": []}
            laws.append(cur)
            part = chapter = ""
            has_bab = False
            continue
        if cur is None:
            continue
        h = is_heading(t)
        if h:
            n, ordw, sub = h
            close_article()
            prev = max([int(a["n"]) for a in cur["articles"] if a["n"]] or [0])
            art = {"n": str(n), "label": str(n), "heading": "المادة " + ordw,
                   "part": part, "chapter": chapter, "text": ""}
            if n <= prev:
                art["n"] = art["label"] = str(prev + 1)
                art["note"] = "كذا ورد رقمها في المصدر، وترتيبها (" + str(prev + 1) + ")."
            if sub:
                art["title"] = sub
            continue
        if re.match(r"^الباب\s", t) and len(t) < 120:
            close_article(); has_bab = True; part = t; chapter = ""; continue
        if re.match(r"^الفصل\s", t) and len(t) < 120:
            close_article()
            if has_bab: chapter = t
            else: part = t; chapter = ""
            continue
        if re.match(r"^(الفرع|القسم)\s", t) and len(t) < 120:
            close_article(); chapter = t; continue
        if re.match(r"^(ملحق|الجدول|جدول)", t) and len(t) < 90:
            close_article()
            if t.startswith("ملحق"):
                part = t; chapter = ""
                continue
            art = {"n": "", "label": "", "heading": t, "part": part, "chapter": chapter, "text": ""}
            continue
        if (len(t) < 80 and not t.endswith((".", "،", "؛", ":")) and t not in ("ملغاة", "ملغى", "حذفت", "حُذفت")
                and (art is None or (next_is_heading(k) and art["text"]))):
            close_article(); part = t; chapter = ""; continue
        if art is None:
            art = {"n": "", "label": "", "heading": "", "part": part, "chapter": chapter, "text": ""}
        art["text"] += ("\n" if art["text"] else "") + t
    close_article()
    for l in laws:
        for i, a in enumerate(l["articles"]):
            a["order"] = i
    return laws


if __name__ == "__main__":
    out = parse(sys.argv[1])
    json.dump(out, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
    for l in out:
        nums = [int(a["n"]) for a in l["articles"] if a["n"]]
        extra = [a["heading"] for a in l["articles"] if not a["n"]]
        if extra: print("   unnumbered:", extra)
        gaps = [x for x in range(1, max(nums) + 1) if x not in nums] if nums else []
        dup = len(nums) - len(set(nums))
        print(l["id"], l["name"], len(l["articles"]), "max", max(nums) if nums else 0, "gaps", gaps[:10], "dup", dup)
