# Criminal (جزائي) types for مولّد التسبيب: report

Files:
- `/home/claude/specs/jazai_types.js`: the code to insert into `engine.js` immediately before the line `T.ahwal = {`.
- `/home/claude/specs/jazai_test.js`: builds `/tmp/engine_merged_jazai.js`, runs the criminal samples, and re-runs the civil and traffic tests.

Test result: **121 passed, 0 failed**. `engine_test.js` and `traffic_test.js` produce **byte-identical output** on the merged engine and the original. `traffic_test2.js` is also identical. 13 civil, family and traffic minutes give the same cat, type, conf, text, alerts and fields on both engines.

## 1. Jurisdiction: why the General Court in أضم hears these cases

- **نظام الإجراءات الجزائية (م/2 dated 22/1/1435هـ), Art. 128:** the Criminal Court hears all criminal cases.
- **Art. 129:** where there is no Criminal Court, the General Court hears criminal matters unless the Supreme Judicial Council decides otherwise. This applies to the users of the app.
- **Art. 147:** the victim or the heirs may claim the private right (الحق الخاص) before the court hearing the public case, at any stage. **Art. 151:** dropping the private claim does not affect the public case.

## 2. Types added (all `cat:'jazai'`)

| key | name | why / basis |
|---|---|---|
| `jzDrugs` | تعاطي المخدرات أو حيازتها بقصد التعاطي | One of the most common prosecution cases. Art. 41 of نظام مكافحة المخدرات (6 months to 2 years). Art. 53 covers confiscation. Trafficking and smuggling (ترويج/تهريب) are scored down and trigger a red alert, because they carry different penalties. |
| `jzAssault` | اعتداء بالضرب أو إيذاء | Discretionary تعزير. The private right (أرش) is supported by تقرير مقدري الشجاج. An alert notes that قصاص-level injuries need mandatory review (Art. 194). |
| `jzTheft` | سرقة (تعزيرية) | Discretionary theft. It has an optional sentence «لم تتكامل شروط إقامة حد السرقة». The private right covers return of the stolen items or their value. A red-flag checklist covers حدّ conditions, because قطع needs mandatory review (Art. 194). |
| `jzHarass` | تحرش | نظام مكافحة جريمة التحرش, Art. 1 (definition) and Art. 6 (penalties). There is a field for the aggravating circumstances listed in Art. 6/2 and an optional order to publish the judgment. |
| `jzInsult` | سب وشتم | Discretionary تعزير. A red alert fires if the words amount to قذف (a حدّ, not تعزير). An alert suggests `jzCyber` when the insult was made online. |
| `jzCyber` | جريمة معلوماتية | نظام مكافحة جرائم المعلوماتية. Art. 3 covers ف2 (threats/extortion), ف4 (privacy via camera phone) and ف5 (defamation). Art. 6 ف1 covers content against public order or morals. Art. 13 covers confiscation of devices. |
| `jazai` (existing, kept) | هيكل جزائي عام | The fallback when no specific type scores at least 3. It is **not replaced**: the original `T.jazai` stays in the file. At runtime, `jzUp()` adds the criminal fields, evidence and builder to it, and it keeps `generic:1`. **Do not delete the existing `T.jazai` lines.** |

Each type has its own `kw`, `fields` with `detect`, `ev` items {id, label, kw, item, det}, `build`, and judge-only `alerts`.

Fields shared by all types:
- التهمة: taken from «أطلب إثبات إدانته بـ…» in the prosecutor's words.
- جواب المدعى عليه: اعتراف / اعتراف ببعض التهمة / إنكار مع الرجوع عن اعتراف مصدق / إنكار / غائب.
- النتيجة: defaults to «ثبوت الإدانة» only when there is a full confession; otherwise it stays empty and a red alert fires.
- Penalty fields, which the judge fills: مدة السجن، الغرامة، عقوبة أخرى.
- احتساب مدة الإيقاف.
- الجنسية (drugs only).
- المجني عليه، الحق الخاص (none / waiver / money claim / reserved), مبلغ الحق الخاص.

**The app never picks a penalty or amount.** When the penalty fields are empty, the text reads «وتعزيره لذلك بـ(…)». The statutory ranges appear only in alerts.

