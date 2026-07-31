#!/usr/bin/env python3
import re, sys, pathlib, shutil

PATH = pathlib.Path("lib/features/sing_box/application/sing_box_config_generator.dart")
USE_REJECT = "--reject" in sys.argv

if not PATH.exists():
    print("!! فایل پیدا نشد:", PATH); sys.exit(1)

src = PATH.read_text(encoding="utf-8")
orig = src
changes = []

def sub(pattern, repl, label, count=0):
    global src
    new, n = re.subn(pattern, repl, src, count=count)
    if n:
        src = new
        changes.append("%-42s x%d" % (label, n))
    return n

# 1) DNS strategy: ipv4_only -> prefer_ipv4
sub(r"'strategy'\s*:\s*'ipv4_only'", "'strategy': 'prefer_ipv4'",
    "dns.strategy -> prefer_ipv4")

# 2) tun.domain_strategy: ipv4_only -> prefer_ipv4
sub(r"'domain_strategy'\s*:\s*'ipv4_only'", "'domain_strategy': 'prefer_ipv4'",
    "domain_strategy -> prefer_ipv4")

# 3) tun.stack: gvisor -> system  (EIN فقط روی system جواب می‌دهد)
sub(r"'stack'\s*:\s*'gvisor'", "'stack': 'system'", "tun.stack -> system")

# 4) افزودن mtu و endpoint_independent_nat بعد از stack
if "'mtu'" not in src:
    sub(r"('stack'\s*:\s*'system'\s*,)",
        r"\1\n        'mtu': 9000,\n        'endpoint_independent_nat': true,",
        "tun: mtu + endpoint_independent_nat", count=1)

# 5) قوانین QUIC / UDP-443
if USE_REJECT:
    sub(r"\{\s*'protocol'\s*:\s*'quic'\s*,\s*'outbound'\s*:\s*'block'\s*\}",
        "{'protocol': 'quic', 'action': 'reject'}", "quic -> action: reject")
    sub(r"\{\s*'network'\s*:\s*'udp'\s*,\s*'port'\s*:\s*\[\s*443\s*\]\s*,\s*'outbound'\s*:\s*'block'\s*\}",
        "{'network': 'udp', 'port': [443], 'action': 'reject'}", "udp/443 -> action: reject")

if src == orig:
    print(">> هیچ تغییری اعمال نشد. خطوط مرتبط فعلی:")
    for i, line in enumerate(orig.splitlines(), 1):
        if any(k in line for k in ("ipv4_only", "gvisor", "quic", "'block'", "mtu", "stack")):
            print("   %4d | %s" % (i, line.rstrip()))
    sys.exit(2)

shutil.copy(PATH, str(PATH) + ".bak")
PATH.write_text(src, encoding="utf-8")
print(">> پشتیبان:", str(PATH) + ".bak")
print(">> تغییرات اعمال‌شده:")
for c in changes:
    print("   -", c)
