"""One-off corrections to laws.json from the review of 17 Nov 2026.

Run once from the repo root:  python3 ios/tools/fix_2026_11_17.py
Every change is listed in the output. It is idempotent: running it again changes nothing.
"""
import json, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SITE = os.path.join(ROOT, "laws.json")

BEFORE = "(النص المعروض هو النص قبل التعديل)"
INTRO = re.compile(r"(لتكون كما يل[ىي]\s*:|لتكون بالنص الآت[ىي]\s*:|وتكون بالنص الآتي\s*:)")
STOP = re.compile(r"^\s*(تم إضافة المادة|\(النص المعروض|وقد أعد مشروع|عُدلت هذه المادة)", re.M)

log = []


def art(law, n):
    for a in law["articles"]:
        if str(a["n"]) == str(n):
            return a
    raise KeyError(f"{law['id']} {n}")


def swap_from_note(law, n, fix_typos=None):
    """The note holds the text in force and the article shows the old one: swap them."""
    a = art(law, n)
    note = a.get("note") or ""
    if BEFORE not in note:
        return
    m = INTRO.search(note)
    if not m:
        return
    head = note[:m.start()].strip().rstrip("،, ")
    rest = note[m.end():]
    s = STOP.search(rest)
    new = (rest[:s.start()] if s else rest).strip().strip('"“”').strip()
    tail = (rest[s.start():] if s else "").replace(BEFORE, "").strip()
    for bad, good in (fix_typos or {}).items():
        new = new.replace(bad, good)
    old = a["text"].strip()
    a["text"] = new
    history = head.replace("حذفت هذه المادة من النظام", "استُبدلت هذه المادة").strip()
    a["note"] = (history + ".\n" + (tail + "\n" if tail and not tail.startswith("وقد أعد") else "")
                 + "النص قبل التعديل:\n" + old)
    a["amended"] = True
    log.append(f"{law['id']} {n}: النص الساري صار هو المعروض (كان في الملاحظة)")


