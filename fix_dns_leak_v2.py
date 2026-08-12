#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""سخت‌سازی DNS در sing_box_config_generator.dart (ضد نشتی، مخصوص حالت Tor)"""
import re, shutil, sys, pathlib

P = pathlib.Path("lib/features/sing_box/application/sing_box_config_generator.dart")
if not P.exists():
    sys.exit("!! فایل پیدا نشد: %s" % P)

src = P.read_text(encoding="utf-8")
shutil.copy(P, str(P) + ".dnsleak.bak")
ok, skip = [], []

# ۱) strict_route در حالت Tor روشن شود
if "'strict_route': isTor," in src:
    skip.append("1/strict_route")
else:
    new, n = re.subn(r"'strict_route':\s*false\s*,", "'strict_route': isTor,", src, count=1)
    if n: src, _ = new, ok.append("1/strict_route -> isTor")
    else: skip.append("1/strict_route (الگو پیدا نشد)")

# ۲) دامنه‌های محلی در حالت Tor به block-dns بروند نه 8.8.8.8
if "isTor ? 'block-dns' : 'bootstrap-dns'" in src:
    skip.append("2/local-suffix")
else:
    pat = re.compile(
        r"(\{\s*\n\s*'domain_suffix':\s*<String>\[\s*'\.local',\s*'\.lan',\s*'\.home'\s*\],\s*\n\s*'server':\s*)'bootstrap-dns'")
    new, n = pat.subn(r"\1isTor ? 'block-dns' : 'bootstrap-dns'", src, count=1)
    if n: src, _ = new, ok.append("2/local-suffix -> block-dns در Tor")
    else: skip.append("2/local-suffix (الگو پیدا نشد)")

# ۳) strategy برای bootstrap-dns
pat = re.compile(r"('tag':\s*'bootstrap-dns',\s*\n\s*'address':\s*'8\.8\.8\.8',\s*\n)(\s*)('detour':\s*'direct',)")
if re.search(r"'tag':\s*'bootstrap-dns',[\s\S]{0,120}?'strategy'", src):
    skip.append("3/bootstrap-strategy")
else:
    new, n = pat.subn(r"\1\2'strategy': 'ipv4_only',\n\2\3", src, count=1)
    if n: src, _ = new, ok.append("3/bootstrap-dns strategy=ipv4_only")
    else: skip.append("3/bootstrap-strategy (الگو پیدا نشد)")

# ۴) strategy برای proxy-dns تور (5353)
pat = re.compile(r"('address':\s*'udp://127\.0\.0\.1:5353',\s*\n)(\s*)('detour':\s*'direct',)")
if re.search(r"udp://127\.0\.0\.1:5353',[\s\S]{0,120}?'strategy'", src):
    skip.append("4/tor-dns-strategy")
else:
    new, n = pat.subn(r"\1\2'strategy': 'ipv4_only',\n\2\3", src, count=1)
    if n: src, _ = new, ok.append("4/tor proxy-dns strategy=ipv4_only")
    else: skip.append("4/tor-dns-strategy (الگو پیدا نشد)")

# ۵) بلاک پورت 853 (DoT) تا اپ‌ها DNS داخلی را دور نزنند
if "<int>[853]" in src:
    skip.append("5/dot-block")
else:
    pat = re.compile(r"(\{\s*\n(\s*)'port':\s*<int>\[53\],\s*\n\s*'outbound':\s*'dns-out'\s*\n\s*\},\n)")
    def rep(m):
        body, ind = m.group(1), m.group(2)
        base = ind[:-2] if len(ind) >= 2 else ind
        return (body
                + f"{base}// DoT/853 مسدود می‌شود تا اپ‌ها مجبور به استفاده از DNS داخلی شوند\n"
                + f"{base}{{\n{ind}'port': <int>[853],\n{ind}'outbound': 'block'\n{base}}},\n")
    new, n = pat.subn(rep, src, count=1)
    if n: src, _ = new, ok.append("5/بلاک پورت 853")
    else: skip.append("5/dot-block (الگو پیدا نشد)")

P.write_text(src, encoding="utf-8")
print("=== اعمال شد ===")
for i in ok: print("  ✔", i)
if skip:
    print("=== رد شد/قبلاً بود ===")
    for i in skip: print("  •", i)
print("\nبکاپ: %s.dnsleak.bak" % P)
