"use strict";
/* ================= المرفقات: قراءة الصور وملفات PDF على الجهاز ================= */
S.atts = [];
let ocrWorkerP = null, ocrCurrent = null, attQueue = Promise.resolve(), attSeq = 0;
const $txt = id => document.getElementById(id).textContent;

function getOCR(){
  if(ocrWorkerP) return ocrWorkerP;
  ocrWorkerP = (async ()=>{
    // عامل واحد يضم النواة وبيانات العربية، ويقدّم ملف اللغة من الذاكرة بدل الإنترنت
    const prefix = `const __ARA="${$txt('araData').trim()}";
const __u8=b=>{const s=atob(b),u=new Uint8Array(s.length);for(let i=0;i<s.length;i++)u[i]=s.charCodeAt(i);return u};
const __f=self.fetch;self.fetch=(u,o)=>String(u).indexOf('ara.traineddata')>=0?Promise.resolve(new Response(__u8(__ARA))):__f(u,o);
`;
    const blob = new Blob([prefix, $txt('srcTessCore'), '\n;\n', $txt('srcTessWorker')], {type:'text/javascript'});
    const w = await Tesseract.createWorker('ara', 1, {
      workerPath: URL.createObjectURL(blob), workerBlobURL:false, langPath:'https://local.invalid/lang', cacheMethod:'none',
      logger: m=>{ if(ocrCurrent && m.status==='recognizing text'){ ocrCurrent.progress = m.progress; updateAttRow(ocrCurrent); } }
    });
    await w.setParameters({tessedit_pageseg_mode:'4', preserve_interword_spaces:'0'});   // عمود واحد: أدق في المسافات بين الكلمات العربية
    return w;
  })();
  ocrWorkerP.catch(()=>{ ocrWorkerP = null; });
  return ocrWorkerP;
}

let pdfInit = false;
function pdfLib(){
  if(!pdfInit){ pdfjsLib.GlobalWorkerOptions.workerSrc = URL.createObjectURL(new Blob([$txt('srcPdfWorker')],{type:'text/javascript'})); pdfInit = true; }
  return pdfjsLib;
}

/* ---------- تنظيف النص ---------- */
function cleanText(t){
  return normDigits((t||'').normalize('NFKC')).replace(/ـ/g,'').replace(/[ \t]+/g,' ').replace(/ *\n */g,'\n').replace(/\n{3,}/g,'\n\n').trim();
}
function arabicScore(t){ const m = t.match(/(^|[\s،.:])(في|من|على|رقم|إلى|عقد|تاريخ|المملكة|العربية|السعودية)(?=[\s،.:]|$)/g); return m?m.length:0; }

/* ---------- تحويل الصورة إلى لوحة بحجم مناسب للقراءة ---------- */
function loadImage(blob){
  return new Promise((res,rej)=>{ const u=URL.createObjectURL(blob); const im=new Image(); im.onload=()=>res({im,u}); im.onerror=()=>rej(new Error('تعذّر فتح الصورة')); im.src=u; });
}
function toCanvas(src, w, h){
  let scale = 1; if(w<1600) scale = Math.min(3, 1800/w); if(w*scale>3200) scale = 3200/w;
  const c=document.createElement('canvas'); c.width=Math.round(w*scale); c.height=Math.round(h*scale);
  const x=c.getContext('2d'); x.fillStyle='#fff'; x.fillRect(0,0,c.width,c.height); x.imageSmoothingQuality='high'; x.drawImage(src,0,0,c.width,c.height);
  return c;
}
function thumbOf(canvas){ const c=document.createElement('canvas'); const s=144/Math.max(canvas.width,canvas.height); c.width=Math.max(1,Math.round(canvas.width*s)); c.height=Math.max(1,Math.round(canvas.height*s)); c.getContext('2d').drawImage(canvas,0,0,c.width,c.height); return c.toDataURL('image/jpeg',.7); }

