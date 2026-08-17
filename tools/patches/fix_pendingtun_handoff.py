#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
بازگرداندن pendingTun = null در مسیر موفق bootstrap
(واگذاری مالکیت fd به launchCore، مثل نسخهٔ اصلی)
"""
import io
import os
import sys
import datetime

TARGET = os.path.join(
    "android", "app", "src", "main", "kotlin",
    "com", "example", "v2ray_stk", "vpn", "V2rayVpnService.kt",
)

if not os.path.isfile(TARGET):
    print("[FATAL] فایل پیدا نشد: " + TARGET)
    sys.exit(1)

with io.open(TARGET, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

# پیدا کردن خط launchCore(waiting, config)
target_idx = -1
for i, ln in enumerate(lines):
    if "launchCore(waiting" in ln:
        target_idx = i
        break

if target_idx < 0:
    print("[FATAL] خط launchCore(waiting, config) پیدا نشد.")
    sys.exit(2)

# بررسی idempotency: آیا در ۶ خط قبل، pendingTun = null هست؟
window = "".join(lines[max(0, target_idx - 6):target_idx])
if "pendingTun = null" in window:
    print("[SKIP] pendingTun = null از قبل در مسیر موفق وجود دارد.")
    sys.exit(0)

# تشخیص تورفتگی از خط launchCore
indent = lines[target_idx][: len(lines[target_idx]) - len(lines[target_idx].lstrip())]

# قبل از خطِ «Log.i(... Tor آماده است ...)» یا مستقیماً قبل launchCore درج می‌کنیم.
# سراغ خط Log.i در بالای launchCore می‌رویم.
insert_at = target_idx
for j in range(target_idx, max(-1, target_idx - 6), -1):
    if "Tor آماده است" in lines[j] and "Log.i" in lines[j]:
        insert_at = j
        break

print("[INFO] درج pendingTun = null قبل از خط " + str(insert_at + 1))

stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
backup = TARGET + ".handoff.bak_" + stamp
with io.open(backup, "w", encoding="utf-8") as fh:
    fh.write("".join(lines))
print("[BACKUP] " + backup)

new_line = indent + "pendingTun = null\n"
lines = lines[:insert_at] + [new_line] + lines[insert_at:]

with io.open(TARGET, "w", encoding="utf-8") as fh:
    fh.write("".join(lines))

# چاپ نتیجه
lo = max(0, insert_at - 6)
hi = min(len(lines), insert_at + 6)
print("---- نتیجه ----")
for i in range(lo, hi):
    print("%4d| %s" % (i + 1, lines[i].rstrip("\n")))
print("---- end ----")

text = "".join(lines)
print("آکولاد باز: %d | بسته: %d" % (text.count("{"), text.count("}")))
print("[OK] pendingTun = null بازگردانده شد.")
