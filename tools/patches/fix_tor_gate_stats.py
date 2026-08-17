#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
اصلاح سه ایراد در V2rayVpnService.kt:
 1) bridgeWatch بعد از سالم شدن کامل می‌مرد -> heartbeat دائمی
 2) بعد از BRIDGE_MAX_RETRY کل پایش می‌ایستاد -> پایش کند ادامه می‌یابد
 3) Hard Gate تور: اگر bootstrap ناموفق بود، sing-box استارت نشود
 4) ریست و استارت/استاپ StatsProvider و VpnStatsStore در چرخهٔ اتصال
اسکریپت idempotent است؛ اجرای دوباره چیزی را خراب نمی‌کند.
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
    src = fh.read()

original = src
stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
backup = TARGET + ".torgate.bak_" + stamp
with io.open(backup, "w", encoding="utf-8") as fh:
    fh.write(original)
print("[BACKUP] " + backup)

applied = []
skipped = []
failed = []


def patch(name, old, new):
    """جایگزینی دقیق با انکر verbatim، همراه بررسی idempotency."""
    global src
    if new in src:
        skipped.append(name + " (قبلا اعمال شده)")
        return
    count = src.count(old)
    if count == 0:
        failed.append(name + " (انکر پیدا نشد)")
        return
    if count > 1:
        failed.append(name + " (انکر " + str(count) + " بار تکرار شده)")
        return
    src = src.replace(old, new, 1)
    applied.append(name)


# ---------------------------------------------------------------- 1
old1 = '        private const val BRIDGE_MAX_RETRY = 10\n'
new1 = (
    '        private const val BRIDGE_MAX_RETRY = 10\n'
    '\n'
    '        // فاصلهٔ ضربان سلامت پس از سالم شدن bridge\n'
    '        private const val BRIDGE_HEARTBEAT_MS = 15_000L\n'
)
patch("1) افزودن BRIDGE_HEARTBEAT_MS", old1, new1)

# ---------------------------------------------------------------- 2
old2 = (
    '            if (healthy) {\n'
    '                Log.d(TAG, "bridge سالم است و داده دریافت می\u200cشود")\n'
    '                return\n'
    '            }\n'
)
new2 = (
    '            if (healthy) {\n'
    '                Log.d(TAG, "bridge سالم است و داده دریافت می\u200cشود")\n'
    '                bridgeRetry = 0\n'
    '                mainHandler.postDelayed(this, BRIDGE_HEARTBEAT_MS)\n'
    '                return\n'
    '            }\n'
)
patch("2) heartbeat دائمی bridgeWatch", old2, new2)

# ---------------------------------------------------------------- 3
old3 = (
    '            if (bridgeRetry >= BRIDGE_MAX_RETRY) {\n'
    '                Log.w(TAG, "bridge پس از $BRIDGE_MAX_RETRY تلاش داده\u200cای نداد، توقف تلاش")\n'
    '                return\n'
    '            }\n'
)
new3 = (
    '            if (bridgeRetry >= BRIDGE_MAX_RETRY) {\n'
    '                Log.w(TAG, "bridge پس از $BRIDGE_MAX_RETRY تلاش داده\u200cای نداد، پایش کند ادامه دارد")\n'
    '                mainHandler.postDelayed(this, BRIDGE_HEARTBEAT_MS)\n'
    '                return\n'
    '            }\n'
)
patch("3) ادامهٔ پایش کند بعد از سقف تلاش", old3, new3)