async function ocrCanvas(att, canvas){
  att.status='قراءة النص'; att.progress=0; updateAttRow(att);
  const w = await getOCR(); ocrCurrent = att;
  const r = await w.recognize(canvas); ocrCurrent = null;
  return {text:r.data.text||'', conf:r.data.confidence||0};
}

/* ---------- معالجة مرفق ---------- */
async function processFile(file){
  const att = {id:'a'+(++attSeq), name:file.name||'صورة ملصقة', kind:/pdf$/i.test(file.type)||/\.pdf$/i.test(file.name||'')?'pdf':'img', status:'في الانتظار', progress:0, text:'', conf:100, doc:null, thumb:''};
  S.atts.push(att); renderAtts();
  attQueue = attQueue.then(async ()=>{
    try{
      if(att.kind==='img'){
        att.status='تجهيز الصورة'; updateAttRow(att);
        const {im,u} = await loadImage(file); const c = toCanvas(im, im.naturalWidth, im.naturalHeight); URL.revokeObjectURL(u);
        att.thumb = thumbOf(c); updateAttRow(att, true);
        const r = await ocrCanvas(att, c); att.text = cleanText(r.text); att.conf = r.conf; att.ocr = true;
      } else {
        att.status='فتح الملف'; updateAttRow(att);
        const pdf = await pdfLib().getDocument({data: new Uint8Array(await file.arrayBuffer())}).promise;
        const n = Math.min(pdf.numPages, 15); const parts=[]; let confs=[];
        for(let p=1;p<=n;p++){
          const page = await pdf.getPage(p);
          const tc = await page.getTextContent(); let t = tc.items.map(i=>i.str+(i.hasEOL?'\n':' ')).join('');
          t = cleanText(t);
          const vp = page.getViewport({scale:2}); const c=document.createElement('canvas'); c.width=vp.width; c.height=vp.height;
          const x=c.getContext('2d'); x.fillStyle='#fff'; x.fillRect(0,0,c.width,c.height);
          if(p===1 || arabicScore(t)<3){ await page.render({canvasContext:x, viewport:vp}).promise; if(p===1){ att.thumb=thumbOf(c); updateAttRow(att,true); } }
          if(arabicScore(t)>=3 && !/[ﭐ-﻿]/.test(t)){ parts.push(t); }
          else { att.status=`قراءة الصفحة ${p} من ${n}`; const r = await ocrCanvas(att, c); parts.push(cleanText(r.text)); confs.push(r.conf); att.ocr = true; }
        }
        att.text = parts.join('\n\n— صفحة —\n\n'); att.conf = confs.length? confs.reduce((a,b)=>a+b,0)/confs.length : 100;
        if(pdf.numPages>n) att.text += `\n\n(قُرئت أول ${n} صفحة من ${pdf.numPages})`;
      }
      att.doc = analyzeDoc(att.text); att.status='تمت القراءة'; att.progress=1;
    }catch(err){ att.status='تعذّرت القراءة: '+(err && err.message || err); att.failed=true; }
    renderAtts();
    if(S.analyzed){ applyAttachments(); renderAll(); }
  });
  return attQueue;
}

/* ---------- التعرف على نوع المستند واستخراج المهم ---------- */
const NUM = '([0-9][0-9,.٬]*)';
const DATE = '([0-9]{1,4}\\s*[\\/\\-]\\s*[0-9]{1,2}\\s*[\\/\\-]\\s*[0-9]{1,4})';
function after(t, labels, valRe, span){ const re = new RegExp('('+labels+')[^0-9\\n]{0,'+(span||25)+'}'+valRe); const m=t.match(re); return m? m[m.length-1].replace(/\s+/g,''):''; }
function afterText(t, labels){
  for(const l of labels.split('|')){ const m = t.match(new RegExp(l+'[ \\t]*[:：][ \\t]*([^\\n:：]{2,45})')); if(m) return m[1].replace(/\s+/g,' ').trim(); }
  for(const l of labels.split('|')){ const m = t.match(new RegExp('(^|\\n)[ \\t]*'+l+'[ \\t]+([^\\n:：]{3,45})')); if(m) return m[2].replace(/\s+/g,' ').trim(); }
  return '';
}
const numOnly = v => (v||'').replace(/[^0-9.]/g,'');
function money(t, labels){ const v = after(t, labels, NUM, 30); const n = parseFloat(numOnly(v)); return n? fmtNum(n):''; }

