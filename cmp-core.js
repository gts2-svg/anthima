/* cmp-core.js — مقارنة نظامين: المطابقة مادة مادة، والفروق بالكلمة، والتقرير الشامل، والأسئلة.
   ملف مشترك بين تطبيق الآيفون وبرنامج الكمبيوتر؛ لا يعتمد على واجهة أيٍّ منهما. */
(function (G) {
  'use strict';
  const AI = '٠١٢٣٤٥٦٧٨٩';
  const ar = (s) => String(s).replace(/[0-9]/g, (d) => AI[d]);
  const en = (s) => String(s).replace(/[٠-٩]/g, (d) => AI.indexOf(d));
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  function norm(s) { return String(s || '').replace(/[ً-ْٰـ]/g, '').replace(/[أإآٱ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي').replace(/ؤ/g, 'و').replace(/ئ/g, 'ي').replace(/[٠-٩]/g, (d) => AI.indexOf(d)).replace(/[^ء-ي0-9a-z\s/]/gi, ' ').replace(/\s+/g, ' ').trim().toLowerCase(); }
  const STOP = new Set('في من على الى عن او ان ما لا مع هذا هذه ذلك تلك التي الذي الذين كل اي قد ثم بعد قبل عند غير بين حتى اذا وفق وفقا وفي ومن وعلى وان او اما به بها له لها فيه فيها منه منها عليه عليها اليه هو هي هم كان تكون يكون المادة الماده النظام نظام هذا اللايحه'.split(' '));
  const stem = (w) => (w.length > 4 ? w.replace(/^(وال|بال|فال|كال|لل|ال|و)/, '') : w).replace(/(ات|ون|ين|ها|هم)$/, (m, x, i) => (i > 2 ? '' : m));
  const toks = (s) => norm(s).split(' ').filter((w) => w.length > 1 && !STOP.has(w)).map(stem);

  /* ---------- اختيار اللائحة لكل نظام ---------- */
  const baseName = (n) => norm(String(n).replace(/\(.*?\)/g, '').replace(/—.*$/, '')).replace(/^نظام /, '');
  function regOptions(laws, arts, lawId) {
    const L = laws[lawId]; if (!L) return [];
    const out = [];
    if ((arts[lawId] || []).some((a) => a.reg)) out.push({ v: 'attached', name: 'لائحته المرفقة بمواده' });
    const b = baseName(L.name);
    Object.values(laws).forEach((R) => { if (R.id !== lawId && /^اللايحه التنفيذيه/.test(norm(R.name)) && norm(R.name).indexOf('لنظام ' + b) >= 0) out.push({ v: R.id, name: R.name }); });
    return out;
  }
  function defaultReg(laws, arts, lawId) {
    const o = regOptions(laws, arts, lawId); if (!o.length) return '';
    const yr = (s) => (en(String(s)).match(/(1[34]\d\d)/) || [])[1];
    const y = yr(laws[lawId].name);
    const pick = o.find((x) => x.v === 'attached') || o.find((x) => y && Math.abs((+yr(x.name) || 0) - y) <= 2) || (o.length === 1 ? o[0] : null);
    return pick ? pick.v : '';
  }

  /* ---------- وحدات المقارنة ---------- */
  // side: 'o' (القديم) أو 'n' (الجديد)
  function units(laws, arts, side, lawId, regSel) {
    const L = (arts[lawId] || []).filter((a) => a.text);
    const law = L.map((a, i) => ({ side, kind: 'law', lawId, n: String(a.n), ref: (side === 'o' ? 'قديم' : 'جديد') + ' م' + ar(a.n), head: a.heading || '', title: a.title || '', text: a.text, i }));
    let reg = [];
    if (regSel === 'attached') reg = (arts[lawId] || []).filter((a) => a.reg).map((a, i) => ({ side, kind: 'reg', lawId, n: String(a.n), ref: (side === 'o' ? 'قديم' : 'جديد') + ' لائحة م' + ar(a.n), head: 'لائحة المادة ' + ar(a.n), title: '', text: a.reg, attached: true, i }));
    else if (regSel && arts[regSel]) reg = arts[regSel].filter((a) => a.text).map((a, i) => ({ side, kind: 'reg', lawId: regSel, n: String(a.n), ref: (side === 'o' ? 'قديم' : 'جديد') + ' لائحة م' + ar(a.n), head: a.heading || '', title: a.title || '', text: a.text, i }));
    return { law, reg };
  }

  /* ---------- التشابه والمطابقة ---------- */
  function vecs(listA, listB) {
    const all = listA.concat(listB); const df = {};
    const tf = all.map((u) => { const m = {}; toks((u.title ? u.title + ' ' : '') + u.text).forEach((w) => { m[w] = (m[w] || 0) + 1; }); Object.keys(m).forEach((w) => { df[w] = (df[w] || 0) + 1; }); return m; });
    const N = all.length;
    return tf.map((m) => { const v = {}; let s = 0; for (const w in m) { const x = (1 + Math.log(m[w])) * Math.log(1 + N / df[w]); v[w] = x; s += x * x; } s = Math.sqrt(s) || 1; for (const w in v) v[w] /= s; return v; });
  }
  const cos = (a, b) => { let s = 0; const [x, y] = Object.keys(a).length < Object.keys(b).length ? [a, b] : [b, a]; for (const w in x) if (y[w]) s += x[w] * y[w]; return s; };
  function wordRatio(a, b) {
    const A = norm(a).split(' '), B = norm(b).split(' '); if (!A.length || !B.length) return 0;
    const l = lcsLen(A, B); return 2 * l / (A.length + B.length);
  }
  function lcsLen(A, B) { const m = B.length; let prev = new Int32Array(m + 1), cur = new Int32Array(m + 1); for (let i = 1; i <= A.length; i++) { for (let j = 1; j <= m; j++) cur[j] = A[i - 1] === B[j - 1] ? prev[j - 1] + 1 : Math.max(prev[j], cur[j - 1]); [prev, cur] = [cur, prev]; } return prev[m]; }

  // كل مادة قديمة تُنسب إلى أقرب مادة جديدة إليها (في النظام أو اللائحة)، فقد تجتمع في المادة الجديدة عدة مواد قديمة
  const TH = 0.26;
  function match(O, N) {
    const V = vecs(O, N), vo = V.slice(0, O.length), vn = V.slice(O.length);
    const S = O.map((u, i) => vn.map((v) => cos(vo[i], v)));
    // تُقبل أقرب مادة إذا كان تشابهها كافياً، أو ظاهر التميز عن التي تليها
    const to = O.map((u, i) => { let b = -1, bs = 0, s2 = 0; S[i].forEach((s, j) => { if (s > bs) { s2 = bs; bs = s; b = j; } else if (s > s2) s2 = s; }); return (bs >= TH || (bs >= 0.14 && bs >= 1.3 * s2)) ? b : -1; });
    const src = N.map(() => []); to.forEach((j, i) => { if (j >= 0) src[j].push(i); });
    src.forEach((l, j) => l.sort((x, y) => S[y][j] - S[x][j]));
    const rows = N.map((u, j) => {
      const l = src[j];
      if (!l.length) { let b = -1, bs = 0; O.forEach((o, i) => { if (S[i][j] > bs) { bs = S[i][j]; b = i; } }); return { st: 'new', n: u, near: bs >= 0.22 ? O[b] : null }; }
      const os = l.map((i) => O[i]);
      const r = wordRatio(os.map((o) => o.text).join('\n'), u.text);
      return { st: os.length === 1 && r >= 0.97 ? 'same' : 'mod', o: os[0], os, n: u, r, moved: os.some((o) => o.kind !== u.kind) };
    });
    const out = [], after = {}, head = [];
    O.forEach((u, i) => {
      if (to[i] >= 0) return;
      let k = i - 1; while (k >= 0 && to[k] < 0) k--;
      let b = -1, bs = 0; S[i].forEach((x, j) => { if (x > bs) { bs = x; b = j; } });
      const row = { st: 'del', o: u, near: bs >= 0.22 ? N[b] : null };
      if (k < 0) head.push(row); else (after[to[k]] = after[to[k]] || []).push(row);
    });
    out.push(...head);
    rows.forEach((r, j) => { out.push(r); if (after[j]) out.push(...after[j]); });
    return out;
  }
  function compare(laws, arts, cfg) {
    const A = units(laws, arts, 'o', cfg.oLaw, cfg.oReg), B = units(laws, arts, 'n', cfg.nLaw, cfg.nReg);
    const rows = match(A.law.concat(A.reg), B.law.concat(B.reg));
    const scope = (r) => (r.n || r.o).kind;
    const law = rows.filter((r) => scope(r) === 'law'), reg = rows.filter((r) => scope(r) === 'reg');
    const cnt = (rs) => { const c = { mod: 0, del: 0, new: 0, same: 0 }; rs.forEach((r) => c[r.st]++); return c; };
    return { A, B, law, reg, c: { law: cnt(law), reg: cnt(reg), all: cnt(rows) } };
  }

  /* ---------- الصفوف من جدول المطابقة الذي كتبه الذكي ---------- */
  function refKey(str) {
    REF.lastIndex = 0; const m = REF.exec(String(str)); if (!m) return null;
    return (m[1] === 'قديم' ? 'o' : 'n') + '|' + (m[2] ? 'R' : 'L') + '|' + en(m[4]).replace(/\s+/g, '');
  }
  function index(sideUnits) {
    const ix = {}, items = {};
    sideUnits.law.forEach((u) => { ix[(u.side) + '|L|' + en(u.n)] = u; });
    sideUnits.reg.forEach((u) => {
      ix[u.side + '|R|' + en(u.n)] = u;
      if (u.attached) u.text.split('\n').forEach((ln) => { const m = ln.match(/^\s*([٠-٩0-9]+(?:\/[٠-٩0-9]+)+)\s*[-–:]?\s*/); if (m) { const k = u.side + '|R|' + en(m[1]); items[k] = { u, text: ln.slice(m[0].length), ref: (u.side === 'o' ? 'قديم' : 'جديد') + ' لائحة ' + ar(en(m[1])) }; } else { const ks = Object.keys(items); if (ks.length) items[ks[ks.length - 1]].text += '\n' + ln; } });
    });
    return { ix, items };
  }
  function aiRows(cmp, map) {
    if (!map || !map.law) return null;
    const O = index(cmp.A), N = index(cmp.B);
    const look = (k) => { if (!k) return null; if (O.items[k]) return { unit: O.items[k].u, ref: O.items[k].ref, text: O.items[k].text }; const u = O.ix[k]; return u ? { unit: u, ref: u.ref, text: u.text } : null; };
    const oldOrder = cmp.A.law.concat(cmp.A.reg); const pos = new Map(oldOrder.map((u, i) => [u, i]));
    const build = (scope) => {
      const list = cmp.B[scope]; const m = map[scope] || []; const by = {};
      m.forEach((e) => { const k = refKey(e.new); if (k) by[k] = e; });
      if (list.length && Object.keys(by).length < list.length * 0.8) return null;
      const used = new Set();
      const rows = list.map((u) => {
        const e = by[u.side + '|' + (scope === 'law' ? 'L' : 'R') + '|' + en(u.n)];
        if (!e) return { st: 'new', n: u, note: '', miss: true };
        const os = (e.old || []).map((x) => look(refKey(x))).filter(Boolean); os.forEach((o) => used.add(o.unit));
        const st = e.status === 'جديدة' || !os.length ? 'new' : e.status === 'كما هي' ? 'same' : 'mod';
        return { st, n: u, os, note: String(e.note || ''), moved: os.some((o) => o.unit.kind !== u.kind) };
      });
      const rem = (map['removed_' + scope] || []).map((e) => ({ st: 'del', o: look(refKey(e.old)), note: String(e.note || '') })).filter((r) => r.o);
      rem.forEach((r) => used.add(r.o.unit));
      return { rows, rem, used };
    };
    const L = build('law'), R = cmp.B.reg.length ? build('reg') : { rows: [], rem: [], used: new Set() };
    if (!L || !R) return null;
    const place = (res) => {
      const out = [], after = new Map(), head = [];
      const anchor = new Map(); res.rows.forEach((r, j) => (r.os || []).forEach((o) => { const p = pos.get(o.unit); if (!anchor.has(p) || anchor.get(p) > j) anchor.set(p, j); }));
      res.rem.forEach((r) => { let p = pos.get(r.o.unit) - 1; while (p >= 0 && !anchor.has(p)) p--; if (p < 0) head.push(r); else { const j = anchor.get(p); after.set(j, (after.get(j) || []).concat(r)); } });
      out.push(...head); res.rows.forEach((r, j) => { out.push(r); if (after.has(j)) out.push(...after.get(j)); });
      return out;
    };
    const law = place(L), reg = place(R);
    const cnt = (rs) => { const c = { mod: 0, del: 0, new: 0, same: 0 }; rs.forEach((r) => c[r.st]++); return c; };
    return { law, reg, c: { law: cnt(law), reg: cnt(reg), all: cnt(law.concat(reg)) }, ai: true };
  }

  /* ---------- الفروق بالكلمة ---------- */
  function diffHTML(a, b) {
    const ta = String(a).split(/(\s+)/), tb = String(b).split(/(\s+)/);
    const wa = ta.filter((x, i) => i % 2 === 0), wb = tb.filter((x, i) => i % 2 === 0);
    const ka = wa.map((w) => norm(w)), kb = wb.map((w) => norm(w));
    const n = ka.length, m = kb.length;
    const dp = new Array(n + 1); for (let i = 0; i <= n; i++) dp[i] = new Int32Array(m + 1);
    for (let i = n - 1; i >= 0; i--) for (let j = m - 1; j >= 0; j--) dp[i][j] = ka[i] === kb[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    const sepA = (i) => (ta[2 * i + 1] || ''), sepB = (j) => (tb[2 * j + 1] || '');
    const ws = (s) => (/\n/.test(s) ? '\n' : (s ? ' ' : ''));
    let i = 0, j = 0, out = '', del = [], ins = [];
    const flush = () => { if (del.length) out += '<del>' + esc(del.join('')).replace(/\s+$/, '') + '</del> '; if (ins.length) out += '<ins>' + esc(ins.join('')).replace(/\s+$/, '') + '</ins> '; del = []; ins = []; };
    while (i < n || j < m) {
      if (i < n && j < m && ka[i] === kb[j]) { flush(); out += esc(wb[j]) + ws(sepB(j)); i++; j++; }
      else if (j < m && (i >= n || dp[i][j + 1] >= dp[i + 1][j])) { ins.push(wb[j] + ws(sepB(j))); j++; }
      else { del.push(wa[i] + ws(sepA(i))); i++; }
    }
    flush();
    return out.trim();
  }

  /* ---------- نص السياق الذي يقرؤه الذكي ---------- */
  function doc(laws, cfg, cmp) {
    const nm = (id) => (laws[id] || {}).name || '';
    const regName = (lawId, sel) => (sel === 'attached' ? 'لائحته التنفيذية (مرفقة بمواده)' : sel ? nm(sel) : '');
    const part = (title, list, tag) => {
      if (!list.length) return '';
      let s = '\n\n==== ' + title + ' ====\n';
      let lastHead = '';
      list.forEach((u) => {
        if (u.attached) { u.text.split('\n').forEach((ln) => { const m = ln.match(/^\s*([٠-٩0-9]+(?:\/[٠-٩0-9]+)+)\s*[-–:]?\s*/); s += m ? '\n[' + tag + ' لائحة ' + ar(en(m[1])) + '] ' + ln.slice(m[0].length) : ' ' + ln; }); return; }
        s += '\n[' + u.ref + ']' + (u.title ? ' (' + u.title + ')' : '') + ' ' + u.text;
      });
      return s;
    };
    const o = cmp.A, n = cmp.B;
    return 'النظام القديم: ' + nm(cfg.oLaw) + (cfg.oReg ? ' ومعه ' + regName(cfg.oLaw, cfg.oReg) : '') + '\nالنظام الجديد: ' + nm(cfg.nLaw) + (cfg.nReg ? ' ومعه ' + regName(cfg.nLaw, cfg.nReg) : '') +
      '\nكل مادة يسبقها وسمها بين معقوفين، وهو الذي تُذكر به في الجواب.' +
      part('النظام القديم: ' + nm(cfg.oLaw), o.law, 'قديم') + part('اللائحة القديمة', o.reg, 'قديم') +
      part('النظام الجديد: ' + nm(cfg.nLaw), n.law, 'جديد') + part('اللائحة الجديدة', n.reg, 'جديد');
  }

  /* ---------- التقرير ---------- */
  const RULES = 'أنت باحث قانوني متمرس في الأنظمة السعودية، تكتب لقاضٍ مقارنةً بين نظامين (قديم وجديد) ولائحتيهما، والنصوص كاملة مرفقة.\n' +
    'القواعد:\n- اعتمد على النصوص المرفقة وحدها، ولا تضف حكماً أو مادة من خارجها، وإن لم تعالج النصوص مسألةً فقل ذلك صراحة.\n' +
    '- كل نقطة تُسند بوسوم المواد كما هي بين المعقوفين دون المعقوفين، مثل: «قديم م٤٦» و«جديد م٢٠» و«قديم لائحة ٢/٤٦» و«جديد لائحة م١٢». اذكر في كل نقطة مقابلها في الطرف الآخر إن وُجد.\n' +
    '- فرّق بين ما في النظام وما في اللائحة، وإن انتقل حكم من النظام إلى اللائحة أو العكس فنبّه عليه.\n' +
    '- اكتب بعربية فصيحة موجزة دقيقة، بلا مقدمات ولا تكرار، وقدّم الأهم. صف التغيير بدقة: ماذا كان، وماذا صار، وما أثره العملي.\n' +
    '- لا تبالغ في الحكم: إن كان الفرق صياغياً فقل إنه صياغي.';
  const ITEM = { type: 'object', properties: { text: { type: 'string', description: 'النقطة في جملة إلى ثلاث جمل' }, refs: { type: 'array', items: { type: 'string' }, description: 'وسوم المواد المستند إليها في الطرفين، مثل «قديم م٤٦» و«جديد م٢٠»' }, favors: { type: 'string', description: 'لمن يميل هذا الحكم: أحد الطرفين المذكورين في parties، أو «متوازن». يُترك فارغاً في غير قسم الميزان' } }, required: ['text', 'refs'] };
  const SCHEMA = { type: 'object', properties: {
    sections: { type: 'array', items: { type: 'object', properties: { key: { type: 'string' }, title: { type: 'string' }, points: { type: 'array', items: ITEM } }, required: ['key', 'title', 'points'] } },
    themes: { type: 'array', items: { type: 'string' }, description: 'في الطلب الأول فقط: الموضوعات الكبرى التي يعالجها النظامان' },
    parties: { type: 'array', items: { type: 'string' }, description: 'في الطلب الأول فقط: الطرفان اللذان تتوزع بينهما المصالح في هذين النظامين' },
    map: { type: 'array', description: 'في طلب المطابقة فقط', items: { type: 'object', properties: { new: { type: 'string', description: 'وسم المادة الجديدة' }, old: { type: 'array', items: { type: 'string' }, description: 'وسوم ما يقابلها في القديم ولائحته، وقد تكون أكثر من واحدة، وفارغة إن كانت جديدة' }, status: { type: 'string', enum: ['كما هي', 'معدّلة', 'جديدة'] }, note: { type: 'string', description: 'سطر واحد بما تغيّر، أو فارغ إن كانت كما هي' } }, required: ['new', 'old', 'status'] } },
    removed: { type: 'array', description: 'في طلب المطابقة فقط', items: { type: 'object', properties: { old: { type: 'string' }, note: { type: 'string', description: 'سطر واحد: ما الحكم الذي سقط، وهل لسقوطه أثر' } }, required: ['old'] } }
  } };
  const TOOL = { name: 'report', description: 'أعد أقسام المقارنة بهذه الحقول', input_schema: SCHEMA };
  const FIXED = [
    { key: 'summary', title: 'الخلاصة', how: 'الصورة العامة للتغيير في ٦–١٠ نقاط: فلسفة النظام الجديد، وهيكله وعدد مواده وأبوابه مقارنة بالقديم، وما نُقل من النظام إلى اللائحة، وأبرز ثلاثة أو أربعة تحولات.' },
    { key: 'added', title: 'ما استُجد', how: 'كل حكم أو إجراء أو مؤسسة جديدة ليس لها أصل في النظام القديم ولا لائحته. لا تذكر هنا ما هو تعديل لحكم قائم.' },
    { key: 'removed', title: 'ما حُذف', how: 'كل حكم كان في النظام القديم أو لائحته ولم يعد له مقابل في الجديد ولائحته، مع بيان أثر حذفه إن كان له أثر.' },
    { key: 'changed', title: 'أبرز ما تغيّر', how: 'التعديلات الجوهرية على أحكام قائمة في الطرفين: ماذا كان وماذا صار. ما كان صياغياً بحتاً فاجمعه في نقطة واحدة.' },
    { key: 'deadlines', title: 'المدد والمواعيد', how: 'كل مدة أو موعد تغيّر أو استُجد أو أُلغي، بصيغة: القديم ← الجديد.' }
  ];
  const TAIL = [
    { key: 'balance', title: 'ميزان الأطراف', how: 'الأحكام التي تغيّر بها ميزان المصالح بين الطرفين المذكورين في parties: لكل حكم املأ favors بالطرف الذي يميل إليه التغيير أو «متوازن»، واذكر السبب باختصار. من ٨ إلى ١٦ نقطة، ثم نقطة أخيرة بالحكم العام على الاتجاه مع favors.' },
    { key: 'transition', title: 'السريان والأحكام الانتقالية', how: 'متى يُعمل بالجديد، وما يلغيه، وحكم الطلبات والإجراءات القائمة وقت نفاذه، وما أُحيل إلى اللائحة أو إلى قرارات لاحقة.' },
    { key: 'watch', title: 'مسائل ينتبه لها القاضي', how: 'مسائل عملية يحتاج القاضي أن ينتبه لها عند التطبيق: مواضع تغيّر فيها الحكم تغيراً قد يُغفل عنه، أو تعارض ظاهر، أو فراغ لم يعالجه الجديد، أو إحالة إلى لائحة.' }
  ];
  const ask1 = (secs, extra) => 'اكتب الأقسام الآتية من المقارنة، كل قسم بمفتاحه وعنوانه:\n' + secs.map((s) => '- key=' + s.key + ' | ' + s.title + ': ' + s.how).join('\n') + (extra ? '\n' + extra : '');

  // إذا رفض الخادم صيغة الطلب، يُعاد مرة واحدة بصيغة أبسط: بلا حفظ مؤقت للنصوص، وبلا أدوات في الأسئلة
  function safe(call) {
    return async (p) => {
      try { return await call(p); }
      catch (e) {
        const m = String(e && e.message || e);
        if (/مفتاح|رصيد|كثرت|اتصال|429|401/.test(m)) throw e;
        const q = Object.assign({}, p, { system: (Array.isArray(p.system) ? p.system.map((b) => b.text).join('\n\n') : p.system) });
        if (p.tool_choice && p.tool_choice.type === 'none') { delete q.tools; delete q.tool_choice; }
        return await call(q);
      }
    };
  }
  async function report(cfg, ctx, call0, onPart, cmpObj, onProg) {
    const call = safe(call0);
    // التقدم: عدد الأجزاء الكلي والمكتمل، ووقت بدء كل جزء جارٍ ليُحسب منه ما مضى من الجزء
    const P = { total: (cmpObj && (cmpObj.B.reg.length || cmpObj.A.reg.length) ? 2 : 1) + 5, done: 0, run: {}, t0: Date.now() };
    P.durs = [];
    const prog = () => { if (onProg) onProg({ total: P.total, done: P.done, run: Object.values(P.run), t0: P.t0, avg: P.durs.length ? P.durs.reduce((a, b) => a + b, 0) / P.durs.length : 0 }); };
    let jid = 0;
    const system = [{ type: 'text', text: RULES }, { type: 'text', text: ctx, cache_control: { type: 'ephemeral' } }];
    const run = async (prompt, max) => {
      const id = ++jid; P.run[id] = { t: Date.now(), first: id === 1 }; prog();
      try { return await run0(prompt, max); } finally { if (id > 1) P.durs.push((Date.now() - P.run[id].t) / 1000); delete P.run[id]; P.done++; prog(); }
    };
    // Sonnet لا يقبل إلزامه بأداة بعينها، فيُطلب منه استدعاؤها نصاً، ويُقرأ JSON من النص إن كتبه بدلها
    const MUST = '\n\nأعد الجواب باستدعاء الأداة report وحدها، ولا تكتب شيئاً خارجها.';
    const pick = (r) => { if (r && !r.data && r.text) { const m = String(r.text).match(/\{[\s\S]*\}/); if (m) try { r.data = JSON.parse(m[0]); } catch (e) {} } return r; };
    const run0 = async (prompt, max) => {
      let r = pick(await call({ tier: 'strong', system, tools: [TOOL], tool_choice: { type: 'auto' }, messages: [{ role: 'user', content: prompt + MUST }], max: max || 8000 }));
      const ok = (d) => d && ((Array.isArray(d.sections) && d.sections.length) || (Array.isArray(d.map) && d.map.length));
      if (!ok(r.data)) r = pick(await call({ tier: 'strong', system, tools: [TOOL], tool_choice: { type: 'auto' }, messages: [{ role: 'user', content: prompt + MUST }], max: 12000 }));
      if (!ok(r.data)) throw new Error('لم يصل جواب مكتمل لهذا القسم');
      return r.data;
    };
    const first = await run(ask1(FIXED.slice(0, 3), 'واملأ أيضاً themes بالموضوعات الكبرى التي يعالجها النظامان (من ٤ إلى ٩ موضوعات، بعنوان قصير لكل موضوع، مثل: «الاختصاص وصلاحيات القاضي»، «الحجز والإفصاح عن الأموال»)، وparties بالطرفين اللذين تتوزع بينهما المصالح (مثل: الدائن والمدين).'));
    const themes = (Array.isArray(first.themes) ? first.themes : []).map(String).filter(Boolean).slice(0, 9);
    const parties = (Array.isArray(first.parties) && first.parties.length >= 2 ? first.parties.slice(0, 2) : ['الطرف الأول', 'الطرف الثاني']).map(String);
    onPart({ sections: first.sections, themes, parties });
    const jobs = [() => run(ask1(FIXED.slice(3)))];
    for (let i = 0; i < themes.length; i += 3) {
      const grp = themes.slice(i, i + 3).map((t, k) => ({ key: 'theme' + (i + k), title: t, how: 'ما تغيّر في هذا الموضوع بين النظامين ولائحتيهما: المستجد والمحذوف والمعدّل، مع أثره العملي.' }));
      jobs.push(() => run(ask1(grp, 'التزم بالعناوين المعطاة كما هي.')));
    }
    jobs.push(() => run(ask1(TAIL, 'الطرفان (parties): ' + parties.join(' و') + '.')));
    const tags = (list) => list.map((u) => u.ref).join('، ');
    const mapJob = (scope, list, oldDesc) => () => run('مطلوب جدول مطابقة فقط (املأ map وremoved واترك sections فارغة):\n' +
      '١- لكل مادة من هذه المواد الجديدة، بالترتيب ودون إسقاط شيء منها: ' + tags(list) + '\nاذكر ما يقابلها في النظام القديم أو لائحته (بوسومها كما هي، وقد تكون عدة مواد أو فقرات)، وحالتها: «كما هي» إن لم يتغير حكمها ولو تغيرت صياغتها يسيراً، أو «معدّلة»، أو «جديدة» إن لم يكن لها أصل. وفي note سطر واحد دقيق بما تغيّر.\n' +
      '٢- ثم اذكر في removed كل ' + oldDesc + ' لم يعد لحكمها مقابل في الجديد ولائحته، مع سطر بما سقط.', 12000).then((d) => ({ map: { [scope]: d.map || [], ['removed_' + scope]: d.removed || [] } }));
    if (cmpObj) {
      jobs.splice(1, 0, mapJob('law', cmpObj.B.law, 'مادة من النظام القديم (لا اللائحة)'));
      if (cmpObj.B.reg.length || cmpObj.A.reg.length) jobs.splice(2, 0, mapJob('reg', cmpObj.B.reg, 'فقرة من اللائحة القديمة'));
    }
    P.total = 1 + jobs.length; prog();
    const errs = [];
    let k = 0;
    const worker = async () => { while (k < jobs.length) { const j = jobs[k++]; try { onPart(await j()); } catch (e) { errs.push(e.message || String(e)); } } };
    await Promise.all([worker(), worker(), worker()]);
    return { themes, parties, errs };
  }
  function order(rep) {
    const keys = FIXED.map((s) => s.key).concat((rep.themes || []).map((t, i) => 'theme' + i), TAIL.map((s) => s.key));
    const by = {}; (rep.sections || []).forEach((s) => { by[s.key] = s; });
    return keys.map((k) => by[k]).filter(Boolean).concat((rep.sections || []).filter((s) => keys.indexOf(s.key) < 0));
  }
  function mergeSections(rep, part) {
    if (part.map) { rep.map = Object.assign(rep.map || {}, part.map); return; }
    rep.sections = (rep.sections || []).filter((s) => !(part.sections || []).some((p) => p.key === s.key)).concat(part.sections || []);
    if (part.themes) rep.themes = part.themes; if (part.parties) rep.parties = part.parties;
  }
  async function ask(ctx, history, q, call0) {
    const call = safe(call0);
    const system = [{ type: 'text', text: RULES + '\n- أنت الآن تجيب عن سؤال القاضي عن الفروق بين النظامين. ابدأ بالجواب مباشرة، واذكر وسوم المواد بين معقوفين داخل الكلام، مثل [قديم م٤٦] و[جديد م٢٠]. إن كان السؤال عن أحد النظامين فقط فأجب منه، واذكر مقابله في الآخر.' }, { type: 'text', text: ctx, cache_control: { type: 'ephemeral' } }];
    const messages = [];
    history.slice(-4).forEach((h) => { if (h.q && h.a) { messages.push({ role: 'user', content: h.q }); messages.push({ role: 'assistant', content: h.a }); } });
    messages.push({ role: 'user', content: q });
    const r = await call({ tier: 'strong', system, tools: [TOOL], tool_choice: { type: 'none' }, messages, max: 3000 });
    const t = String(r.text || '').trim(); if (!t) throw new Error('لم يصل جواب');
    return t;
  }

  /* ---------- الوسوم إلى روابط ---------- */
  const REF = /\[?(قديم|جديد)\s+(لائحة\s+)?(م\s*)?([0-9٠-٩]+(?:\s*\/\s*[0-9٠-٩]+)*)\]?/g;
  function resolve(cfg, side, isReg, hasM, num) {
    const law = side === 'قديم' ? cfg.oLaw : cfg.nLaw, reg = side === 'قديم' ? cfg.oReg : cfg.nReg;
    const parts = en(num).split('/').map((x) => x.trim());
    if (!isReg) return { lawId: law, n: parts[0] };
    if (parts.length > 1) return { lawId: law, n: parts[parts.length - 1], reg: true };
    if (reg === 'attached' || !reg) return { lawId: law, n: parts[0], reg: true };
    return { lawId: reg, n: parts[0] };
  }
  function refsHTML(text, cfg) {
    let out = '', last = 0; const s = String(text); REF.lastIndex = 0; let m;
    while ((m = REF.exec(s))) {
      out += esc(s.slice(last, m.index)); last = m.index + m[0].length;
      const t = resolve(cfg, m[1], !!m[2], !!m[3], m[4]);
      const lab = m[1] + ' ' + (m[2] ? 'لائحة ' : '') + (m[3] || (!m[2] ? 'م' : '')) + ar(en(m[4]).replace(/\s+/g, ''));
      out += '<button class="cref ' + (m[1] === 'قديم' ? 'o' : 'n') + '" data-cref="' + esc(t.lawId + '|' + t.n) + '">' + esc(lab.replace(/\s+/g, ' ')) + '</button>';
    }
    return out + esc(s.slice(last));
  }
  // النسبة: الأجزاء المكتملة، وما مضى من الأجزاء الجارية مقدَّراً بزمنها المعتاد (لا يتجاوز ٩٠٪ من الجزء قبل اكتماله)
  // النسبة: الأجزاء المكتملة، وما مضى من الأجزاء الجارية؛ يتباطأ تقدم الجزء كلما طال ولا يقف
  const EXP = (r, pg) => (r.first ? 150 : (pg.avg || 110));
  function percent(pg) {
    if (!pg) return 0; const now = Date.now();
    const part = (pg.run || []).reduce((a, r) => a + Math.min(0.95, 1 - Math.exp(-(now - r.t) / 1000 / EXP(r, pg))), 0);
    return Math.max(1, Math.min(99, Math.round(100 * (pg.done + part) / Math.max(1, pg.total))));
  }
  // الوقت الباقي: ما بقي من الأجزاء الجارية، ثم الأجزاء المنتظرة على دفعات من ثلاثة
  function remaining(pg) {
    if (!pg) return ''; const now = Date.now(); const T = pg.avg || 110;
    const run = pg.run || []; const left = Math.max(0, pg.total - pg.done - run.length);
    let s;
    const first = run.find((r) => r.first);
    if (first) { const el = (now - first.t) / 1000; s = Math.max(20, Math.max(150, el * 1.15) - el) + Math.ceil(left / 3) * T; }
    else { const cur = run.reduce((m, r) => Math.max(m, Math.max(15, T * 1.1 - (now - r.t) / 1000)), 0); s = cur + Math.ceil(Math.max(0, left - Math.max(0, 3 - run.length)) / 3) * T + (run.length ? 0 : (left ? T : 0)); }
    const m = Math.round(s / 60);
    return s < 60 ? 'أقل من دقيقة' : m <= 1 ? 'نحو دقيقة' : m === 2 ? 'نحو دقيقتين' : 'نحو ' + ar(m) + (m <= 10 ? ' دقائق' : ' دقيقة');
  }
  function estimate(ctx) { const tok = ctx.length / 2.4; return { tok: Math.round(tok), usd: (tok * 6e-6 + 8 * tok * 0.3e-6 + 9 * 5000 * 15e-6) }; }
  function key(cfg) { return [cfg.oLaw, cfg.oReg || '-', cfg.nLaw, cfg.nReg || '-'].join('|'); }

  G.CMP = { percent, remaining, aiRows, norm, ar, en, esc, regOptions, defaultReg, compare, diffHTML, doc, report, order, mergeSections, ask, refsHTML, estimate, key };
})(typeof window !== 'undefined' ? window : globalThis);
