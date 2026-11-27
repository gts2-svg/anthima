# New civil (حقوقي) types for مولّد التسبيب

Files:
- `huquqi_types.js` holds the new types. Paste it into `engine.js` just before `T.ahwal = {`.
- `huquqi_test.js` runs the tests. It builds `/tmp/engine_merged.js` and writes copies of the old tests to `specs/regress/`.

Test result: **148 passed, 0 failed**.
- Each new type has its own sample minutes. The RENT and DAMAGE samples use Arabic-Indic digits.
- 25 old cases give exactly the same output on the old engine and the merged one: same type, category, confidence, text, alerts and fields. They include the test.js cases, the traffic minutes and the sale2 minutes.
- `engine_test.js`, `traffic_test.js`, `traffic_test2.js` and `sale2.js` were run on the merged engine. Their output is byte-for-byte the same as on the old engine.

## Types added (all `cat:'huquqi'`, built on the `price`/`traffic` pattern)

| key | name | why it was added |
|---|---|---|
| `rent` | مطالبة بأجرة متأخرة (دون إخلاء) | Claims for unpaid rent after the tenant has left are very common. Today the engine sends them to `lease`. It then orders eviction from a unit that is already empty, and never treats the case as final, even at 50,000 or less, because `lease` has no `money`. The new type is purely monetary, so the finality rule works. |
| `refund` | فسخ عقد واسترداد ما دُفع | A buyer pays and nothing is delivered, or a client pays and the work is never done. `defect` needs an عيب, and `contract` is the opposite side (the contractor suing for his price). If the contract is already cancelled, choose «رد المبلغ فقط»: the case is then purely monetary and counts as yasira. |
| `mistaken` | رد مبلغ محوّل بالخطأ | Bank transfers sent by mistake. This is a very frequent claim, and no existing type covers دفع غير المستحق. |
| `damage` | تعويض عن ضرر بالممتلكات (غير مروري) | Water leaks, demolition, fire, damage to a neighbour's property. Real-estate damage is named in م31/أ. Traffic and personal injury are blocked by negative keyword weights. |
| `wadia` | رد وديعة أو أمانة | Claims to get back money or things left with someone for safekeeping. The CTL deposit chapter (م506 onward) gives a direct legal basis. |

On classification:
- Negative keyword weights keep the new types away from the old ones: eviction requests count against `rent`; عيب, قرض, transfer «بالخطأ» and traffic words count against `refund`; traffic and injury words count against `damage`; قرض counts against `mistaken` and `wadia`.
- New types are inserted after the old ones, so an old type still wins a tie.
- Every case that failed in the reasoning returns to the normal flow: «رد الدعوى» (`outcome`), wafa, agentDef, absN with a notice number, absX in the first session (postponement) and in a later one, and the single-judge voice (soloVoice).
- For the judge only (not in the generated text):
  - Checklist alerts on the relevant CTL articles.
  - The 100k writing rule for `refund` and `wadia`, which the engine's `proneTypes` list does not include.
  - A note when an Ejar-registered contract is involved.
  - A warning when the minutes contain more than one request.
  - Arithmetic and size mismatches: expert estimate vs. amount claimed, refund larger than the price, rent larger than three years' rent.

## Types excluded

- **إخلاء لانتهاء المدة**: already handled by `lease` (sabab = انتهاء مدة العقد).
- **إلزام بالإفراغ / إثبات تملك عقار مبيع**: already handled by `ownRE`, whose ruling includes إلزام بالإفراغ.
- **منع تعرض**: `possession` already exists.
- **صحة توقيع / إثبات عقد as a claim on its own**: rare, and usually a step inside another claim. Not added.
- **Cheques and promissory notes (الأوراق التجارية)**:
  - They are executory instruments (نظام التنفيذ م9/4), so they go straight to the enforcement court.
  - Claims under commercial laws go to the commercial court (نظام المحاكم التجارية م16/7).
  - If the plaintiff sues on the underlying debt instead, the case is a loan or sale-price claim, which `loan`/`price` already cover.
- **مطالبة شريك بحصته**:
  - Disputes between partners in a mudaraba or under the Companies Law belong to the commercial court (م16/3 and م16/4).
  - Partners sharing one property (شيوع) are covered by `qisma`.
- **الوقف، الوصية، الإرث وقسمة التركة**:
  - These belong to the personal-status courts (مرافعات م33), as the MoJ page lists them.
  - This includes قسمة التركة, even with real estate, when there is a dispute, a waqf share, a will, a minor or an absent heir.
- **Labour and administrative claims**: labour courts (مرافعات م34) and ديوان المظالم. The `damage` alert also points out that a claim against a government body goes to ديوان المظالم.

## Articles cited in the generated text, with sources

