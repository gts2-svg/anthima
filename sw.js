/* anthima — يحفظ التطبيق داخل الجهاز ليفتح فوراً ويعمل بدون إنترنت */
const CACHE = 'anthima-2026-11-04a';
const CORE = ["./", "index.html", "manifest.webmanifest", "laws.json", "icon-180.png", "icon-192.png", "icon-512.png", "icon-maskable-512.png"];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  const same = url.origin === location.origin;
  const font = /fonts\.(googleapis|gstatic)\.com$/.test(url.hostname);
  if (!same && !font) return;
  // يعرض المحفوظ فوراً، ويحدّثه من الشبكة في الخلفية للمرة القادمة
  e.respondWith(caches.open(CACHE).then(async c => {
    const key = same && req.mode === 'navigate' ? './' : req;
    const hit = await c.match(key, { ignoreSearch: same });
    const net = fetch(req).then(r => { if (r && (r.ok || r.type === 'opaque')) c.put(key, r.clone()); return r; }).catch(() => null);
    return hit || (await net) || new Response('', { status: 504 });
  }));
});
