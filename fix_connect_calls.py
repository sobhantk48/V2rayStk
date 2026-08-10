#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""تزریق torEnabled به همه فراخوانی‌های _service.connect( با اسکن پرانتز — idempotent"""
import pathlib, re, subprocess, sys

p = pathlib.Path("lib/features/vpn/application/vpn_controller.dart")
if not p.exists():
    sys.exit("!! vpn_controller.dart نیست. از ریشه پروژه اجرا کن.")

s = p.read_text(encoding="utf-8")
KEY = "_service.connect("
out, i, n, skipped = [], 0, 0, 0

while True:
    j = s.find(KEY, i)
    if j < 0:
        out.append(s[i:])
        break
    k = j + len(KEY)
    depth = 1
    while k < len(s) and depth:
        if s[k] == '(':
            depth += 1
        elif s[k] == ')':
            depth -= 1
        k += 1
    inner = s[j + len(KEY):k - 1]
    if "torEnabled" in inner:
        out.append(s[i:k])
        skipped += 1
    else:
        core = inner.rstrip().rstrip(',')
        out.append(s[i:j] + KEY + core +
                   ",\n        torEnabled: await _isTorEnabled(),\n      )")
        n += 1
    i = k

new = "".join(out)
if new != s:
    p.write_text(new, encoding="utf-8")

print("=" * 58)
print(f" ✔ اصلاح‌شده : {n}")
print(f" • از قبل OK : {skipped}")
print("=" * 58)
print("\n>>> محل‌های فراخوانی بعد از پچ:")
subprocess.run(["grep", "-n", "-A3", "_service.connect(", str(p)])
print("\n>>> وضعیت Kotlin (prepareAndConnect / startVpnService):")
subprocess.run(["grep", "-rn", "prepareAndConnect\\|fun startVpnService\\|pendingTorEnabled\\|EXTRA_TOR_ENABLED",
                "android/app/src/main/kotlin/com/example/v2ray_stk/"])