const DOCS = [
  {type:'ejar', label:'عقد إيجار', test:t=>/(إيجار|ايجار)/.test(t) && /(المؤجر|المستأجر|مستأجر|مؤجر|الوحدة الإيجارية|مدة الإيجار|سجل العقد)/.test(t),
    ex:t=>({
      contractNo:{label:'رقم العقد', v: after(t,'رقم سجل العقد|رقم العقد|سجل العقد|رقم عقد الإيجار','([0-9]{6,})',30)},
      lessor:{label:'المؤجر', v: afterText(t,'اسم المؤجر|المؤجر')},
      lessee:{label:'المستأجر', v: afterText(t,'اسم المستأجر|المستأجر')},
      rent:{label:'الأجرة', v: money(t,'قيمة الإيجار السنوي|الأجرة السنوية|الاجرة السنوية|إجمالي قيمة العقد|اجمالي قيمة العقد|قيمة الأجرة|مبلغ الإيجار|قيمة الإيجار')},
      start:{label:'بداية العقد', v: after(t,'تاريخ بداية مدة الإيجار|تاريخ بداية العقد|بداية مدة الإيجار|تاريخ البداية|بداية الإيجار|تاريخ بدء',DATE,40)},
      end:{label:'نهاية العقد', v: after(t,'تاريخ نهاية مدة الإيجار|تاريخ نهاية العقد|نهاية مدة الإيجار|تاريخ النهاية|نهاية الإيجار|تاريخ انتهاء',DATE,40)},
      unit:{label:'نوع الوحدة', v: afterText(t,'نوع الوحدة|استخدام الوحدة|الغرض من الإيجار')}
    })},
  {type:'deed', label:'صك ملكية', test:t=>/[صض]+ك/.test(t) && /(المالك|رقم الصك|المساحة|الحدود|كتابة العدل|وزارة العدل|السجل العقاري|قطعة)/.test(t),
    ex:t=>({
      deedNo:{label:'رقم الصك', v: after(t,'رقم ال[صض]+ك|ال[صض]+ك رقم|[صض]ك رقم|رقم الوثيقة','([0-9]{6,})',20)},
      owner:{label:'المالك', v: afterText(t,'اسم المالك|المالك|الملاك')},
      area:{label:'المساحة', v: after(t,'المساحة|مساحة',NUM,25)},
      plot:{label:'رقم القطعة', v: after(t,'رقم القطعة|قطعة رقم|القطعة رقم|القطعة','([0-9]{1,6})',15)},
      date:{label:'تاريخ الصك', v: after(t,'تاريخ الصك|بتاريخ|التاريخ',DATE,20)}
    })},
  {type:'najm', label:'تقرير حادث', test:t=>/(نجم|تقرير (ال)?حادث|محضر (ال)?حادث|نسبة (ال)?(خطأ|خطا|مسؤولية|المسؤولية)|المرور)/.test(t),
    ex:t=>{ // القراءة الضوئية تقرأ علامة % أحياناً «96»
      const fix=v=>{ v=v.replace(/[%٪\s]/g,''); if(+v>100 && /^96/.test(v)) v=v.slice(2); if(+v>100 && /96$/.test(v)) v=v.slice(0,-2); return v===''?NaN:+v; };
      let rs=[...t.matchAll(/نسبة\s*(ال)?(خطأ|خطا|خطأً|المسؤولية|مسؤولية|الخطأ)[^0-9\n]{0,12}([0-9%٪ ]{1,7})/g)].map(m=>fix(m[3])).filter(n=>n>=0&&n<=100);
      if(!rs.length) rs=[...t.matchAll(/([0-9]{1,3})\s*[%٪]/g)].map(m=>+m[1]).filter(n=>n<=100);
      return {
        ratios:{label:'نسب الخطأ', v: rs.length? [...new Set(rs)].map(n=>n+'٪').join(' / '):''},
        date:{label:'تاريخ الحادث', v: after(t,'تاريخ الحادث|تاريخ ووقت الحادث|التاريخ',DATE,30)},
        reportNo:{label:'رقم التقرير', v: after(t,'رقم الحادث|رقم التقرير|رقم البلاغ|رقم القضية','([0-9A-Za-z\\-]{5,})',20)}
      }}},
  {type:'shijaj', label:'تقرير مقدّري الشجاج', test:t=>/(شجاج|أرش|ارش|حكومة)/.test(t) && /(مقدر|تقدير|تقرير)/.test(t),
    ex:t=>({ amount:{label:'المبلغ المقدّر', v: money(t,'المبلغ|بمبلغ|قدره|وقدره|الإجمالي|الاجمالي|المجموع|إجمالي')}, injury:{label:'الإصابة', v: afterText(t,'الإصابة|الاصابة|نوع الإصابة')} })},
  {type:'medical', label:'تقرير طبي', test:t=>/(تقرير طبي|التقرير الطبي|التشخيص|المستشفى|مستشفى|الحالة الصحية|Diagnosis)/i.test(t),
    ex:t=>({ diagnosis:{label:'التشخيص', v: afterText(t,'التشخيص|Diagnosis|الإصابة|الاصابة')}, date:{label:'التاريخ', v: after(t,'تاريخ الدخول|تاريخ التقرير|التاريخ',DATE,25)} })},
  {type:'note', label:'سند لأمر', test:t=>/سند لأمر|سند لامر/.test(t),
    ex:t=>({ amount:{label:'المبلغ', v: money(t,'المبلغ|مبلغ|قيمة السند')}, due:{label:'تاريخ الاستحقاق', v: after(t,'تاريخ الاستحقاق|الاستحقاق',DATE,20)} })},
  {type:'sale', label:'عقد بيع أو مبايعة', test:t=>/(عقد بيع|مبايعة|البائع|المشتري|الطرف الأول البائع)/.test(t),
    ex:t=>({ price:{label:'الثمن', v: money(t,'الثمن|بمبلغ|قيمة البيع|سعر البيع|المبلغ')}, date:{label:'تاريخ البيع', v: after(t,'تاريخ البيع|تاريخ العقد|بتاريخ|التاريخ',DATE,25)}, seller:{label:'البائع', v: afterText(t,'البائع|اسم البائع')}, buyer:{label:'المشتري', v: afterText(t,'المشتري|اسم المشتري')} })},
  {type:'bank', label:'تحويل أو كشف حساب', test:t=>/(تحويل|حوالة|كشف حساب|الآيبان|ايبان|IBAN|المستفيد|رقم العملية)/i.test(t),
    ex:t=>({ amount:{label:'المبلغ', v: money(t,'المبلغ|مبلغ التحويل|قيمة التحويل|Amount')}, date:{label:'التاريخ', v: after(t,'التاريخ|تاريخ العملية|تاريخ التحويل',DATE,20)}, ben:{label:'المستفيد', v: afterText(t,'المستفيد|اسم المستفيد')} })}
];
function analyzeDoc(text){
  for(const d of DOCS) if(d.test(text)){ const items = d.ex(text); for(const k in items) if(!items[k].v) delete items[k]; return {type:d.type, label:d.label, items}; }
  const amt = maxAmount(text);
  return {type:'other', label:'مستند', items: amt? {amount:{label:'أكبر مبلغ مذكور', v:fmtNum(amt)}} : {}};
}

