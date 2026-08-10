#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""تزریق EXTRA_KILL_SWITCH و اتصال آن به onStartCommand در V2rayVpnService.kt"""
import re, shutil, sys, pathlib

F = pathlib.Path("android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt")
if not F.exists():
    sys.exit("!! فایل پیدا نشد: %s" % F)

src = F.read_text(encoding="utf-8")
orig = src
shutil.copy2(F, ".trash_bak/V2rayVpnService.kt.bak_killswitch")

# ---------- 1) const val EXTRA_KILL_SWITCH ----------
if "EXTRA_KILL_SWITCH" not in src:
    m = re.search(r'([ \t]*)const val EXTRA_TOR_ENABLED\s*=\s*"[^"]*"\s*\n', src)
    if not m:
        sys.exit("!! EXTRA_TOR_ENABLED پیدا نشد؛ دستی لازمه")
    indent = m.group(1)
    src = src[:m.end()] + f'{indent}const val EXTRA_KILL_SWITCH = "extra_kill_switch"\n' + src[m.end():]
    print("[1] OK  const val EXTRA_KILL_SWITCH اضافه شد")
else:
    print("[1] SKIP EXTRA_KILL_SWITCH از قبل بود")

# ---------- 2) خواندن extra در onStartCommand ----------
if re.search(r'getBooleanExtra\(\s*EXTRA_KILL_SWITCH', src):
    print("[2] SKIP خواندن extra از قبل بود")
else:
    m = re.search(
        r'([ \t]*)val torEnabled\s*=\s*intent\?\.getBooleanExtra\(\s*EXTRA_TOR_ENABLED\s*,\s*false\s*\)\s*\?:\s*false\s*\n',
        src)
    if not m:
        sys.exit("!! خط torEnabled در onStartCommand پیدا نشد")
    indent = m.group(1)
    inject = (f'{indent}val killSwitch = intent?.getBooleanExtra('
              f'EXTRA_KILL_SWITCH, false) ?: false\n')
    src = src[:m.end()] + inject + src[m.end():]
    print("[2] OK  val killSwitch اضافه شد")

# ---------- 3) پاس دادن به startVpn ----------
if re.search(r'startVpn\(\s*config\s*,\s*torEnabled\s*,\s*killSwitch\s*\)', src):
    print("[3] SKIP startVpn از قبل killSwitch می‌گرفت")
else:
    new, n = re.subn(r'startVpn\(\s*config\s*,\s*torEnabled\s*\)',
                     'startVpn(config, torEnabled, killSwitch)', src)
    if n == 0:
        sys.exit("!! فراخوانی startVpn(config, torEnabled) پیدا نشد")
    src = new
    print(f"[3] OK  {n} فراخوانی startVpn پچ شد")

if src != orig:
    F.write_text(src, encoding="utf-8")
    print("\n>> فایل نوشته شد. بکاپ: .trash_bak/V2rayVpnService.kt.bak_killswitch")
else:
    print("\n>> هیچ تغییری لازم نبود.")
