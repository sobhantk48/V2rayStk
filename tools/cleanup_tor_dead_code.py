import re, os, sys

ROOT = os.path.expanduser("~/development/V2rayStk")
SVC  = os.path.join(ROOT, "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt")
DEAD = [
    "lib/features/vpn/presentation/tor_switch_widget.dart",
    "lib/features/vpn/providers/tor_provider.dart",
]

print("=" * 60)

# ---------- ۱) پاکسازی V2rayVpnService.kt ----------
if not os.path.isfile(SVC):
    print("❌ V2rayVpnService.kt پیدا نشد:", SVC); sys.exit(1)

src = open(SVC, encoding="utf-8").read()
orig = src

# حذف تابع مردهٔ waitForPort (با brace-matching امن)
m = re.search(r'[ \t]*private fun waitForPort\s*\(', src)
if m:
    i = src.index("{", m.end())
    depth, j = 0, i
    while j < len(src):
        if src[j] == "{": depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0: break
        j += 1
    start = src.rfind("\n", 0, m.start()) + 1
    end   = j + 1
    while end < len(src) and src[end] in " \t": end += 1
    if end < len(src) and src[end] == "\n": end += 1
    src = src[:start] + src[end:]
    print("✅ تابع مردهٔ waitForPort حذف شد")
else:
    print("ℹ️  waitForPort قبلاً حذف شده بود")

# حذف import های یتیم‌شده
for imp in ("java.net.Socket", "java.net.InetSocketAddress"):
    tail = re.sub(r'^\s*import\s+' + re.escape(imp) + r'\s*$', '', src, flags=re.M)
    base = imp.split(".")[-1]
    if not re.search(r'\b' + base + r'\b', re.sub(r'^\s*import .*$', '', tail, flags=re.M)):
        if src != tail:
            src = tail
            print(f"✅ import بی‌مصرف حذف شد: {imp}")

src = re.sub(r'\n{3,}', '\n\n', src)

if src != orig:
    open(SVC + ".bak", "w", encoding="utf-8").write(orig)
    open(SVC, "w", encoding="utf-8").write(src)
    print("💾 V2rayVpnService.kt ذخیره شد (بکاپ: .bak)")
else:
    print("ℹ️  V2rayVpnService.kt تغییری نداشت")

print("-" * 60)

# ---------- ۲) حذف کد مردهٔ Tor در دارت ----------
for rel in DEAD:
    p = os.path.join(ROOT, rel)
    base = os.path.basename(rel)
    if not os.path.isfile(p):
        print(f"ℹ️  از قبل نبود: {base}"); continue

    # چک امنیتی: مطمئن شو جایی import نشده
    users = []
    for dp, _, fs in os.walk(os.path.join(ROOT, "lib")):
        for f in fs:
            if not f.endswith(".dart"): continue
            fp = os.path.join(dp, f)
            if os.path.abspath(fp) == os.path.abspath(p): continue
            try:
                if base in open(fp, encoding="utf-8").read():
                    users.append(os.path.relpath(fp, ROOT))
            except Exception:
                pass

    if users:
        print(f"⚠️  {base} حذف نشد چون استفاده شده در: {users}")
    else:
        os.rename(p, p + ".removed")
        print(f"🗑️  حذف شد (به .removed تغییر نام یافت): {rel}")

print("=" * 60)
print("✅ تمام. حالا دستور بعدی رو بزن.")
