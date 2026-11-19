"""يجهّز اختبار TestFlight لتطبيق من غير فتح App Store Connect:
مجموعة داخلية اسمها ME تصلها كل نسخة تلقائياً، وفيها المختبِرون المذكورون في TESTERS.
يُشغَّل بعد رفع أي نسخة، ولا يضرّ تكراره: ما كان موجوداً يُترك كما هو.

المتغيرات: BUNDLE_ID، TESTERS (بريد أو أكثر بينها مسافات)، ASC_KEY_ID، ASC_ISSUER_ID، ASC_KEY_P8."""
import json, os, sys, time, urllib.error, urllib.parse, urllib.request
import jwt  # pyjwt[crypto]

API = "https://api.appstoreconnect.apple.com/v1"
GROUP = "ME"


def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})


def call(method, path, body=None, ok_fail=False):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:600]
        if ok_fail:
            print(f"  (تجاهلت) {method} {path}: {e.code} {detail}")
            return None
        sys.exit(f"::error::{method} {path}: {e.code} {detail}")


def q(**params):
    return "?" + urllib.parse.urlencode(params)


def main():
    bundle = os.environ["BUNDLE_ID"]
    emails = [e.strip().lower() for e in os.environ.get("TESTERS", "").split() if e.strip()]

    apps = call("GET", "/apps" + q(**{"filter[bundleId]": bundle}))["data"]
    if not apps:
        sys.exit(f"::error::لا يوجد تطبيق في App Store Connect بالمعرّف {bundle}. أنشئه أولاً (Apps ← + ← New App).")
    app = apps[0]["id"]
    print(f"التطبيق: {apps[0]['attributes']['name']} ({bundle})")

    groups = [g for g in call("GET", f"/apps/{app}/betaGroups" + q(limit=200))["data"] if g["attributes"].get("isInternalGroup")]
    group = next((g for g in groups if g["attributes"]["name"] == GROUP), groups[0] if groups else None)
    if group is None:
        group = call("POST", "/betaGroups", {"data": {"type": "betaGroups",
            "attributes": {"name": GROUP, "isInternalGroup": True, "hasAccessToAllBuilds": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})["data"]
        print(f"أنشأت مجموعة {GROUP}، وتصلها كل نسخة تلقائياً")
    else:
        print(f"المجموعة موجودة: {group['attributes']['name']}")
        if not group["attributes"].get("hasAccessToAllBuilds"):
            call("PATCH", f"/betaGroups/{group['id']}", {"data": {"type": "betaGroups", "id": group["id"],
                 "attributes": {"hasAccessToAllBuilds": True}}}, ok_fail=True)
    gid = group["id"]

    inside = {t["attributes"].get("email", "").lower() for t in
              call("GET", f"/betaGroups/{gid}/betaTesters" + q(limit=200))["data"]}
    for email in emails:
        if email in inside:
            print(f"  {email}: موجود في المجموعة")
            continue
        # الإضافة بإنشاء المختبِر داخل المجموعة؛ وإن رفضتها أبل فبربط المختبِر الموجود بها
        made = call("POST", "/betaTesters", {"data": {"type": "betaTesters",
            "attributes": {"email": email, "firstName": "JUBRAN", "lastName": "ALTALIDI"},
            "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": gid}]}}}}, ok_fail=True)
        if made:
            tid = made["data"]["id"]
        else:
            found = call("GET", "/betaTesters" + q(**{"filter[email]": email}))["data"]
            if not found:
                print(f"::warning::{email}: لم أستطع إضافته"); continue
            tid = found[0]["id"]
            if call("POST", f"/betaGroups/{gid}/relationships/betaTesters",
                    {"data": [{"type": "betaTesters", "id": tid}]}, ok_fail=True) is None:
                print(f"::warning::{email}: أبل رفضت إضافته للمجموعة"); continue
        call("POST", "/betaTesterInvitations", {"data": {"type": "betaTesterInvitations", "relationships": {
            "app": {"data": {"type": "apps", "id": app}}, "betaTester": {"data": {"type": "betaTesters", "id": tid}}}}},
            ok_fail=True)
        print(f"  {email}: أُضيف وأُرسلت له الدعوة")

    # النسخ المرفوعة قبل إنشاء المجموعة: تُضاف إليها (ما كان منها قيد المعالجة يصلها تلقائياً بعد انتهائها)
    builds = call("GET", "/builds" + q(**{"filter[app]": app, "sort": "-uploadedDate", "limit": 3}))["data"]
    ready = [b for b in builds if b["attributes"].get("processingState") == "VALID" and not b["attributes"].get("expired")]
    if ready:
        call("POST", f"/betaGroups/{gid}/relationships/builds", {"data": [{"type": "builds", "id": b["id"]} for b in ready]},
             ok_fail=True)
        print("النسخ الجاهزة في المجموعة: " + ", ".join(b["attributes"]["version"] for b in ready))
    else:
        print("لا نسخة جاهزة بعد؛ ستصل المجموعة تلقائياً حين تنتهي معالجتها")


if __name__ == "__main__":
    main()