# ---------------------------------------------------------------- 4
old4 = (
    '                    if (ok) {\n'
    '                        Log.i(TAG, "Tor آماده است (100%)، استارت sing-box")\n'
    '                    } else {\n'
    '                        Log.w(\n'
    '                            TAG,\n'
    '                            "Tor آماده نشد (${daemon.bootstrapPercent}%)، sing-box با احتمال خطا استارت می\u200cشود",\n'
    '                        )\n'
    '                    }\n'
    '                    updateNotification("VPN در حال اجرا")\n'
    '                    launchCore(waiting, config)\n'
)
new4 = (
    '                    if (!ok) {\n'
    '                        Log.e(\n'
    '                            TAG,\n'
    '                            "Tor آماده نشد (${daemon.bootstrapPercent}%)، اتصال لغو شد",\n'
    '                        )\n'
    '                        runCatching { waiting.close() }\n'
    '                        updateNotification("اتصال تور ناموفق بود")\n'
    '                        setStatus(VpnStatus.DISCONNECTED)\n'
    '                        stopVpn()\n'
    '                        return@post\n'
    '                    }\n'
    '\n'
    '                    Log.i(TAG, "Tor آماده است (100%)، استارت sing-box")\n'
    '                    updateNotification("VPN در حال اجرا")\n'
    '                    launchCore(waiting, config)\n'
)
patch("4) Hard Gate تور", old4, new4)

# ---------------------------------------------------------------- 5
old5 = '            SingBoxBridge.start(this, coreFd, config)\n'
new5 = (
    '            // آمار قدیمی نباید روی اتصال جدید نمایش داده شود\n'
    '            runCatching { VpnStatsStore.reset() }\n'
    '            runCatching { StatsProvider.reset() }\n'
    '\n'
    '            SingBoxBridge.start(this, coreFd, config)\n'
)
patch("5) ریست آمار پیش از استارت هسته", old5, new5)

# ---------------------------------------------------------------- 6
old6 = (
    '            setStatus(VpnStatus.CONNECTED)\n'
    '            startBridgeWatch()\n'
)
new6 = (
    '            setStatus(VpnStatus.CONNECTED)\n'
    '            startBridgeWatch()\n'
    '            runCatching { StatsProvider.start() }\n'
    '                .onFailure { Log.w(TAG, "StatsProvider.start() failed: ${it.message}") }\n'
)
patch("6) استارت StatsProvider بعد از اتصال", old6, new6)

# ---------------------------------------------------------------- 7
old7 = (
    '        stopBridge()\n'
    '\n'
    '        runCatching { SingBoxBridge.stop() }\n'
)
new7 = (
    '        runCatching { StatsProvider.stop() }\n'
    '            .onFailure { Log.w(TAG, "StatsProvider.stop() failed: ${it.message}") }\n'
    '\n'
    '        stopBridge()\n'
    '\n'
    '        runCatching { SingBoxBridge.stop() }\n'
)
patch("7) توقف StatsProvider در teardown", old7, new7)

# ---------------------------------------------------------------- 8
old8 = (
    '        setStatus(VpnStatus.DISCONNECTED)\n'
    '\n'
    '        runCatching {\n'
    '            val manager =\n'
)
new8 = (
    '        setStatus(VpnStatus.DISCONNECTED)\n'
    '\n'
    '        runCatching { StatsProvider.reset() }\n'
    '        runCatching { VpnStatsStore.reset() }\n'
    '\n'
    '        runCatching {\n'
    '            val manager =\n'
)
patch("8) پاک‌سازی آمار پس از قطع", old8, new8)

# ---------------------------------------------------------------- write
if src != original:
    with io.open(TARGET, "w", encoding="utf-8") as fh:
        fh.write(src)
    print("[WRITE] " + TARGET)
else:
    print("[WRITE] تغییری لازم نبود، فایل دست‌نخورده ماند")

print("")
print("=== گزارش ===")
for item in applied:
    print("  [OK]   " + item)
for item in skipped:
    print("  [SKIP] " + item)
for item in failed:
    print("  [MISS] " + item)
print("")
print("اعمال‌شده: " + str(len(applied)) +
      " | رد‌شده: " + str(len(skipped)) +
      " | ناموفق: " + str(len(failed)))

if failed:
    print("")
    print("[هشدار] بعضی انکرها نچسبیدند. اگر لازم شد بکاپ را برگردان:")
    print("  cp '" + backup + "' '" + TARGET + "'")
    sys.exit(2)