def main():
    data = json.load(open(SITE))
    laws = {l["id"]: l for l in data["laws"]}

    # 1) Texts in force that sat in the notes.
    for n in ("118", "119", "120"):
        swap_from_note(laws["awraq"], n)
    swap_from_note(laws["insur"], "18", {"ينولى": "يتولى"})
    swap_from_note(laws["insur"], "22")

    a = art(laws["tanfeethold"], "46")
    if BEFORE in (a.get("note") or ""):
        add = "ولا يخل صدور أمر المنع من السفر - وفقاً للفقرة (1) من هذه المادة - بتنفيذ قرار الإبعاد الصادر من الجهة المختصة."
        a["text"] = a["text"].rstrip() + "\n" + add
        a["note"] = "عُدلت هذه المادة بالمرسوم الملكي رقم (م/52) وتاريخ 1444/4/22هـ بإضافة العبارة الأخيرة إلى عجزها."
        a["amended"] = True
        log.append("tanfeethold 46: أُضيفت عبارة التعديل إلى النص")

    # 2) An interpretation is not an amendment.
    a = art(laws["awraq"], "38")
    if BEFORE in (a.get("note") or ""):
        a["note"] = a["note"].replace(BEFORE, "").strip()
        log.append("awraq 38: حُذف «النص المعروض قبل التعديل» (تفسير لا تعديل)")

    # 3) Traffic 74: the word «المقررة» (Royal Decree م/50, 2/3/1447).
    a = art(laws["muroor"], "74")
    if "مضاعفة الغرامة للمخالفة" in a["text"]:
        a["text"] = a["text"].replace("مضاعفة الغرامة للمخالفة", "مضاعفة الغرامة المقررة للمخالفة")
        log.append("muroor 74: أُضيفت كلمة «المقررة»")

    # 4) Judiciary law: article 9 shows article 73's text; articles amended by م/100 (1448) not yet updated.
    q = laws["qadaa"]
    a = art(q, "9")
    wrong = art(q, "73")["text"].strip()
    if a["text"].strip() == wrong:
        a["text"] = ("تعذّر عرض نص هذه المادة: النسخة السابقة كان فيها نص المادة (الثالثة والسبعين) خطأً. "
                     "ارجع للنص الرسمي على موقع هيئة الخبراء حتى يُعاد استيراد النظام.")
        a["note"] = "عُدلت هذه المادة بالمراسيم الملكية (م/81) وتاريخ 13/7/1440هـ و(م/141) وتاريخ 19/10/1441هـ و(م/129) وتاريخ 30/11/1443هـ."
        a["unverified"] = True
        log.append("qadaa 9: أُزيل النص الخطأ ووُضع تنبيه")
    a = art(q, "73")
    if (a.get("note") or "").startswith("المادة الثانية والسبعين"):
        a["note"] = "عُدلت هذه المادة بالمرسوم الملكي رقم (م/81) وتاريخ 13/7/1440هـ."
        log.append("qadaa 73: نُظّفت الملاحظة")
    for n in ("31", "32", "35", "36", "37", "38", "39", "40", "41", "42"):
        a = art(q, n)
        warn = "تنبيه: عُدلت هذه المادة بالمرسوم الملكي رقم (م/100) وتاريخ 3/4/1448هـ، والنص المعروض قبل هذا التعديل. ارجع للنص الرسمي."
        if warn not in (a.get("note") or ""):
            a["note"] = ((a.get("note") or "").strip() + "\n" + warn).strip()
            a["unverified"] = True
            log.append(f"qadaa {n}: تنبيه بتعديل م/100")

    # 5) The 1433 execution law: repealed except two parts kept in force by Council of Ministers decision 746.
    t = laws["tanfeethold"]
    t["name"] = "نظام التنفيذ (١٤٣٣هـ) — ملغى عدا الحجز التحفظي والإعسار"
    t["status"] = "repealed"
    t["source"] = ("موقع هيئة الخبراء بمجلس الوزراء، بالنص الساري وتعديلاته حتى ١٤٤٨هـ، ولائحته التنفيذية من الملف المرفوع. "
                   "حل محله نظام التنفيذ (١٤٤٧هـ)، وبقي سارياً بموجب قرار مجلس الوزراء رقم (٧٤٦): الباب الثاني (الحجز التحفظي، "
                   "المواد ٢٣–٣٣) حتى نقل أحكامه إلى نظام المرافعات الشرعية، والفصل الأول من الباب الخامس (الإعسار، المواد ٧٧–٨٢) "
                   "حتى نفاذ نظام للإعسار المدني. وتبقى الأوراق التجارية الصادرة قبل النظام الجديد سندات تنفيذية مدة سنة. ويُعرض للمقارنة.")
    for a in t["articles"]:
        try:
            k = int(str(a["n"]).split(".")[0])
        except ValueError:
            continue
        if 23 <= k <= 33 or 77 <= k <= 82:
            if not a.get("inForce"):
                a["inForce"] = True
                part = "سادساً" if k <= 33 else "سابعاً"
                a["note"] = ((a.get("note") or "").strip() + f"\nسارية بموجب البند ({part}) من قرار مجلس الوزراء رقم (٧٤٦).").strip()
    log.append("tanfeethold: سارية المواد ٢٣–٣٣ و٧٧–٨٢، والباقي ملغى")

    # 6) The new commercial transactions law is not in force yet; the bills of exchange law still is.
    m = laws.get("muamalat")
    if m and m.get("status") != "pending":
        m["status"] = "pending"
        m["name"] = "نظام المعاملات التجارية — لم يُعمل به بعد"
        m["source"] = ("وافق عليه مجلس الوزراء في ١٦/٥/١٤٤٨هـ، ويُعمل به بعد مضي (مائة وثمانين) يومًا من تاريخ نشره في الجريدة الرسمية. "
                       "النص من صورة مرفوعة لم تُطابق بعد بنص الجريدة الرسمية. ويلغي عند نفاذه النظام التجاري ونظام الأوراق التجارية "
                       "ونظام الدفاتر التجارية (المادة ٢٦٩).")
        log.append("muamalat: لم يُعمل به بعد")
    aw = laws["awraq"]
    if "سيُلغى" not in (aw.get("source") or ""):
        aw["source"] = ((aw.get("source") or "").strip() + " ساري حالياً، وسيُلغى عند نفاذ نظام المعاملات التجارية.").strip()

    # 7) Text copied from the website's interface, and two headings.
    junk = re.compile(r"^\s*(آخر تعديل|النص الأصلي والتعديلات السابقة|تفاصيل إضافة المادة|مضافة)\s*$", re.M)
    for l in data["laws"]:
        for a in l["articles"]:
            for f in ("text", "reg", "note"):
                v = a.get(f)
                if v and junk.search(v):
                    a[f] = re.sub(r"\n{2,}", "\n", junk.sub("", v)).strip()
                    log.append(f"{l['id']} {a['n']}: حُذف نص من واجهة الموقع ({f})")

    data["version"] = "2026-11-17a"
    json.dump(data, open(SITE, "w"), ensure_ascii=False, separators=(",", ":"))
    print("\n".join(log) if log else "no changes")


if __name__ == "__main__":
    main()