/* ---------- ربط المرفقات بالقضية ---------- */
const DOC_CHIPS = {ejar:['contract'], deed:['deed','ownShare'], najm:['report'], medical:['medical'], shijaj:['shijaj'], sale:['sale'], bank:['transfer'], note:['bond']};
let attConflicts = [];
function docsOf(type){ return S.atts.filter(a=>a.doc && a.doc.type===type); }
function firstItem(type, key){ for(const a of docsOf(type)) if(a.doc.items[key]) return a.doc.items[key].v; return ''; }
const sameNum = (a,b) => numOnly(a)===numOnly(b);
function fillFromDoc(fieldKey, value, label){
  if(!value || !T[S.type] || !T[S.type].fields.some(f=>f.k===fieldKey)) return;
  const cur = S.f[fieldKey];
  if(!cur){ S.f[fieldKey]=value; S.st[fieldKey]='unc'; return; }
  if(!sameNum(cur,value) && /[0-9]/.test(cur+value)) attConflicts.push({lvl:'red', t:`تعارض في ${label}`, b:`في المحضر (${cur})، وفي المرفق (${value}). تحقق قبل الحكم.`});
}
function applyAttachments(){
  attConflicts = [];
  if(!S.type || !S.atts.length) return;
  const evIds = new Set(T[S.type].ev.map(e=>e.id));
  for(const a of S.atts){ if(!a.doc) continue; for(const id of (DOC_CHIPS[a.doc.type]||[])) if(evIds.has(id)) S.ev.add(id); }
  fillFromDoc('contractNo', firstItem('ejar','contractNo'), 'رقم العقد');
  fillFromDoc('deedNo', firstItem('deed','deedNo'), 'رقم الصك');
  if(['ownRE','ownCar','defect','shufaa'].includes(S.type)) fillFromDoc('amount', firstItem('sale','price'), 'الثمن');
  if(S.type==='injury') fillFromDoc('amount', firstItem('shijaj','amount'), 'المبلغ المقدّر');
  if(S.type==='traffic'){ const r = firstItem('najm','ratios'); const ns=(r.match(/[0-9]+/g)||[]).map(Number); if(ns.length && !S.f.ratio){ S.f.ratio=String(Math.max(...ns)); S.st.ratio='unc'; } }
}
function toDate(s){
  const m = (s||'').match(/([0-9]{1,4})\s*[\/\-]\s*([0-9]{1,2})\s*[\/\-]\s*([0-9]{1,4})/); if(!m) return null;
  let y,mo,d; if(+m[1]>31){y=+m[1];mo=+m[2];d=+m[3]}else{d=+m[1];mo=+m[2];y=+m[3]}
  if(y>1300 && y<1600){ // هجري
    const approx = Date.UTC(622,6,16) + ((y-1)*354.36707 + (mo-1)*29.5306 + (d-1))*86400000;
    for(let k=-45;k<=45;k++){ const t=new Date(approx+k*86400000); const h=hijriParts(t); if(h.d===d&&h.m===mo&&h.y===y) return t; }
    return new Date(approx);
  }
  if(y>1900) return new Date(Date.UTC(y,mo-1,d));
  return null;
}
function attAlerts(){
  const a = attConflicts.slice();
  if(!S.atts.length) return a;
  const pending = S.atts.filter(x=>!x.doc && !x.failed).length;
  if(pending) a.push({lvl:'info', t:'المرفقات قيد القراءة', b:`باقي ${pending} مرفق، وتُحدَّث البيانات تلقائياً بعد انتهائها.`});
  if(S.atts.some(x=>x.ocr && x.conf<70)) a.push({lvl:'warn', t:'قراءة مرفق غير واضحة', b:'أحد المرفقات مصوّر بجودة ضعيفة، فراجع ما استُخرج منه (بالأصفر) مع الأصل.'});
  // المالك في الصك ومدى وروده في المحضر
  const owner = firstItem('deed','owner');
  if(owner && S.text){ const w = owner.split(/\s+/).filter(x=>x.length>2).slice(0,2); if(w.length && !w.every(x=>S.text.includes(x))) a.push({lvl:'warn', t:'اسم المالك في الصك', b:`المالك في الصك (${owner}) لم يرد اسمه في المحضر؛ تحقق من صفة المدعي.`}); }
  // انتهاء عقد الإيجار
  const end = toDate(firstItem('ejar','end'));
  if(end && S.type==='lease'){ const past = end < new Date(); a.push({lvl: past?'info':'warn', t: past?'العقد منتهٍ في المرفق':'العقد سارٍ في المرفق', b:`تاريخ نهاية العقد في المرفق: ${firstItem('ejar','end')}.`+(!past && S.f.sabab==='انتهاء مدة العقد'?' والدعوى مبنية على انتهاء المدة!':'')}); }
  // الشفعة: 180 يوماً من تسجيل البيع
  if(S.type==='shufaa'){ const d = toDate(firstItem('sale','date')||firstItem('deed','date')); if(d){ const days=Math.floor((Date.now()-d)/86400000); if(days>180) a.push({lvl:'red', t:'مضى أكثر من 180 يوماً على البيع', b:`بحسب المرفق مضى نحو ${days} يوماً؛ لا تُسمع دعوى الشفعة بعد 180 يوماً من تسجيل البيع (م667). تحقق من تاريخ التسجيل.`}); } }
  // العيب: 180 يوماً من التسليم
  if(S.type==='defect'){ const d = toDate(firstItem('sale','date')); if(d){ const days=Math.floor((Date.now()-d)/86400000); if(days>180) a.push({lvl:'warn', t:'مضى أكثر من 180 يوماً على البيع', b:`بحسب المرفق مضى نحو ${days} يوماً؛ تحقق من تاريخ التسليم (م344).`}); } }
  // المبلغ في الدعوى أكبر من الثابت في المرفقات المالية
  if(['loan'].includes(S.type)){ const amts = docsOf('bank').map(x=>parseFloat(numOnly(x.doc.items.amount&&x.doc.items.amount.v))).filter(Boolean); const sum = amts.reduce((p,c)=>p+c,0); const claim=parseFloat(numOnly(S.f.amount)); if(sum && claim && Math.abs(sum-claim)>1) a.push({lvl:'warn', t:'المبلغ لا يطابق التحويلات', b:`المطالب به (${fmtNum(claim)}) ومجموع التحويلات المرفقة (${fmtNum(sum)}).`}); }
  return a;
}

