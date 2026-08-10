#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پچ idempotent زنجیره torEnabled: Dart -> MainActivity -> V2rayVpnService"""
import pathlib, sys, re

rep = []
BASE = pathlib.Path("android/app/src/main/kotlin/com/example/v2ray_stk")

# ============================ MainActivity.kt ============================
p = BASE / "MainActivity.kt"
if not p.exists():
    sys.exit("!! MainActivity.kt پیدا نشد. از ریشه پروژه اجرا کن.")
s = p.read_text(encoding="utf-8"); o = s

# 0) حذف تعریف‌های تکراری احتمالی
lines, seen, out = s.split("\n"), False, []
for ln in lines:
    if ln.strip() == "private var pendingTorEnabled: Boolean = false":
        if seen:
            rep.append("MainActivity: تعریف تکراری pendingTorEnabled حذف شد")
            continue
        seen = True
    out.append(ln)
s = "\n".join(out)

# 1) افزودن فیلد
if not seen:
    s = s.replace(
        "    private var pendingConfig: String? = null",
        "    private var pendingConfig: String? = null\n"
        "    private var pendingTorEnabled: Boolean = false", 1)
    rep.append("MainActivity: فیلد pendingTorEnabled اضافه شد")

# 2) خواندن آرگومان از Dart
if 'call.argument<Boolean>("torEnabled")' not in s:
    s = s.replace(
        '                        prepareAndConnect(call.argument<String>("config") ?: "")',
        '                        prepareAndConnect(\n'
        '                            call.argument<String>("config") ?: "",\n'
        '                            call.argument<Boolean>("torEnabled") ?: false,\n'
        '                        )', 1)
    rep.append("MainActivity: آرگومان torEnabled از Dart خوانده شد")

# 3) امضای prepareAndConnect
if "private fun prepareAndConnect(config: String, torEnabled: Boolean)" not in s:
    s = s.replace(
        "    private fun prepareAndConnect(config: String) {\n"
        "        val prepareIntent = VpnService.prepare(this)\n"
        "        if (prepareIntent != null) {\n"
        "            pendingConfig = config\n"
        "            startActivityForResult(prepareIntent, vpnPrepareRequestCode)\n"
        "        } else {\n"
        "            startVpnService(config)\n"
        "        }\n"
        "    }",
        "    private fun prepareAndConnect(config: String, torEnabled: Boolean) {\n"
        "        val prepareIntent = VpnService.prepare(this)\n"
        "        if (prepareIntent != null) {\n"
        "            pendingConfig = config\n"
        "            pendingTorEnabled = torEnabled\n"
        "            startActivityForResult(prepareIntent, vpnPrepareRequestCode)\n"
        "        } else {\n"
        "            startVpnService(config, torEnabled)\n"
        "        }\n"
        "    }", 1)
    rep.append("MainActivity: prepareAndConnect پارامتر torEnabled گرفت")

# 4) امضای startVpnService + putExtra
if "private fun startVpnService(config: String, torEnabled: Boolean)" not in s:
    s = s.replace(
        "    private fun startVpnService(config: String) {",
        "    private fun startVpnService(config: String, torEnabled: Boolean) {", 1)
    rep.append("MainActivity: startVpnService پارامتر torEnabled گرفت")

if "EXTRA_TOR_ENABLED" not in s:
    s = s.replace(
        "            putExtra(V2rayVpnService.EXTRA_CONFIG, config)",
        "            putExtra(V2rayVpnService.EXTRA_CONFIG, config)\n"
        "            putExtra(V2rayVpnService.EXTRA_TOR_ENABLED, torEnabled)", 1)
    rep.append("MainActivity: EXTRA_TOR_ENABLED در Intent گذاشته شد")

# 5) onActivityResult
if 'startVpnService(pendingConfig ?: "", pendingTorEnabled)' not in s:
    s = s.replace(
        '                startVpnService(pendingConfig ?: "")',
        '                startVpnService(pendingConfig ?: "", pendingTorEnabled)', 1)
    rep.append("MainActivity: onActivityResult فلگ را پاس داد")