Generated parts:
- «رصد البينات»: «وقد اطلعت الدائرة على …؛ هكذا تضمنت.», followed by closing of the pleadings, unless the minutes already record it.
- «التسبيب والحكم»: claim, then answer, then evidence, then the legal description, then the private right, then «وعليه ومن أجل ذلك كله. حكمت الدائرة …، وبذلك حكمت والله أعلم وأحكم.», then the criminal closing.
- If the accused is absent, the output is a single «القرار» under Art. 140. A conviction in absence is never produced.

Criminal closing, which replaces the civil 50k-finality closing:
«…الاعتراض عليه بطلب الاستئناف خلال ثلاثين يوماً من تاريخ تسلّم صورة صك الحكم أو إيداعها ملف الدعوى، فإن لم يُقدَّم الاعتراض خلالها سقط الحق في طلب الاستئناف واكتسب الحكم القطعية، وفقاً للمواد 192 و193 و194 من نظام الإجراءات الجزائية»

The articles are written out in ordinal words in the text. The closing names المدعي العام and the accused, and also المجني عليه when a private right is claimed or reserved.

Party wording:
- The accused is «المدعى عليه/ها» if the minutes use that term, otherwise «المتهم/ة».
- The prosecutor is «المدعي العام», or «ممثل النيابة العامة» if only that term appears.
- The victim is «المجني عليه/ها».
- Gender comes from the `dG` field or from «المتهمة».
- The text says «الدائرة» throughout; `soloVoice()` converts it for single-judge minutes. This is tested.

## 3. How it hooks into the engine without touching civil types

- `CAT_SIGNS.jazai.push(...)` adds new signals:
  - Ungated: ممثل النيابة, لائحة الدعوى العامة, المتهم.
  - Gated (only count when a criminal marker is present): إثبات إدانته, المصدق شرعاً, المختبر الجنائي, محضر القبض.
- The criminal markers are: المدعي العام / ممثل النيابة / لائحة الدعوى العامة / الدائرة الجزائية / المتهم.
- **Every `kw` regex of the criminal types is gated the same way** (`jzRe`). A civil injury or contract claim that mentions «اعتدى» or «السرقة» is not pulled into the criminal category (tested).
- Six function wrappers delegate to the original function unless `T[S.type].cat==='jazai'`: `classify` (adds the fallback to the generic type), `extractCommon` (clears the civil `pos` field), `extractType`, `allFields` (hides civil fields and keeps only `dG`), `generate`, and `buildAlerts` (criminal alerts, with no 50k or civil Art. 57 alerts).
- Reassigning function declarations works in strict mode (checked). The code uses no lookbehind, so it is safe for JavaScriptCore.
- Known UI limitation: `view()` builds chips as `t.ev + EV_COMMON`, so the civil chip «يمين المدعى عليه (نفي)» still shows on criminal types. It is ignored in the criminal text. Hiding it would mean changing `view()`.

## 4. Excluded matters

| matter | reason |
|---|---|
| ترويج / تهريب المخدرات | Within the court's jurisdiction, but the penalties are heavier (some up to death, which needs mandatory review under Art. 194), and the relevant articles were not verified. It is scored down and flagged. |
| حيازة سلاح بدون ترخيص | **Jurisdiction not verified.** The 1442هـ implementing-regulation amendments on uqn.gov.sa only show administrative handling (General Directorate of Weapons and Explosives). The law text (qadha.org.sa PDF) could not be fetched because the permission request timed out. Decide whether some violations go to an administrative committee before adding this type. |
| التزوير / الرشوة | Criminal jurisdiction moved from ديوان المظالم to the MOJ courts in 1437هـ (press report, almowaten.net, May 2016). So these are General-Court matters where no Criminal Court exists. Not implemented because نظام مكافحة التزوير articles were not verified. |
| حدّ القذف، حدّ المسكر، السرقة الحدية | These are حدود, not تعزير. Only alerts cover them, inside `jzInsult` and `jzTheft`. |
| القصاص / الحدود with قتل، قطع، رجم | These need mandatory review (Art. 194/199) and a different structure. |
| Terrorism | Goes to المحكمة الجزائية المتخصصة (from general knowledge; the source was not fetched because alqassim.gov.sa was unreachable). |
| Traffic accidents (public right) | Left to the existing `murori` category. |

