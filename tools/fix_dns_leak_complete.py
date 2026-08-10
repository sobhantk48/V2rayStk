import re, shutil, os

# ───────────────────────────────────────────────
# 1) sing_box_config_generator.dart: DNS leak fix
# ───────────────────────────────────────────────
p = "lib/features/sing_box/application/sing_box_config_generator.dart"
src = open(p, encoding="utf-8").read()
shutil.copy(p, p + ".bak2")

# الف) proxy-dns: مطمئن شو آدرس udp://127.0.0.1:5353 هست (شاید پچ قبلی اعمال شده)
old_proxy_dns = "'address': 'tcp://1.1.1.1'"
new_proxy_dns = "'address': 'udp://127.0.0.1:5353'"
if old_proxy_dns in src:
    src = src.replace(old_proxy_dns, new_proxy_dns)
    print("FIXED: proxy-dns address -> udp://127.0.0.1:5353")
else:
    print("SKIP: proxy-dns already patched or not found")

# ب) حذف rule ای که outbound DNS رو direct می‌فرسته (منبع اصلی leak)
# این rule: {'outbound': ['any'], 'server': 'local-dns'}
old_rule = re.compile(
    r"\s*\{[\s\n]*'outbound':\s*\['any'\],[\s\n]*'server':\s*'local-dns',[\s\n]*\},",
    re.DOTALL
)
src2, n = old_rule.subn("", src)
if n > 0:
    src = src2
    print("FIXED: removed 'outbound any -> local-dns' DNS leak rule")
else:
    print("SKIP: any->local-dns rule not found (check manually)")

# ج) حذف ip_is_private -> direct (این هم می‌تونه leak ایجاد کنه وقتی Tor فعاله)
old_private = re.compile(
    r"\s*\{'ip_is_private':\s*true,\s*'outbound':\s*'direct'\},",
    re.DOTALL
)
src3, m = old_private.subn("", src)
if m > 0:
    src = src3
    print("FIXED: removed ip_is_private -> direct route rule")
else:
    print("SKIP: ip_is_private rule not found (check manually)")

open(p, "w", encoding="utf-8").write(src)
print("--- generator done ---")

# ───────────────────────────────────────────────
# 2) TorDaemon.kt: حذف waitForPort و import های Socket
# ───────────────────────────────────────────────
kt = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/TorDaemon.kt"
ksrc = open(kt, encoding="utf-8").read()
shutil.copy(kt, kt + ".bak2")

# حذف import های Socket که دیگه لازم نیستن
ksrc = re.sub(r'\s*import java\.net\.Socket\n', '\n', ksrc)
ksrc = re.sub(r'\s*import java\.net\.InetSocketAddress\n', '\n', ksrc)

# حذف تمام بلاک waitForPort (متد + صدا زدنش)
# حذف call سایت: if (waitForPort(...)) { ... } else { ... }
ksrc = re.sub(
    r'\s*Log\.i\(TAG,\s*"⏳ Waiting for Tor SOCKS port to open\.\.\."\)\s*'
    r'if\s*\(waitForPort\(9050,\s*30\)\)\s*\{[^}]*\}\s*else\s*\{[^}]*\}',
    '',
    ksrc, flags=re.DOTALL
)

# حذف تعریف متد waitForPort
ksrc = re.sub(
    r'\s*private fun waitForPort\(port: Int, maxRetries: Int\): Boolean \{.*?return false\s*\}',
    '',
    ksrc, flags=re.DOTALL
)

open(kt, "w", encoding="utf-8").write(ksrc)
print("FIXED: TorDaemon.kt - removed waitForPort + Socket imports")
print("--- TorDaemon done ---")
