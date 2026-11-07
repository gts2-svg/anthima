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
      if (list.length && Object.keys(by).length < list.length * 0.3) return null;
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

  /* ---------- التقرير ----------
     كل قسم في طلب مستقل، والرد نص عادي بعناوين ونقاط يُقرأ وهو يُكتب؛ فإن انقطع حُفظ ما كُتب. */
  const RULES = 'أنت باحث قانوني متمرس في الأنظمة السعودية، تكتب لقاضٍ مقارنةً بين نظامين (قديم وجديد) ولائحتيهما، والنصوص كاملة مرفقة.\n' +
    'القواعد:\n- اعتمد على النصوص المرفقة وحدها، ولا تضف حكماً أو مادة من خارجها، وإن لم تعالج النصوص مسألةً فقل ذلك صراحة.\n' +
    '- اذكر وسوم المواد بين معقوفين كما هي في النصوص، مثل [قديم م٤٦] و[جديد م٢٠] و[قديم لائحة ٢/٤٦] و[جديد لائحة م١٢]، واذكر في كل نقطة مقابلها في الطرف الآخر إن وُجد.\n' +
    '- فرّق بين ما في النظام وما في اللائحة، وإن انتقل حكم من النظام إلى اللائحة أو العكس فنبّه عليه.\n' +
    '- اكتب بعربية فصيحة موجزة دقيقة، بلا مقدمات ولا تكرار، وقدّم الأهم. صف التغيير بدقة: ماذا كان، وماذا صار، وما أثره العملي.\n' +
    '- لا تبالغ في الحكم: إن كان الفرق صياغياً فقل إنه صياغي.';
  const FMT = (title, extra) => '\n\nاكتب القسم بهذا الشكل حرفياً، بلا مقدمة ولا خاتمة ولا تنسيق آخر:\n## ' + title + '\n- نقطة\n- نقطة\nكل نقطة في سطر واحد يبدأ بشرطة، وفيها وسوم المواد بين معقوفين.' + (extra || '');
  const FIXED = [
    { key: 'summary', title: 'الخلاصة', how: 'الصورة العامة للتغيير في ٦–١٠ نقاط: فلسفة النظام الجديد، وهيكله وعدد مواده وأبوابه مقارنة بالقديم، وما نُقل من النظام إلى اللائحة، وأبرز التحولات.', w: 2600 },
    { key: 'added', title: 'ما استُجد', how: 'كل حكم أو إجراء أو مؤسسة جديدة ليس لها أصل في النظام القديم ولا لائحته. لا تذكر هنا ما هو تعديل لحكم قائم.', w: 4500 },
    { key: 'removed', title: 'ما حُذف', how: 'كل حكم كان في النظام القديم أو لائحته ولم يعد له مقابل في الجديد ولائحته، مع بيان أثر حذفه إن كان له أثر.', w: 3800 },
    { key: 'changed', title: 'أبرز ما تغيّر', how: 'التعديلات الجوهرية على أحكام قائمة في الطرفين: ماذا كان وماذا صار. ما كان صياغياً بحتاً فاجمعه في نقطة واحدة.', w: 4500 },
    { key: 'deadlines', title: 'المدد والمواعيد', how: 'كل مدة أو موعد تغيّر أو استُجد أو أُلغي، بصيغة: القديم ← الجديد.', w: 2800 }
  ];
  const TAIL = [
    { key: 'balance', title: 'ميزان الأطراف', how: '', w: 3600 },
    { key: 'transition', title: 'السريان والأحكام الانتقالية', how: 'متى يُعمل بالجديد، وما يلغيه، وحكم الطلبات والإجراءات القائمة وقت نفاذه، وما أُحيل إلى اللائحة أو إلى قرارات لاحقة.', w: 2200 },
    { key: 'watch', title: 'مسائل ينتبه لها القاضي', how: 'مسائل عملية يحتاج القاضي أن ينتبه لها عند التطبيق: مواضع تغيّر فيها الحكم تغيراً قد يُغفل عنه، أو تعارض ظاهر، أو فراغ لم يعالجه الجديد، أو إحالة إلى لائحة.', w: 2800 }
  ];
  function specs(rep, cmp) {
    const par = rep.parties || ['الطرف الأول', 'الطرف الثاني'];
    const out = FIXED.map((s) => Object.assign({ kind: 'sec' }, s));
    (rep.themes || []).forEach((t, i) => out.push({ kind: 'sec', key: 'theme' + i, title: t, how: 'ما تغيّر في هذا الموضوع بين النظامين ولائحتيهما: المستجد والمحذوف والمعدّل، مع أثره العملي.', w: 3200 }));
    TAIL.forEach((s) => out.push(Object.assign({ kind: 'sec' }, s, s.key === 'balance' ? { how: 'الأحكام التي تغيّر بها ميزان المصالح بين ' + par[0] + ' و' + par[1] + ': من ٨ إلى ١٦ نقطة، تبدأ كل نقطة بأحد الوسوم [لصالح ' + par[0] + '] أو [لصالح ' + par[1] + '] أو [متوازن]، ثم الحكم وسببه باختصار. واجعل آخر نقطة الحكم العام على اتجاه النظام الجديد بوسمها.' } : {})));
    if (cmp) {
      const chunk = (list, scope) => { for (let i = 0; i < list.length; i += 30) { const part = list.slice(i, i + 30); out.push({ kind: 'map', scope, key: 'map_' + scope + '_' + (i / 30), title: 'مطابقة ' + (scope === 'law' ? 'مواد النظام' : 'مواد اللائحة') + ' ' + ar(i / 30 + 1), refs: part.map((u) => u.ref), w: part.length * 120 }); } };
      chunk(cmp.B.law, 'law'); chunk(cmp.B.reg, 'reg');
      out.push({ kind: 'removed', key: 'map_removed', title: 'المواد التي لا مقابل لها', w: 3000 });
    }
    return out;
  }
  function prompt(sp) {
    if (sp.kind === 'sec') return 'اكتب القسم الآتي من المقارنة: «' + sp.title + '»: ' + sp.how + FMT(sp.title);
    if (sp.kind === 'map') return 'لكل مادة من المواد الجديدة الآتية، بالترتيب ودون إسقاط شيء منها: ' + sp.refs.join('، ') +
      '\nاكتب سطراً واحداً بهذا الشكل حرفياً، بلا مقدمة ولا خاتمة:\nجديد م٧ | قديم م٩، قديم لائحة ٢/٩ | معدّلة | ما تغيّر في سطر واحد\n' +
      'الخانة الثانية: ما يقابلها في النظام القديم أو لائحته بوسومه (وقد تكون عدة مواد أو فقرات)، أو «لا يوجد». الخانة الثالثة واحدة من: كما هي، معدّلة، جديدة. «كما هي» إن لم يتغير حكمها ولو تغيرت صياغتها يسيراً.';
    return 'اذكر كل مادة من النظام القديم وكل فقرة من لائحته لم يعد لحكمها مقابل في النظام الجديد ولائحته، كل واحدة في سطر بهذا الشكل حرفياً، بلا مقدمة ولا خاتمة:\nقديم م٩٠ | ما الحكم الذي سقط، وهل لسقوطه أثر\nقديم لائحة ٢/٥ | …';
  }
  // قراءة النص: قسم بعنوان ونقاط
  function parseSec(text, parties) {
    const pts = []; let title = '';
    String(text || '').replace(/\r/g, '').split('\n').forEach((ln) => {
      const l = ln.trim(); if (!l) return;
      if (/^#{1,4}\s*/.test(l)) { if (!title) title = l.replace(/^#+\s*/, ''); return; }
      const m = l.match(/^([-•*–]|[0-9٠-٩]+[.)-])\s*/);
      if (m || !pts.length) pts.push({ text: l.slice(m ? m[0].length : 0) }); else pts[pts.length - 1].text += ' ' + l;
    });
    pts.forEach((p) => { const f = p.text.match(/^\[(لصالح\s+([^\]]+)|متوازن)\]\s*/); if (f) { p.favors = f[2] ? f[2].trim() : 'متوازن'; p.text = p.text.slice(f[0].length); } p.text = p.text.replace(/\*\*/g, ''); });
    return { title, points: pts.filter((p) => p.text) };
  }
  function parseMap(text) {
    const out = [];
    String(text || '').split('\n').forEach((ln) => {
      const c = ln.replace(/^[-•*\s]+/, '').split('|').map((x) => x.trim()); if (c.length < 3) return;
      const st = /جديد/.test(c[2]) ? 'جديدة' : /كما/.test(c[2]) ? 'كما هي' : 'معدّلة';
      out.push({ new: c[0], old: /لا يوجد|^-?$/.test(c[1]) ? [] : c[1].split(/[،,؛]/).map((x) => x.trim()).filter(Boolean), status: st, note: c.slice(3).join(' | ') });
    });
    return out;
  }
  function parseRemoved(text) {
    const out = [];
    String(text || '').split('\n').forEach((ln) => { const c = ln.replace(/^[-•*\s]+/, '').split('|').map((x) => x.trim()); if (c.length >= 2 && /قديم/.test(c[0])) out.push({ old: c[0], note: c.slice(1).join(' | ') }); });
    return out;
  }
  // يبني جدول المطابقة من أجزائه المكتوبة
  function mapOf(rep) {
    const m = { law: [], reg: [], removed_law: [], removed_reg: [] }; let any = false;
    (rep.specs || []).forEach((sp) => {
      const s = rep.secs && rep.secs[sp.key]; if (!s || !s.text) return;
      if (sp.kind === 'map') { m[sp.scope] = m[sp.scope].concat(parseMap(s.text)); any = true; }
      if (sp.kind === 'removed') parseRemoved(s.text).forEach((r) => { (/لائحة/.test(r.old) ? m.removed_reg : m.removed_law).push(r); });
    });
    return any ? m : null;
  }
  function sysOf(ctx) { return [{ type: 'text', text: RULES }, { type: 'text', text: ctx, cache_control: { type: 'ephemeral' } }]; }
  // call({tier, system, messages, max, onText}) => {text, stop, usage}
  // Sonnet 5.5 يفكر قبل الكتابة افتراضياً، والتفكير يُحسب من حد الطول؛ فالأقسام التحليلية بتفكير متوسط وحد واسع،
  // وجداول المطابقة بلا تفكير مسبق. وانقطاع الاتصال يُعاد معه الجزء حتى مرتين.
  const MODE = { sec: { max: 32000, thinking: { type: 'adaptive', display: 'summarized' }, effort: 'medium' }, map: { max: 16000, thinking: { type: 'between_tools' }, effort: 'medium' } };
  const NETERR = /load failed|failed to fetch|network|net::|انقطع|overloaded|\b(500|502|503|504|529)\b|تعذر الاتصال|ECONN|socket|timeout/i;
  async function runSpec(rep, sp, ctx, call, onUpdate) {
    const md = sp.kind === 'sec' || sp.kind === 'plan' ? MODE.sec : MODE.map;
    let s;
    for (let attempt = 0; attempt < 3; attempt++) {
      s = rep.secs[sp.key] = { text: '', think: 0, state: 'run', t: Date.now(), tries: attempt + 1 };
      try {
        const r = await call(Object.assign({ tier: 'strong', system: sysOf(ctx), messages: [{ role: 'user', content: prompt(sp) }], onText: (t) => { s.text = t; onUpdate(); }, onThink: (n) => { s.think = n; onUpdate(); } }, md));
        s.text = r.text || s.text; s.stop = r.stop || '';
        s.state = !String(s.text).trim() ? 'err' : (r.stop === 'max_tokens' ? 'cut' : 'ok');
        if (s.state === 'err') s.err = 'وصل رد فارغ' + (r.stop ? ' (' + r.stop + ')' : '');
      } catch (e) { s.state = 'err'; s.err = String(e && e.message || e); }
      if (s.state === 'err' && NETERR.test(s.err) && attempt < 2) { onUpdate(true); await new Promise((r) => setTimeout(r, 3000 * (attempt + 1))); continue; }
      break;
    }
    s.dur = (Date.now() - s.t) / 1000; delete s.t; onUpdate(true);
    return s;
  }
  async function report(rep, ctx, call, cmp, onUpdate, conc) {
    rep.secs = rep.secs || {}; rep.t0 = Date.now();
    // ١) خطة قصيرة: الموضوعات والطرفان (ويُحفظ معها نص النظامين عند الخادم للطلبات التالية)
    rep.specs = [{ kind: 'plan', key: 'plan', title: 'قراءة النظامين', w: 3500 }];
    onUpdate(true);
    let ps;
    for (let attempt = 0; ; attempt++) {
    ps = rep.secs.plan = { text: '', state: 'run', t: Date.now(), tries: attempt + 1 };
    try {
      const r = await call({ tier: 'strong', thinking: MODE.map.thinking, effort: 'medium', system: sysOf(ctx), messages: [{ role: 'user', content: 'اكتب سطرين فقط بهذا الشكل حرفياً:\nالموضوعات: موضوع؛ موضوع؛ موضوع\nالطرفان: الأول؛ الثاني\nالموضوعات هي الموضوعات الكبرى التي يعالجها النظامان (من ٤ إلى ٨، بعنوان قصير لكل موضوع، مثل: الاختصاص وصلاحيات القاضي؛ الحجز والإفصاح عن الأموال). والطرفان هما من تتوزع بينهما المصالح في النظامين (مثل: الدائن؛ المدين).' }], max: 4000, onText: (t) => { ps.text = t; onUpdate(); } });
      ps.text = r.text || ps.text; ps.state = 'ok'; break;
    } catch (e) { const m = String(e && e.message || e); if (NETERR.test(m) && attempt < 2) { await new Promise((r) => setTimeout(r, 3000 * (attempt + 1))); continue; } ps.state = 'err'; ps.err = m; delete ps.t; onUpdate(true); throw e; }
    }
    delete ps.t;
    const line = (k) => ((ps.text.match(new RegExp(k + '\\s*[:：]\\s*(.+)')) || [])[1] || '').split(/[؛;،,]/).map((x) => x.replace(/[*.]/g, '').trim()).filter(Boolean);
    rep.themes = line('الموضوعات').slice(0, 8); const pr = line('الطرفان'); rep.parties = pr.length >= 2 ? pr.slice(0, 2) : ['الطرف الأول', 'الطرف الثاني'];
    rep.specs = rep.specs.concat(specs(rep, cmp)); onUpdate(true);
    // ٢) بقية الأقسام، عدة أجزاء في وقت واحد
    await runAll(rep, rep.specs.filter((sp) => sp.kind !== 'plan'), ctx, call, onUpdate, conc);
  }
  async function runAll(rep, todo, ctx, call, onUpdate, conc) {
    let k = 0;
    const worker = async () => { while (k < todo.length) { const sp = todo[k++]; await runSpec(rep, sp, ctx, call, onUpdate); } };
    await Promise.all(Array.from({ length: Math.max(1, conc || 3) }, worker));
    rep.map = mapOf(rep);
  }
  // يكمل الأجزاء الناقصة وحدها: المتعذرة والمنقطعة وما لم يبدأ
  async function resume(rep, ctx, call, cmp, onUpdate, conc) {
    rep.t0 = Date.now();
    const todo = (rep.specs || []).filter((sp) => sp.kind !== 'plan' && (!rep.secs[sp.key] || rep.secs[sp.key].state !== 'ok'));
    todo.forEach((sp) => { delete rep.secs[sp.key]; });
    await runAll(rep, todo, ctx, call, onUpdate, conc);
  }
  const missing = (rep) => (rep && rep.specs ? rep.specs.filter((sp) => sp.kind !== 'plan' && (!rep.secs[sp.key] || /err|cut/.test(rep.secs[sp.key].state))).length : 0);
  async function retry(rep, key, ctx, call, cmp, onUpdate) {
    const sp = (rep.specs || []).find((x) => x.key === key); if (!sp) return;
    await runSpec(rep, sp, ctx, call, onUpdate); rep.map = mapOf(rep);
  }
  // تجربة سريعة: نص صغير من أول المواد، وقسم قصير؛ تكلفتها أقل من سنت
  async function quickTest(laws, arts, cfg, call) {
    const pick = (id) => (arts[id] || []).slice(0, 4).map((a) => a.text.slice(0, 500));
    const ctx = 'النظام القديم: ' + (laws[cfg.oLaw] || {}).name + '\n' + pick(cfg.oLaw).map((t, i) => '[قديم م' + ar(i + 1) + '] ' + t).join('\n') + '\n\nالنظام الجديد: ' + (laws[cfg.nLaw] || {}).name + '\n' + pick(cfg.nLaw).map((t, i) => '[جديد م' + ar(i + 1) + '] ' + t).join('\n');
    const t0 = Date.now(); let chunks = 0;
    const r = await call({ tier: 'strong', system: RULES, messages: [{ role: 'user', content: 'هذه أول أربع مواد من كل نظام:\n' + ctx + '\n\nاكتب القسم الآتي: «الخلاصة» في ثلاث نقاط قصيرة فقط.' + FMT('الخلاصة') }], max: 6000, thinking: MODE.map.thinking, effort: 'medium', onText: () => { chunks++; } });
    const sec = parseSec(r.text);
    return { ok: sec.points.length > 0, secs: (Date.now() - t0) / 1000, streamed: chunks > 1, stop: r.stop, points: sec.points.length, sample: sec.points[0] ? sec.points[0].text : String(r.text || '').slice(0, 200) };
  }
  // الأقسام المكتوبة بترتيبها، للعرض
  function sections(rep) {
    return (rep.specs || []).filter((sp) => sp.kind === 'sec').map((sp) => { const s = (rep.secs || {})[sp.key] || {}; const p = parseSec(s.text); return { key: sp.key, title: sp.title, points: p.points, state: s.state || 'wait', err: s.err || '', thinking: s.state === 'run' && !s.text, tries: s.tries || 1 }; });
  }
  async function ask(ctx, history, q, call, onText) {
    const system = [{ type: 'text', text: RULES + '\n- أنت الآن تجيب عن سؤال القاضي عن الفروق بين النظامين. ابدأ بالجواب مباشرة، واذكر وسوم المواد بين معقوفين داخل الكلام. إن كان السؤال عن أحد النظامين فقط فأجب منه، واذكر مقابله في الآخر.' }, { type: 'text', text: ctx, cache_control: { type: 'ephemeral' } }];
    const messages = [];
    history.slice(-4).forEach((h) => { if (h.q && h.a) { messages.push({ role: 'user', content: h.q }); messages.push({ role: 'assistant', content: h.a }); } });
    messages.push({ role: 'user', content: q });
    const r = await call({ tier: 'strong', system, messages, max: 24000, thinking: { type: 'adaptive', display: 'summarized' }, effort: 'medium', onText });
    const t = String(r.text || '').trim(); if (!t) throw new Error('وصل رد فارغ' + (r.stop ? ' (' + r.stop + ')' : ''));
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
  // وسم بين معقوفين قد يجمع عدة مواد أو مدى، مثل [قديم م١، م٢] أو [جديد م٢٠–٢٥]: يُعرض كاملاً ويفتح أول مادة فيه
  const GROUP = /\[((?:قديم|جديد)[^\[\]]{0,80})\]/g;
  function chip(cfg, m, label) {
    const t = resolve(cfg, m[1], !!m[2], !!m[3], m[4]);
    return '<button class="cref ' + (m[1] === 'قديم' ? 'o' : 'n') + '" data-cref="' + esc(t.lawId + '|' + t.n) + '">' + esc(label.replace(/\s+/g, ' ').trim()) + '</button>';
  }
  function bare(s, cfg) {
    let out = '', last = 0; REF.lastIndex = 0; let m;
    while ((m = REF.exec(s))) {
      out += esc(s.slice(last, m.index)); last = m.index + m[0].length;
      out += chip(cfg, m, m[1] + ' ' + (m[2] ? 'لائحة ' : '') + (m[3] || (!m[2] ? 'م' : '')) + ar(en(m[4]).replace(/\s+/g, '')));
    }
    return out + esc(s.slice(last));
  }
  function refsHTML(text, cfg) {
    const s = String(text); let out = '', last = 0, g; GROUP.lastIndex = 0;
    while ((g = GROUP.exec(s))) {
      REF.lastIndex = 0; const m = REF.exec('[' + g[1] + ']'); if (!m) continue;
      out += bare(s.slice(last, g.index), cfg); last = g.index + g[0].length;
      out += chip(cfg, m, ar(g[1]));
    }
    return out + bare(s.slice(last), cfg);
  }
  // التقدم الحقيقي: يُقاس بما كُتب فعلاً من كل جزء مقابل حجمه المتوقع
  function progress(rep) {
    if (!rep || !rep.specs) return { pc: 0, done: 0, total: 0, rem: '' };
    const now = Date.now(); let W = 0, D = 0, written = 0, done = 0;
    const planned = rep.specs.length > 1;
    rep.specs.forEach((sp) => {
      const s = (rep.secs || {})[sp.key]; W += sp.w;
      if (!s) return;
      if (s.state === 'run') { const got = s.text.length + 0.15 * (s.think || 0); written += got; D += sp.w * Math.min(0.97, got / sp.w + (sp.kind === 'plan' ? Math.min(0.6, (now - s.t) / 60000) : 0)); }
      else { D += sp.w; done++; written += (s.text || '').length; }
    });
    if (!planned) W += 50000; // قبل معرفة الأجزاء: تقدير لمجموعها
    const pc = Math.max(1, Math.min(99, Math.round(100 * D / W)));
    const el = (now - rep.t0) / 1000;
    let rem = 'يقدّر الوقت…';
    if (planned && D > 4000 && el > 20) { const rate = D / el; const s = (W - D) / rate; const m = Math.round(s / 60); rem = s < 60 ? 'باقي أقل من دقيقة' : m <= 1 ? 'باقي نحو دقيقة' : m === 2 ? 'باقي نحو دقيقتين' : 'باقي نحو ' + ar(m) + (m <= 10 ? ' دقائق' : ' دقيقة'); }
    return { pc, done, total: rep.specs.length, rem, writing: rep.specs.filter((sp) => rep.secs[sp.key] && rep.secs[sp.key].state === 'run').map((sp) => sp.title), thinking: rep.specs.some((sp) => rep.secs[sp.key] && rep.secs[sp.key].state === 'run' && !rep.secs[sp.key].text && rep.secs[sp.key].think) };
  }
  function estimate(ctx) { const tok = ctx.length / 2.4; return { tok: Math.round(tok), usd: (tok * 1.3 * 3.75e-6 + 20 * tok * 1.3 * 0.1e-6 + 20 * 4000 * 15e-6) }; }
  // «جزء واحد ناقص» و«جزآن ناقصان» و«٣ أجزاء ناقصة» و«١١ جزءاً ناقصاً»
  function parts(n) { return n === 1 ? 'جزء واحد ناقص' : n === 2 ? 'جزآن ناقصان' : n <= 10 ? ar(n) + ' أجزاء ناقصة' : ar(n) + ' جزءاً ناقصاً'; }
  function key(cfg) { return [cfg.oLaw, cfg.oReg || '-', cfg.nLaw, cfg.nReg || '-'].join('|'); }

  /* ---------- ملف Word ----------
     يُبنى داخل التطبيق دون مكتبات: ملفات XML في حزمة zip غير مضغوطة. */
  const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
  const crc32 = (b) => { let c = 0xffffffff; for (let i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  function zip(files) {
    const enc = new TextEncoder(); const parts = [], cen = []; let off = 0;
    const u16 = (v) => [v & 255, (v >>> 8) & 255], u32 = (v) => [v & 255, (v >>> 8) & 255, (v >>> 16) & 255, (v >>> 24) & 255];
    files.forEach(([name, str]) => {
      const nb = enc.encode(name), db = enc.encode(str), c = crc32(db);
      const head = [].concat(u32(0x04034b50), u16(20), u16(0x0800), u16(0), u16(0), u16(0x21), u32(c), u32(db.length), u32(db.length), u16(nb.length), u16(0));
      parts.push(Uint8Array.from(head), nb, db);
      cen.push(Uint8Array.from([].concat(u32(0x02014b50), u16(20), u16(20), u16(0x0800), u16(0), u16(0), u16(0x21), u32(c), u32(db.length), u32(db.length), u16(nb.length), u16(0), u16(0), u16(0), u16(0), u32(0), u32(off))), nb);
      off += head.length + nb.length + db.length;
    });
    const csz = cen.reduce((a, b) => a + b.length, 0);
    const end = Uint8Array.from([].concat(u32(0x06054b50), u16(0), u16(0), u16(files.length), u16(files.length), u32(csz), u32(off), u16(0)));
    const all = parts.concat(cen, [end]); const out = new Uint8Array(all.reduce((a, b) => a + b.length, 0)); let p = 0; all.forEach((b) => { out.set(b, p); p += b.length; });
    return out;
  }
  const X = (s) => String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '');
  function run(t, o) { o = o || {}; return '<w:r><w:rPr>' + (o.b ? '<w:b/><w:bCs/>' : '') + (o.c ? '<w:color w:val="' + o.c + '"/>' : '') + '<w:rtl/>' + (o.sz ? '<w:sz w:val="' + o.sz + '"/><w:szCs w:val="' + o.sz + '"/>' : '') + '</w:rPr><w:t xml:space="preserve">' + X(t) + '</w:t></w:r>'; }
  function para(runs, o) { o = o || {}; return '<w:p><w:pPr>' + (o.style ? '<w:pStyle w:val="' + o.style + '"/>' : '') + '<w:bidi/>' + (o.ind ? '<w:ind w:right="' + o.ind + '" w:hanging="260"/>' : '') + '<w:jc w:val="' + (o.jc || 'both') + '"/></w:pPr>' + runs + '</w:p>'; }
  function cell(t, o) { o = o || {}; return '<w:tc><w:tcPr><w:tcW w:w="' + o.w + '" w:type="dxa"/>' + (o.fill ? '<w:shd w:val="clear" w:color="auto" w:fill="' + o.fill + '"/>' : '') + '</w:tcPr>' + String(t).split('\n').map((l) => para(run(l, { b: o.b, sz: o.sz || 22 }), { jc: 'right' })).join('') + '</w:tc>'; }
  function docx(rep, cfg, laws, rows) {
    const nm = (id) => (laws[id] || {}).name || '';
    const day = new Date(rep.at || Date.now()).toLocaleDateString('ar-SA-u-ca-gregory-nu-arab', { day: 'numeric', month: 'long', year: 'numeric' });
    let b = para(run('تقرير مقارنة', { b: 1, sz: 40, c: '123C63' }), { jc: 'center' }) +
      para(run(nm(cfg.oLaw) + '  ←  ' + nm(cfg.nLaw), { b: 1, sz: 30 }), { jc: 'center' }) +
      para(run('كُتب في ' + day + ' بنموذج Sonnet 5.5، من النصوص النظامية المحفوظة في التطبيق.', { sz: 22, c: '5D6A78' }), { jc: 'center' });
    if (rows && rows.c) { const c = rows.c.all; b += para(run('معدّلة: ' + ar(c.mod) + '   ·   لا مقابل لها: ' + ar(c.del) + '   ·   جديدة: ' + ar(c.new) + '   ·   كما هي: ' + ar(c.same), { sz: 24, c: '8A6418' }), { jc: 'center' }); }
    sections(rep).forEach((s) => {
      if (!s.points.length) return;
      b += para(run(s.title, { b: 1, sz: 30, c: '123C63' }), { style: 'Heading1', jc: 'right' });
      s.points.forEach((p) => { b += para((p.favors ? run('[' + (p.favors === 'متوازن' ? 'متوازن' : 'لصالح ' + p.favors) + '] ', { b: 1, sz: 26, c: '8A6418' }) : '') + run('• ' + p.text, { sz: 28 }), { ind: 260 }); });
      if (s.state === 'cut') b += para(run('(انقطع هذا القسم قبل اكتماله، والمعروض ما كُتب منه)', { sz: 20, c: 'A3312A' }));
    });
    if (rows && rows.ai) {
      b += para(run('جدول المطابقة مادة مادة', { b: 1, sz: 30, c: '123C63' }), { style: 'Heading1', jc: 'right' });
      const W = [1700, 2300, 1300, 4300];
      const head = '<w:tr><w:trPr><w:tblHeader/></w:trPr>' + ['المادة الجديدة', 'مقابلها في القديم', 'الحالة', 'ما تغيّر'].map((t, i) => cell(t, { w: W[i], b: 1, fill: 'EAF0F7' })).join('') + '</w:tr>';
      const st = { mod: 'معدّلة', del: 'لا مقابل لها', new: 'جديدة', same: 'كما هي' };
      const tr = rows.law.concat(rows.reg).map((r) => '<w:tr>' + cell(r.n ? r.n.ref : '—', { w: W[0] }) + cell((r.os || (r.o ? [r.o] : [])).map((o) => o.ref).join('\n') || '—', { w: W[1] }) + cell(st[r.st], { w: W[2] }) + cell(r.note || '', { w: W[3] }) + '</w:tr>').join('');
      b += '<w:tbl><w:tblPr><w:bidiVisual/><w:tblW w:w="9600" w:type="dxa"/><w:tblBorders>' + ['top', 'left', 'bottom', 'right', 'insideH', 'insideV'].map((k) => '<w:' + k + ' w:val="single" w:sz="4" w:color="CFDBE8"/>').join('') + '</w:tblBorders></w:tblPr><w:tblGrid>' + W.map((w) => '<w:gridCol w:w="' + w + '"/>').join('') + '</w:tblGrid>' + head + tr + '</w:tbl>';
    }
    const docXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' + b + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1200" w:right="1150" w:bottom="1200" w:left="1150" w:header="600" w:footer="600" w:gutter="0"/><w:bidi/></w:sectPr></w:body></w:document>';
    const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Traditional Arabic" w:hAnsi="Traditional Arabic" w:cs="Traditional Arabic"/><w:sz w:val="28"/><w:szCs w:val="28"/><w:rtl/><w:lang w:val="ar-SA" w:bidi="ar-SA"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:bidi/><w:spacing w:after="120" w:line="300" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="320" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:bCs/></w:rPr></w:style></w:styles>';
    return zip([
      ['[Content_Types].xml', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>'],
      ['_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>'],
      ['word/_rels/document.xml.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>'],
      ['word/document.xml', docXml], ['word/styles.xml', styles]
    ]);
  }

  /* ---------- تقرير PDF ----------
     صفحة HTML مطبوعة بتنسيق A4؛ يحوّلها البرنامج إلى PDF، وخطوطها من مجلد الخطوط (fontBase). */
  function reportHTML(rep, cfg, laws, rows, fontBase) {
    const F = (n) => fontBase + n;
    // الوسوم بين معقوفين: [قديم …] ذهبي، [جديد …] أزرق
    const tags = (t) => esc(t).replace(/\[([^\]]+)\]/g, (m, x) => '<span class="tg ' + (/^\s*جديد/.test(x) ? 'n' : /^\s*قديم/.test(x) ? 'o' : 'x') + '">' + x + '</span>');
    const nm = (id) => (laws[id] || {}).name;
    const secs = sections(rep).filter((s) => s.points.length);
    const date = new Date(rep.at).toLocaleDateString('ar-SA-u-ca-gregory-nu-arab', { day: 'numeric', month: 'long', year: 'numeric' });
    const hdate = new Date(rep.at).toLocaleDateString('ar-SA-u-ca-islamic-umalqura-nu-arab', { day: 'numeric', month: 'long', year: 'numeric' });
    const c = rows.c.all; const par = rep.parties || [];
    const secHtml = secs.map((s, i) => {
      let extra = '';
      if (s.key === 'balance' && par.length === 2) {
        const a = s.points.filter((p) => p.favors && par[0].indexOf(p.favors) >= 0 || p.favors === par[0]).length, b = s.points.filter((p) => p.favors && (par[1].indexOf(p.favors) >= 0 || p.favors === par[1])).length, m = s.points.filter((p) => p.favors === 'متوازن').length, t = Math.max(1, a + b + m);
        extra = '<div class="bal"><i style="width:' + (a / t * 100) + '%;background:#123c63"></i><i style="width:' + (m / t * 100) + '%;background:#cfd8e3"></i><i style="width:' + (b / t * 100) + '%;background:#b8892b"></i></div><div class="bl"><span>لصالح ' + esc(par[0]) + ': ' + ar(a) + '</span><span>متوازن: ' + ar(m) + '</span><span>لصالح ' + esc(par[1]) + ': ' + ar(b) + '</span></div>';
      }
      return '<section><h2 id="s' + i + '"><span class="no">' + ar(i + 1) + '</span>' + esc(s.title) + '</h2>' + extra + '<ol>' + s.points.map((p) => '<li>' + (p.favors ? '<span class="fav' + (p.favors === 'متوازن' ? ' m' : (par[1] && (par[1].indexOf(p.favors) >= 0 || p.favors === par[1])) ? ' d' : '') + '">' + esc(p.favors === 'متوازن' ? 'متوازن' : 'لصالح ' + p.favors) + '</span> ' : '') + tags(p.text) + '</li>').join('') + '</ol></section>';
    }).join('');
    const st = { mod: ['معدّلة', 'mod'], del: ['لا مقابل لها', 'del'], new: ['جديدة', 'new'], same: ['كما هي', 'same'] };
    const tr = (list, title) => '<h3 class="tt">' + title + '</h3><table><thead><tr><th style="width:15%">المادة الجديدة</th><th style="width:20%">مقابلها في القديم</th><th style="width:11%">الحالة</th><th>ما تغيّر</th></tr></thead><tbody>' +
      list.map((r) => '<tr><td>' + (r.n ? '<span class="tg n">' + esc(r.n.ref) + '</span>' : '—') + '</td><td>' + ((r.os || (r.o ? [r.o] : [])).map((o) => '<span class="tg o">' + esc(o.ref) + '</span>').join(' ') || '—') + '</td><td><span class="st ' + st[r.st][1] + '">' + st[r.st][0] + '</span></td><td>' + tags(r.note || '') + '</td></tr>').join('') + '</tbody></table>';
    const html = `<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><style>
    @font-face{font-family:Naskh;src:url(${F('noto-naskh-arabic-arabic-400-normal.woff2')})}
    @font-face{font-family:Naskh;font-weight:700;src:url(${F('noto-naskh-arabic-arabic-700-normal.woff2')})}
    @font-face{font-family:Plex;src:url(${F('ibm-plex-sans-arabic-arabic-400-normal.woff2')})}
    @font-face{font-family:Plex;font-weight:600;src:url(${F('ibm-plex-sans-arabic-arabic-600-normal.woff2')})}
    @font-face{font-family:Plex;font-weight:700;src:url(${F('ibm-plex-sans-arabic-arabic-700-normal.woff2')})}
    @font-face{font-family:Plex;src:url(${F('ibm-plex-sans-arabic-latin-400-normal.woff2')});unicode-range:U+0000-00FF}
    @page{size:A4;margin:22mm 18mm 20mm}
    *{box-sizing:border-box}
    body{margin:0;font-family:Naskh,serif;font-size:12.5pt;line-height:2;color:#1b2430;text-align:justify}
    .cover{border-bottom:3px solid #b8892b;padding-bottom:14px;margin-bottom:18px;text-align:center}
    .kick{font-family:Plex;font-size:10pt;color:#8a6418;letter-spacing:0;font-weight:600}
    h1{font-family:Plex;font-weight:700;font-size:24pt;color:#123c63;margin:4px 0 6px;line-height:1.4}
    .laws{font-family:Plex;font-weight:600;font-size:13pt;line-height:1.7}
    .laws .a{color:#8a6418}.laws .b{color:#123c63}.laws .ar{color:#8b97a5;margin:0 8px}
    .meta{font-family:Plex;font-size:9.5pt;color:#5d6a78;margin-top:6px}
    .stats{display:flex;gap:8px;margin:16px 0 10px}
    .stat{flex:1;border:1px solid #e3e8ef;border-radius:10px;padding:8px 4px;text-align:center;font-family:Plex}
    .stat b{display:block;font-size:20pt;line-height:1.2}.stat span{font-size:9pt;color:#5d6a78}
    .stat.mod b{color:#8a6418}.stat.del b{color:#a3312a}.stat.new b{color:#1f6b52}.stat.same b{color:#5d6a78}
    .warn{font-family:Plex;font-size:9pt;color:#5d6a78;background:#f5f6f8;border-radius:8px;padding:7px 12px;line-height:1.7;text-align:right}
    .toc{margin:16px 0 0;font-family:Plex;font-size:10.5pt;columns:2;column-gap:28px;line-height:2}
    .toc a{color:#123c63;text-decoration:none}.toc span{color:#b8892b;margin-left:6px;font-weight:700}
    section{margin-top:18px}
    h2{font-family:Plex;font-weight:700;font-size:15pt;color:#123c63;margin:0 0 6px;padding-bottom:4px;border-bottom:1px solid #e3e8ef;break-after:avoid;display:flex;align-items:center;gap:8px}
    h2 .no{display:inline-grid;place-items:center;min-width:24px;height:24px;border-radius:7px;background:#123c63;color:#fff;font-size:11pt}
    ol{margin:0;padding:0 22px 0 0;list-style:arabic-indic}
    li{margin:0 0 6px;padding-right:4px;break-inside:avoid}
    li::marker{color:#b8892b;font-family:Plex;font-weight:700;font-size:10.5pt}
    .tg{font-family:Plex;font-size:8.6pt;font-weight:600;border-radius:5px;padding:0 5px;margin:0 1px;white-space:nowrap;vertical-align:1px;line-height:1.6}
    .tg.o{background:#fbf4e4;color:#8a6418}.tg.n{background:#eaf0f7;color:#123c63}.tg.x{background:#f1f4f8;color:#5d6a78}
    .fav{font-family:Plex;font-size:8.6pt;font-weight:700;border-radius:5px;padding:0 6px;background:#123c63;color:#fff;white-space:nowrap}
    .fav.d{background:#b8892b}.fav.m{background:#cfd8e3;color:#1b2430}
    .bal{display:flex;height:9px;border-radius:5px;overflow:hidden;margin:8px 0 4px}.bal i{display:block}
    .bl{display:flex;justify-content:space-between;font-family:Plex;font-size:9pt;color:#5d6a78;margin-bottom:8px}
    .mapsec{break-before:page}
    h3.tt{font-family:Plex;font-size:12pt;color:#123c63;margin:14px 0 6px}
    table{width:100%;border-collapse:collapse;font-size:10pt;line-height:1.7}
    thead{display:table-header-group}
    th{font-family:Plex;font-weight:700;font-size:9pt;background:#eaf0f7;color:#123c63;padding:5px 6px;text-align:right;border:1px solid #d6e0eb}
    td{padding:5px 6px;border:1px solid #e3e8ef;vertical-align:top;text-align:right}
    tr{break-inside:avoid}
    tbody tr:nth-child(even) td{background:#fafbfc}
    .st{font-family:Plex;font-size:8.6pt;font-weight:700;border-radius:5px;padding:1px 6px;white-space:nowrap}
    .st.mod{background:#fbf4e4;color:#8a6418}.st.del{background:#fbeceb;color:#a3312a}.st.new{background:#ecf5f1;color:#1f6b52}.st.same{background:#f1f4f8;color:#5d6a78}
    </style></head><body>
    <div class="cover"><div class="kick">تقرير مقارنة بين نظامين</div><h1>المقارنة الشاملة</h1>
    <div class="laws"><span class="a">${esc(nm(cfg.oLaw))}</span><span class="ar">←</span><span class="b">${esc(nm(cfg.nLaw))}</span></div>
    <div class="meta">مع ${cfg.oReg === 'attached' ? 'لائحته التنفيذية' : esc(nm(cfg.oReg) || '')} · و${esc(nm(cfg.nReg) || '')}<br>كُتب في ${hdate} الموافق ${date}</div></div>
    <div class="stats"><div class="stat mod"><b>${ar(c.mod)}</b><span>معدّلة</span></div><div class="stat del"><b>${ar(c.del)}</b><span>لا مقابل لها</span></div><div class="stat new"><b>${ar(c.new)}</b><span>جديدة</span></div><div class="stat same"><b>${ar(c.same)}</b><span>كما هي</span></div></div>
    <div class="warn">تحليل آلي كتبه الذكي (Sonnet 5.5) من نصوص النظامين ولائحتيهما المحفوظة في التطبيق؛ يُرجع إلى نص المادة قبل الاعتماد. أرقام المواد بالذهبي من النظام القديم، وبالأزرق من الجديد.</div>
    <div class="toc">${secs.map((s, i) => '<div><span>' + ar(i + 1) + '</span><a href="#s' + i + '">' + esc(s.title) + '</a></div>').join('')}<div><span>${ar(secs.length + 1)}</span><a href="#map">جدول المطابقة مادة مادة</a></div></div>
    ${secHtml}
    <section class="mapsec"><h2 id="map"><span class="no">${ar(secs.length + 1)}</span>جدول المطابقة مادة مادة</h2>
    ${tr(rows.law, 'مواد النظام')}${rows.reg && rows.reg.length ? tr(rows.reg, 'مواد اللائحة') : ''}</section>
    </body></html>`;

    const header = '<div style="width:100%;font-size:8px;color:#8b97a5;padding:0 18mm;direction:rtl;font-family:sans-serif;display:flex;justify-content:space-between"><span>مقارنة: ' + esc(nm(cfg.oLaw)) + ' ← ' + esc(nm(cfg.nLaw)) + '</span><span>الأنظمة</span></div>';
    const footer = '<div style="width:100%;font-size:9px;color:#5d6a78;text-align:center;font-family:sans-serif;direction:rtl">صفحة <span class="pageNumber"></span> من <span class="totalPages"></span></div>';
    return { html, header, footer };
  }

  G.CMP = { reportHTML, parts, resume, missing, norm, ar, en, esc, regOptions, defaultReg, compare, diffHTML, doc, report, retry, quickTest, sections, parseSec, progress, aiRows, ask, refsHTML, estimate, key, docx };
})(typeof window !== 'undefined' ? window : globalThis);