## 5. Articles used, with sources

**In generated text (all verified):**

- **نظام الإجراءات الجزائية (م/2، 22/1/1435هـ), Arts. 129, 140, 192, 193, 194.** Source: MOJ copy of the law text, https://adlm.moj.gov.sa/attach/1291.pdf
  - 192: the convicted person, the prosecutor and the private claimant may object by appeal or review, and the court informs them when the judgment is pronounced.
  - 193: judgment copy within 10 days; the deposit date in the case file starts the period.
  - 194: 30 days, after which the right lapses; death, stoning, amputation and قصاص go to appeal even without objection.
  - 140: an absent accused is not convicted until he appears.
  - Also read in the same source: 128, 147–153, 161, 162, 181, 182, 199, 210.
- **Implementing regulations (قرار مجلس الوزراء 142 في 21/3/1436هـ), Arts. 139–141.** Informing the parties of the objection right, and finality when no objection is filed unless review is mandatory. This supports «واكتسب الحكم القطعية». Source: https://www.moj.gov.sa/Documents/Regulations/pdf/09.pdf
- **نظام مكافحة المخدرات والمؤثرات العقلية, Art. 41 (text) and Art. 53 (text); Arts. 39, 42, 43 and 60 (alerts).** Source: SFDA booklet «إجراءات وضوابط المواد المخدرة والمؤثرات العقلية» (1441هـ), hosted at https://www.moh.gov.sa/eServices/Licences/Documents/17.pdf
- **نظام مكافحة جريمة التحرش, Art. 1 and Art. 6 (text); Art. 3/1 and Art. 6/2 (alerts).** Source: King Saud University faculty reproduction, https://faculty.ksu.edu.sa/en/salissa/blog/258043. This is a government-university domain, but laws.boe.gov.sa could not be fetched to cross-check.
- **نظام مكافحة جرائم المعلوماتية, Art. 3 (ف2، ف4، ف5), Art. 6 (ف1) and Art. 13 (text); Arts. 14 and 15 (read).** Source: Communications, Space and Technology Commission (CST), https://www.cst.gov.sa/ar/mediacenter/publicationsandbrochures/Documents/PR_PRN_002A.pdf. The Art. 3 penalty is also confirmed by SPA: https://www.spa.gov.sa/520814

**In alerts only:**

- **Lashing (الجلد):** the General Assembly of the Supreme Court set the principle «عدم الحكم بعقوبة الجلد في العقوبات التعزيرية», replaced by imprisonment, a fine, or both (2020). Source: Okaz, 1 May 2020, https://www.okaz.com.sa/news/local/2022129. This is a press report; no official SJC or Supreme Court page was found. No template contains lashing.

## 6. Unverified items (not cited in any generated text)

1. **The article number for the drugs travel ban and deportation.** The SFDA extract places it ambiguously under Art. 56 or 57. The text only says «منعه من السفر… مدة (…)» with no article number, and the judge fills the duration.
2. **The paragraph added to Art. 6 of the harassment law** (publication of the judgment at the convict's expense). The amendment is reported by Al-Watan (https://www.alwatan.com.sa/article/1066248), but neither its wording nor its decree was fetched. «نشر ملخص الحكم» appears only if the judge selects it, with no article number.
3. **Whether any article of نظام الإجراءات الجزائية, especially Art. 140 (absence) or Arts. 192–194, was amended after 1435هـ.** The MOJ copy shows only the original text, and laws.boe.gov.sa was unreachable both through WebFetch (robots.txt) and the shell proxy (403).
4. **Whether any SJC decision makes some minor criminal judgments final** (a criminal equivalent of the civil 50k rule). None was found. The closing always uses 30 days.
5. **نظام الأسلحة والذخائر:** jurisdiction and penalties. The qadha.org.sa PDF was blocked because the permission request timed out.
6. **نظام مكافحة التزوير, نظام الحماية من الإيذاء, نظام الأحداث:** mentioned by name in alerts only, with no article numbers.
7. **«تُحتسب منها مدة إيقافه»:** standard wording. It is the judge's choice (shown only once a prison term is entered) and no article is cited.
