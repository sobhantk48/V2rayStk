#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Hard Gate برای Tor:
1) تایم‌اوت بوت‌استرپ: 90_000L -> 300_000L
2) اگر Tor به 100% نرسید، sing-box استارت نشود و اتصال تمیز قطع شود
"""
import re, shutil, sys
from datetime import datetime
from pathlib import Path

SRC = Path("android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt")

def main():
    if not SRC.exists():
        print(f"[x] پیدا نشد: {SRC}"); sys.exit(1)
    text = SRC.read_text(encoding="utf-8")
    orig = text
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = SRC.with_suffix(SRC.suffix + f".hardgate.bak_{ts}")
    shutil.copy2(SRC, bak)
    print(f"== بکاپ: {bak}")

    # --- 1) تایم‌اوت ---
    if "TOR_BOOTSTRAP_TIMEOUT_MS = 300_000L" in text:
        print("   [skip] تایم‌اوت قبلا 300s بود")
    else:
        new, n = re.subn(
            r"(TOR_BOOTSTRAP_TIMEOUT_MS\s*=\s*)90_000L",
            r"\g<1>300_000L", text)
        if n:
            text = new
            print("   [ok] تایم‌اوت 90s -> 300s")
        else:
            print("   [!] الگوی تایم‌اوت پیدا نشد")

    # --- 2) hard gate ---
    if "HARD_GATE_V1" in text:
        print("   [skip] hard gate قبلا اعمال شده")
    else:
        old_block = """                    val waiting = pendingTun
                    if (waiting == null) {
                        Log.w(TAG, "tun معلق موجود نیست، استارت هسته لغو شد")
                        return@post
                    }
                    pendingTun = null

                    if (ok) {
                        Log.i(TAG, "Tor آماده است (100%)، استارت sing-box")
                    } else {
                        Log.w(
                            TAG,
                            "Tor آماده نشد (${daemon.bootstrapPercent}%)، sing-box با احتمال خطا استارت می‌شود",
                        )
                    }
                    updateNotification("VPN در حال اجرا")
                    launchCore(waiting, config)"""

        new_block = """                    // HARD_GATE_V1
                    val waiting = pendingTun
                    if (waiting == null) {
                        Log.w(TAG, "tun معلق موجود نیست، استارت هسته لغو شد")
                        return@post
                    }

                    if (!ok) {
                        val pct = runCatching { daemon.bootstrapPercent }.getOrDefault(0)
                        Log.e(
                            TAG,
                            "Tor به 100% نرسید (" + pct + "%) — استارت sing-box لغو شد",
                        )
                        updateNotification("Tor آماده نشد (" + pct + "%) — اتصال قطع شد")
                        setStatus(VpnStatus.DISCONNECTED)
                        stopVpn()
                        return@post
                    }

                    pendingTun = null
                    Log.i(TAG, "Tor آماده است (100%)، استارت sing-box")
                    updateNotification("VPN در حال اجرا")
                    launchCore(waiting, config)"""

        if old_block in text:
            text = text.replace(old_block, new_block, 1)
            print("   [ok] hard gate اعمال شد")
        else:
            print("   [x] بلاک اصلی پیدا نشد — فایل دستکاری شده؟")
            sys.exit(2)

    if text == orig:
        print("== تغییری لازم نبود"); return
    SRC.write_text(text, encoding="utf-8")
    print(f"== نوشته شد: {SRC}")

if __name__ == "__main__":
    main()