/* ---------- العرض ---------- */
function attRowHTML(a){
  const items = a.doc? Object.values(a.doc.items).map(i=>`<li><b>${esc(i.label)}:</b> ${esc(i.v)}</li>`).join('') : '';
  const pct = Math.round((a.progress||0)*100);
  return `<div class="att" data-att="${a.id}">
    ${a.thumb?`<img src="${a.thumb}" alt="">`:`<img alt="">`}
    <div class="ab">
      <span class="an">${esc(a.doc? a.doc.label : a.name)}${a.doc&&a.doc.type!=='other'?` <span class="muted" style="font-weight:400">· ${esc(a.name)}</span>`:''}</span>
      ${a.doc? (items?`<ul>${items}</ul>`:'<span class="muted">لم يُتعرّف على بيانات محددة؛ النص الكامل متاح.</span>') : `<span class="muted">${esc(a.status)}${a.failed?'':` ${pct?pct+'%':''}`}</span>${a.failed?'':`<div class="bar"><i style="width:${pct}%"></i></div>`}`}
      ${a.doc&&a.ocr&&a.conf<70?'<span class="muted" style="color:var(--wtx)">قراءة ضعيفة الوضوح — راجع الأرقام</span>':''}
      <div class="row">
        ${a.doc?`<button class="btn sm" type="button" data-full="${a.id}">النص الكامل</button>`:''}
        <button class="btn sm" type="button" data-rm="${a.id}">حذف</button>
      </div>
    </div></div>`;
}
function renderAtts(){ $('#attList').innerHTML = S.atts.map(attRowHTML).join(''); }
function updateAttRow(a){ const el = document.querySelector(`[data-att="${a.id}"]`); if(el) el.outerHTML = attRowHTML(a); else renderAtts(); }