if "pendingTorEnabled = false\n        }" not in s:
    s = s.replace(
        "            pendingConfig = null\n        }",
        "            pendingConfig = null\n"
        "            pendingTorEnabled = false\n        }", 1)
    rep.append("MainActivity: ریست pendingTorEnabled")

if s != o:
    p.write_text(s, encoding="utf-8")

# ========================== V2rayVpnService.kt ==========================
p = BASE / "vpn/V2rayVpnService.kt"
if not p.exists():
    sys.exit("!! V2rayVpnService.kt پیدا نشد")
s = p.read_text(encoding="utf-8"); o = s

# حذف تکراری احتمالی ثابت
c = s.count('const val EXTRA_TOR_ENABLED = "extra_tor_enabled"')
if c > 1:
    s = s.replace('        const val EXTRA_TOR_ENABLED = "extra_tor_enabled"\n', "", c - 1)
    rep.append("Service: ثابت تکراری حذف شد")

# 1) ثابت
if "EXTRA_TOR_ENABLED" not in s:
    s = s.replace(
        '        const val EXTRA_CONFIG = "extra_config"',
        '        const val EXTRA_CONFIG = "extra_config"\n'
        '        const val EXTRA_TOR_ENABLED = "extra_tor_enabled"', 1)
    rep.append("Service: ثابت EXTRA_TOR_ENABLED اضافه شد")

# 2) خواندن از Intent در onStartCommand
if "getBooleanExtra(EXTRA_TOR_ENABLED" not in s:
    s = s.replace(
        "                val config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()\n"
        "                startVpn(config)",
        "                val config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()\n"
        "                val torEnabled =\n"
        "                    intent?.getBooleanExtra(EXTRA_TOR_ENABLED, false) ?: false\n"
        "                startVpn(config, torEnabled)", 1)
    rep.append("Service: torEnabled از Intent خوانده شد")

# 3) امضای startVpn
if "private fun startVpn(config: String, torEnabled: Boolean)" not in s:
    s = s.replace(
        "    private fun startVpn(config: String) {",
        "    private fun startVpn(config: String, torEnabled: Boolean) {", 1)
    rep.append("Service: امضای startVpn اصلاح شد")

# 4) شرطی‌کردن اجرای Tor
if "if (torEnabled) {" not in s:
    s = s.replace(
        "            torDaemon = TorDaemon(this@V2rayVpnService)\n"
        "            torDaemon?.start()",
        "            if (torEnabled) {\n"
        "                Log.d(TAG, \"Tor فعال است، در حال اجرای دیمون\")\n"
        "                torDaemon = TorDaemon(this@V2rayVpnService)\n"
        "                torDaemon?.start()\n"
        "            } else {\n"
        "                Log.d(TAG, \"Tor غیرفعال است، از اجرا صرف‌نظر شد\")\n"
        "            }", 1)
    rep.append("Service: اجرای Tor مشروط شد")

# 5) اصلاح stopVpn (تفکیک runCatching + null کردن)
if "torDaemon = null" not in s:
    s = s.replace(
        "        runCatching {\n"
        "            SingBoxBridge.stop()\n"
        "            torDaemon?.stop()\n"
        "        }",
        "        runCatching { SingBoxBridge.stop() }\n"
        "        runCatching { torDaemon?.stop() }\n"
        "        torDaemon = null", 1)
    rep.append("Service: stopVpn اصلاح و torDaemon تهی شد")

if s != o:
    p.write_text(s, encoding="utf-8")

# ============================ گزارش نهایی ============================
print("=" * 55)
if rep:
    for r in rep:
        print(" ✔", r)
else:
    print(" ! تغییری لازم نبود (قبلاً پچ شده)")
print("=" * 55)
