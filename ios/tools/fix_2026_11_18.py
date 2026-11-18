"""Corrections to laws.json from the check of 18 Nov 2026 against the Ministry of Justice
commentaries on نظام المعاملات المدنية and نظام الإثبات.

Run once from the repo root:  python3 ios/tools/fix_2026_11_18.py
Every change is listed in the output. It is idempotent: running it again changes nothing.

1. نظام المعاملات المدنية: eight wording errors (the text of the commentary, and for م٧٠٥ the
   official text on the Bureau of Experts site, have the correct wording).
2. نظام المعاملات المدنية: a section heading glued to the end of articles 32, 46 and 56.
3. نظام الإثبات: paragraph numbers («١- ٢-») missing in 73 articles, restored from the commentary.
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = os.path.join(ROOT, "laws.json")
NUMBERING = os.path.join(ROOT, "ios", "data", "fixes", "ithbat-numbering-2026-11-18.json")

WORDING = {
    "654": [("وحال الطرفان", "وحال الطرفين")],
    "660": [("(السادسة والستون بعد الستمائة)", "(السادسة والستين بعد الستمائة)")],
    "663": [("(الحادية والستون بعد الستمائة)", "(الحادية والستين بعد الستمائة)")],
    "666": [("هذه الأعذار", "هذا الإعذار")],
    "677": [("(الحادية والخمسون بعد الستمائة)", "(الحادية والخمسين بعد الستمائة)")],
    "701": [("مالك عقاري منفصلين", "مالك عقارين منفصلين")],
    "705": [("مأذون فيه", "مأذوناً فيه")],
    "715": [("إذا جزيء العقار", "إذا جُزِّئ العقار")],
}
GLUED_HEADING = re.compile(r"\n[١٢٣]- [^\n]+\n\.\s*$")
NUM = re.compile(r"^[١-٩]- ")

log = []


def art(law, n):
    for a in law["articles"]:
        if str(a["n"]) == str(n):
            return a
    raise KeyError(f"{law['id']} {n}")


def main():
    data = json.load(open(SITE))
    laws = {l["id"]: l for l in data["laws"]}

    madani = laws["madani"]
    for n, pairs in WORDING.items():
        a = art(madani, n)
        for bad, good in pairs:
            if bad in a["text"]:
                a["text"] = a["text"].replace(bad, good)
                log.append(f"المعاملات م{n}: «{bad}» ← «{good}»")
    for n in ("32", "46", "56"):
        a = art(madani, n)
        new = GLUED_HEADING.sub("", a["text"]).rstrip()
        if new != a["text"]:
            a["text"] = new
            log.append(f"المعاملات م{n}: حُذف عنوان الفقرة الملتصق بآخر النص")

    ithbat = laws["ithbat"]
    for n, fixed in json.load(open(NUMBERING)).items():
        a = art(ithbat, n)
        if a["text"] == fixed:
            continue
        plain = "\n".join(NUM.sub("", l) for l in fixed.split("\n"))
        if a["text"].strip() != plain.strip():
            log.append(f"الإثبات م{n}: تُرك — النص الحالي لا يطابق النص المتوقع دون ترقيم")
            continue
        a["text"] = fixed
        log.append(f"الإثبات م{n}: أعيد ترقيم الفقرات")

    if log and data.get("version", "") < "2026-11-18a":
        data["version"] = "2026-11-18a"
        log.append("تاريخ نصوص المكتبة ← 2026-11-18a")
    json.dump(data, open(SITE, "w"), ensure_ascii=False, separators=(",", ":"))
    print("\n".join(log) or "لا تغيير")
    print(len(log), "تغيير")


if __name__ == "__main__":
    main()