$('#attList').addEventListener('click', e=>{
  const f = e.target.closest('[data-full]'); if(f){ const a=S.atts.find(x=>x.id===f.dataset.full); $('#dlgTextTitle').textContent = 'النص الكامل — '+(a.doc?a.doc.label:a.name); $('#fullText').value=a.text||''; $('#dlgText').showModal(); return; }
  const r = e.target.closest('[data-rm]'); if(r){ S.atts = S.atts.filter(x=>x.id!==r.dataset.rm); renderAtts(); if(S.analyzed){ loadType(false); renderAll(); } }
});
$('#btnCopyFull').onclick = async ()=>{ try{ await navigator.clipboard.writeText($('#fullText').value); }catch(_){ $('#fullText').select(); document.execCommand('copy'); } toast('نُسخ النص'); };

/* ---------- طرق الإدخال: لصق، إرفاق، سحب وإفلات، حافظة ---------- */
function takeFiles(list){ let n=0; for(const f of list){ if(f && (/^image\//.test(f.type) || /pdf/.test(f.type) || /\.pdf$/i.test(f.name||''))){ processFile(f); n++; } } if(n) toast(n===1?'أُضيف المرفق':`أُضيف ${n} مرفقات`); return n; }
function filesFromClipboard(e){ const out=[]; const items = (e.clipboardData && e.clipboardData.items) || []; for(const it of items){ if(it.kind==='file'){ const f=it.getAsFile(); if(f) out.push(f); } } return out; }
document.addEventListener('paste', e=>{
  const files = filesFromClipboard(e);
  if(files.length){ e.preventDefault(); takeFiles(files); }
  else if(e.target && e.target.id==='pasteZone'){ e.preventDefault(); toast('الحافظة لا تحتوي صورة'); }
});
const pz = $('#pasteZone');
pz.addEventListener('input', ()=>{ pz.innerHTML=''; });          // لا نكتب نصاً في منطقة اللصق
pz.addEventListener('dragover', e=>{ e.preventDefault(); pz.classList.add('drag'); });
pz.addEventListener('dragleave', ()=>pz.classList.remove('drag'));
pz.addEventListener('drop', e=>{ e.preventDefault(); pz.classList.remove('drag'); takeFiles(e.dataTransfer.files||[]); });
$('#fileAtt').onchange = e=>{ takeFiles(e.target.files||[]); e.target.value=''; };
$('#btnClipRead').onclick = async ()=>{
  if(!navigator.clipboard || !navigator.clipboard.read){ toast('استعمل Ctrl+V أو اللصق في المربع'); pz.focus(); return; }
  try{ const items = await navigator.clipboard.read(); const files=[];
    for(const it of items){ const t = it.types.find(x=>/^image\//.test(x)||/pdf/.test(x)); if(t){ const b = await it.getType(t); files.push(new File([b], 'صورة ملصقة', {type:t})); } }
    if(!takeFiles(files)) toast('الحافظة لا تحتوي صورة');
  }catch(_){ toast('اسمح بالوصول للحافظة، أو الصق في المربع'); pz.focus(); }
};
if(window.__tasbeeb) Object.assign(window.__tasbeeb, {processFile, analyzeDoc, attAlerts, applyAttachments});
