/* anthima — يحفظ التطبيق داخل الجهاز ليفتح بدون إنترنت، ويجلب أحدث نسخة كلما توفر الاتصال */
const CACHE = 'anthima-2026-11-05g';
const CORE = ['./', 'index.html', 'manifest.webmanifest', 'laws.json', 'icon-180.png', 'icon-192.png', 'icon-512.png', 'icon-maskable-512.png'];
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(CORE.map((u) => new Request(u, { cache: 'reload' })))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const same = url.origin === location.origin;
  const font = /fonts\.(googleapis|gstatic)\.com$/.test(url.hostname);
  if (!same && !font) return;
  const fresh = same && (req.mode === 'navigate' || /\/(index\.html|laws\.json)?$/.test(url.pathname) || url.pathname.endsWith('laws.json'));
  e.respondWith(caches.open(CACHE).then(async (c) => {
    const key = same && req.mode === 'navigate' ? './' : (same ? url.pathname.replace(/^.*\//, '') || './' : req);
    if (fresh) {
      // الصفحة والأنظمة: من الشبكة أولاً حتى يصل التحديث فوراً، والمحفوظ عند انقطاع النت
      try { const r = await fetch(req, { cache: 'no-cache' }); if (r && r.ok) c.put(key, r.clone()); return r; }
      catch (err) { return (await c.match(key)) || (await c.match(req, { ignoreSearch: true })) || new Response('', { status: 504 }); }
    }
    const hit = await c.match(req, { ignoreSearch: same });
    const net = fetch(req).then((r) => { if (r && (r.ok || r.type === 'opaque')) c.put(req, r.clone()); return r; }).catch(() => null);
    return hit || (await net) || new Response('', { status: 504 });
  }));
});
