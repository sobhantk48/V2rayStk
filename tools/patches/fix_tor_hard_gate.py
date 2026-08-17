#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hard Gate تور - نسخهٔ خط‌محور (مقاوم به تفاوت متن)

منطق: در بلوک انتظار بوت‌استرپ، از خط «if (ok)» تا خط
«launchCore(waiting, config)» را پیدا می‌کند و کل آن را با
گیت سخت جایگزین می‌کند. به متن دقیق پیام‌ها وابسته نیست.
"""
import io
import os
import sys
import datetime

TARGET = os.path.join(
    "android", "app", "src", "main", "kotlin",
    "com", "example", "v2ray_stk", "vpn", "V2rayVpnService.kt",
)

MARKER = "اتصال تور ناموفق بود"

if not os.path.isfile(TARGET):
    print("[FATAL] فایل پیدا نشد: " + TARGET)
    sys.exit(1)

with io.open(TARGET, "r", encoding="utf-8") as fh:
    lines = fh.readlines()

joined = "".join(lines)

if MARKER in joined and "return@post" in joined:
    print("[SKIP] گیت سخت تور از قبل وجود دارد، تغییری لازم نیست.")
    sys.exit(0)


def dump(a, b, tag):
    print("---- " + tag + " ----")
    lo = max(0, a)
    hi = min(len(lines), b)
    for i in range(lo, hi):
        print("%4d| %s" % (i + 1, lines[i].rstrip("\n")))
    print("---- end ----")


# پیدا کردن خط launchCore(waiting, config)
end_idx = -1
for i, ln in enumerate(lines):
    if "launchCore(waiting" in ln:
        end_idx = i
        break

if end_idx < 0:
    print("[FATAL] خط launchCore(waiting, config) پیدا نشد.")
    dump(185, 245, "ناحیهٔ مشکوک")
    sys.exit(2)

# عقب‌گرد تا خط if (ok)
start_idx = -1
for i in range(end_idx, max(-1, end_idx - 40), -1):
    stripped = lines[i].strip()
    if stripped.startswith("if (ok)") or stripped.startswith("if (!ok)"):
        start_idx = i
        break

if start_idx < 0:
    print("[FATAL] خط «if (ok)» در ۴۰ خط قبل از launchCore پیدا نشد.")
    dump(end_idx - 40, end_idx + 5, "ناحیهٔ واقعی فایل")
    sys.exit(3)

print("[FOUND] بلوک هدف: خط " + str(start_idx + 1) + " تا " + str(end_idx + 1))
dump(start_idx, end_idx + 1, "متن فعلی (قبل از تغییر)")

old_block = lines[start_idx:end_idx + 1]
old_text = "".join(old_block)

if "launchCore(waiting" not in old_text:
    print("[FATAL] بلوک استخراج‌شده معتبر نیست.")
    sys.exit(4)

# تشخیص تو رفتگی از خود خط if
indent = lines[start_idx][: len(lines[start_idx]) - len(lines[start_idx].lstrip())]
u = indent + "    "

new_block = [
    indent + "if (!ok) {\n",
    u + "Log.e(\n",
    u + "    TAG,\n",
    u + "    \"Tor آماده نشد (${daemon.bootstrapPercent}%)، اتصال لغو شد\",\n",
    u + ")\n",
    u + "runCatching { waiting.close() }\n",
    u + "updateNotification(\"" + MARKER + "\")\n",
    u + "setStatus(VpnStatus.DISCONNECTED)\n",
    u + "stopVpn()\n",
    u + "return@post\n",
    indent + "}\n",
    "\n",
    indent + "Log.i(TAG, \"Tor آماده است (100%)، استارت sing-box\")\n",
    indent + "updateNotification(\"VPN در حال اجرا\")\n",
    indent + "launchCore(waiting, config)\n",
]

stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
backup = TARGET + ".hardgate.bak_" + stamp
with io.open(backup, "w", encoding="utf-8") as fh:
    fh.write(joined)
print("[BACKUP] " + backup)

new_lines = lines[:start_idx] + new_block + lines[end_idx + 1:]

with io.open(TARGET, "w", encoding="utf-8") as fh:
    fh.write("".join(new_lines))

print("[WRITE] " + TARGET)
print("")

lines = new_lines
dump(start_idx - 4, start_idx + len(new_block) + 4, "متن جدید (بعد از تغییر)")

# بررسی تعادل آکولاد کل فایل
text = "".join(new_lines)
opens = text.count("{")
closes = text.count("}")
print("")
print("آکولاد باز: " + str(opens) + " | بسته: " + str(closes))
if opens != closes:
    print("[هشدار] آکولادها نامتعادل است. بکاپ:")
    print("  cp '" + backup + "' '" + TARGET + "'")
    sys.exit(5)

print("[OK] گیت سخت تور اعمال شد.")