All articles below are from نظام المعاملات المدنية unless marked otherwise.

**م31/أ نظام المرافعات الشرعية** (used in `rent`, and in `damage` when the damage comes from a property)
- Covers real-estate claims, including «دعاوى الضرر والإخلاء ودفع الأجرة ومنع التعرض للحيازة».
- Source: MoJ page on the general courts: https://www.moj.gov.sa/ar/Ministry/Courts/pages/firstcourts.aspx
- Item structure confirmed in the MoJ implementing regulations PDF: https://www.moj.gov.sa/Documents/Regulations/pdf/75.4.pdf

**م429** (`rent`)
- Quoted text: «يلتزم المستأجر بأن يؤدي الأجرة في المواعيد المتفق عليها».
- The article also says no rent is due for a period before handover. This appears in an alert.
- Sources:
  - Published text, الجمعية العلمية القضائية: https://qadha.org.sa/files/shares/نظام المعاملات المدنية مع الفهارس.pdf
  - Second source: https://nezams.com/نظام-المعاملات-المدنية/

**م107** (`refund`, paraphrased, not quoted)
- In two-sided contracts, if one party does not perform, the other may ask for rescission (after a formal notice).
- Sources: qadha.org.sa and nezams.com.

**م111** (`refund`)
- Quoted text: «في حالتي فسخ العقد أو انفساخه يعود المتعاقدان إلى الحالة التي كانا عليها قبل التعاقد».
- Sources: qadha.org.sa and nezams.com.

**م145** (`mistaken`)
- Quoted text: «كل من تسلَّم على سبيل الوفاء ما ليس مستحقّاً له وجب عليه ردُّه».
- The exception (the payer knew he owed nothing) appears in an alert.
- Sources: nezams.com (wording) and qadha.org.sa (content).

**م120** (`damage`)
- Same quote the engine already uses for traffic. Already verified.

**م136** (`damage`)
- Quoted text: «يكون التعويض بما يجبر الضرر كاملاً».
- Sources: qadha.org.sa and nezams.com.

**م506** (`wadia`, paraphrased)
- الإيداع عقد يحفظ بمقتضاه المودع لديه مال المودع على أن يرده بعينه.
- Sources: qadha.org.sa and nezams.com.

**م515** (`wadia`, paraphrased)
- In an unpaid deposit, the depositor may take the deposit back.
- Sources: qadha.org.sa and nezams.com.

**Already verified, reused through existing helpers**: مرافعات م57 and م185/4, the 50,000 finality rule (قرار 41/19/2), and نظام الإثبات م66 and م68.

**Cited in judge-only alerts only**: م137 and م143 (3 years / 10 years), م159 (3 years / 10 years).
- Each was confirmed on qadha.org.sa, and م137 and م159 also on nezams.com.
- م143: opening words and both periods confirmed on qadha.org.sa; nezams.com confirmed only the article number and opening words.

**Cited only in this report**:
- نظام المحاكم التجارية م16: from the text published by الاقتصادية: https://www.aleqt.com/2020/04/17/article_1807586.html
- نظام التنفيذ م9/4 (الأوراق التجارية): secondary source only: https://www.mohamah.net/law/?p=49622

## Unverified or not cited

- **م435** (tenant returns the property; أجرة المثل when he stays without right): the two sources disagree on whether it is م435 or م436. **Not cited.**
- **Seller's duty to deliver** (nezams.com says م321): one source only. **Not cited**; `refund` uses م107 and م111 instead.
- **Depositary's duty of care and when he is liable for loss** (nezams.com says م509): one source only. The `wadia` alert mentions the rule (تعدٍّ أو تقصير) **without an article number**. The same goes for «a cash deposit becomes a loan if its use was allowed».
- **Ejar-registered contract as an executory instrument**: no article number found, so the alert has no number. The existing `lease` alert does the same.
- **Formal notice (إعذار) under م107**: whether filing the lawsuit counts as notice is not verified. It is a checklist question in the alert, not a statement in the text.
- **Could not open the official BOE site or the WIPO PDF**: laws.boe.gov.sa was blocked by the network proxy, and the WIPO PDF (https://wipolex-res.wipo.int/edocs/lexdocs/laws/ar/sa/sa110ar_1.pdf) was refused at the permission step.
  - The CTL texts were therefore checked against two published copies: the Saudi judicial association (qadha.org.sa) and nezams.com.
  - **Recommendation: compare م429, م111, م145, م136, م506 and م515 with laws.boe.gov.sa before release.**
- **The fetch tool gave only short exact quotes**, not full article texts. So the generated text quotes only the opening phrase of each article («التي جاء فيها: …»); م107, م506 and م515 are paraphrased. Only م120 uses «ونصها», as before.
