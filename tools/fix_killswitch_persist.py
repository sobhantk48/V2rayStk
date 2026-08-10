#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
پچ نهایی Kill Switch + Always-On:
  1) ساخت VpnPrefs.kt (ذخیره دائمی config و فلگ‌ها)
  2) سیم‌کشی کامل alwaysOnVpn در MainActivity.kt
  3) بازیابی/ذخیره فلگ‌ها در V2rayVpnService.kt برای استارت بدون Intent
اجرای دوباره امن است (idempotent).
"""
import io, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KOTLIN = os.path.join(ROOT, "android/app/src/main/kotlin/com/example/v2ray_stk")
MAIN = os.path.join(KOTLIN, "MainActivity.kt")
SVC = os.path.join(KOTLIN, "vpn/V2rayVpnService.kt")
PREFS = os.path.join(KOTLIN, "vpn/VpnPrefs.kt")


def read(p):
    with io.open(p, "r", encoding="utf-8") as f:
        return f.read()


def write(p, s):
    with io.open(p, "w", encoding="utf-8") as f:
        f.write(s)


def replace_once(text, old, new, label):
    if new in text and old not in text:
        print("  [skip] از قبل اعمال شده: " + label)
        return text
    c = text.count(old)
    if c != 1:
        print("  [ERROR] '%s' پیدا نشد یا چندبار بود (count=%d)" % (label, c))
        sys.exit(1)
    print("  [ok] " + label)
    return text.replace(old, new, 1)


# ---------------------------------------------------------------- 1) VpnPrefs.kt
VPNPREFS_SRC = '''package com.example.v2ray_stk.vpn

import android.content.Context

/**
 * ذخیره‌سازی دائمی کانفیگ و فلگ‌های VPN در SharedPreferences.
 *
 * هدف: سناریوهای استارت خودکار سیستم (ریبوت دستگاه یا Always-On سیستمی) که در آن‌ها
 * Android سرویس را با intent == null بالا می‌آورد و هیچ داده‌ای در Intent وجود ندارد.
 * در این حالت آخرین کانفیگ و فلگ‌ها از این‌جا بازیابی می‌شوند.
 */
object VpnPrefs {
    private const val PREFS_NAME = "vpn_prefs"
    private const val KEY_CONFIG = "config"
    private const val KEY_TOR_ENABLED = "tor_enabled"
    private const val KEY_KILL_SWITCH = "kill_switch"
    private const val KEY_ALWAYS_ON = "always_on"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(
        context: Context,
        config: String,
        torEnabled: Boolean,
        killSwitch: Boolean,
        alwaysOnVpn: Boolean,
    ) {
        prefs(context).edit()
            .putString(KEY_CONFIG, config)
            .putBoolean(KEY_TOR_ENABLED, torEnabled)
            .putBoolean(KEY_KILL_SWITCH, killSwitch)
            .putBoolean(KEY_ALWAYS_ON, alwaysOnVpn)
            .apply()
    }

    /** پس از قطع دستی توسط کاربر صدا زده می‌شود تا ریبوت باعث اتصال خودسر نشود. */
    fun clear(context: Context) {
        prefs(context).edit().clear().apply()
    }

    fun config(context: Context): String =
        prefs(context).getString(KEY_CONFIG, "").orEmpty()

    fun torEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_TOR_ENABLED, false)

    fun killSwitch(context: Context): Boolean =
        prefs(context).getBoolean(KEY_KILL_SWITCH, false)

    fun alwaysOnVpn(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ALWAYS_ON, false)
}
'''

if os.path.exists(PREFS):
    print("VpnPrefs.kt از قبل وجود دارد -> بازنویسی می‌شود")
write(PREFS, VPNPREFS_SRC)
print("[ok] VpnPrefs.kt نوشته شد")

# ---------------------------------------------------------------- 2) MainActivity.kt
print("\nMainActivity.kt:")
m = read(MAIN)

# 2.1 فراخوانی prepareAndConnect در بلاک connect
m = replace_once(
    m,
    '''                        prepareAndConnect(
                            call.argument<String>("config") ?: "",
                            pendingTorEnabled,
                            pendingKillSwitch,
                        )''',
    '''                        prepareAndConnect(
                            call.argument<String>("config") ?: "",
                            pendingTorEnabled,
                            pendingKillSwitch,
                            pendingAlwaysOnVpn,
                        )''',
    "فراخوانی prepareAndConnect با alwaysOnVpn",
)

# 2.2 امضا و بدنه prepareAndConnect
m = replace_once(
    m,
    '''    private fun prepareAndConnect(config: String, torEnabled: Boolean, killSwitch: Boolean) {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            pendingConfig = config
            pendingTorEnabled = torEnabled
            pendingKillSwitch = killSwitch
            startActivityForResult(prepareIntent, vpnPrepareRequestCode)
        } else {
            startVpnService(config, torEnabled, killSwitch)
        }
    }''',
    '''    private fun prepareAndConnect(
        config: String,
        torEnabled: Boolean,
        killSwitch: Boolean,
        alwaysOnVpn: Boolean,
    ) {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            pendingConfig = config
            pendingTorEnabled = torEnabled
            pendingKillSwitch = killSwitch
            pendingAlwaysOnVpn = alwaysOnVpn
            startActivityForResult(prepareIntent, vpnPrepareRequestCode)
        } else {
            startVpnService(config, torEnabled, killSwitch, alwaysOnVpn)
        }
    }''',
    "امضا/بدنه prepareAndConnect",
)

# 2.3 امضا و بدنه startVpnService
m = replace_once(
    m,
    '''    private fun startVpnService(config: String, torEnabled: Boolean, killSwitch: Boolean) {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra(V2rayVpnService.EXTRA_CONFIG, config)
            putExtra(V2rayVpnService.EXTRA_TOR_ENABLED, torEnabled)
            putExtra(V2rayVpnService.EXTRA_KILL_SWITCH, killSwitch)
        }
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }''',
    '''    private fun startVpnService(
        config: String,
        torEnabled: Boolean,
        killSwitch: Boolean,
        alwaysOnVpn: Boolean,
    ) {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra(V2rayVpnService.EXTRA_CONFIG, config)
            putExtra(V2rayVpnService.EXTRA_TOR_ENABLED, torEnabled)
            putExtra(V2rayVpnService.EXTRA_KILL_SWITCH, killSwitch)
            putExtra(V2rayVpnService.EXTRA_ALWAYS_ON, alwaysOnVpn)
        }
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
    }''',
    "امضا/بدنه startVpnService",
)

# 2.4 فراخوانی startVpnService در onActivityResult
m = replace_once(
    m,
    '                startVpnService(pendingConfig ?: "", pendingTorEnabled, pendingKillSwitch)',
    '                startVpnService(pendingConfig ?: "", pendingTorEnabled, pendingKillSwitch, pendingAlwaysOnVpn)',
    "startVpnService در onActivityResult",
)

write(MAIN, m)
print("[ok] MainActivity.kt ذخیره شد")

# ---------------------------------------------------------------- 3) V2rayVpnService.kt
print("\nV2rayVpnService.kt:")
s = read(SVC)

# 3.1 ثابت EXTRA_ALWAYS_ON
s = replace_once(
    s,
    '        const val EXTRA_KILL_SWITCH = "extra_kill_switch"',
    '        const val EXTRA_KILL_SWITCH = "extra_kill_switch"\n        const val EXTRA_ALWAYS_ON = "extra_always_on"',
    "ثابت EXTRA_ALWAYS_ON",
)

# 3.2 قطع دستی -> پاک‌کردن prefs
s = replace_once(
    s,
    '''            ACTION_DISCONNECT -> {
                stopVpn()
                return START_NOT_STICKY
            }''',
    '''            ACTION_DISCONNECT -> {
                // قطع دستی توسط کاربر: prefs پاک شود تا ریبوت باعث اتصال خودسر نشود
                runCatching { VpnPrefs.clear(this) }
                stopVpn()
                return START_NOT_STICKY
            }''',
    "پاک‌کردن VpnPrefs در قطع دستی",
)

# 3.3 else -> بازیابی/ذخیره از VpnPrefs
s = replace_once(
    s,
    '''            else -> {
                val config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()
                val torEnabled = intent?.getBooleanExtra(EXTRA_TOR_ENABLED, false) ?: false
                val killSwitch = intent?.getBooleanExtra(EXTRA_KILL_SWITCH, false) ?: false
                startVpn(config, torEnabled, killSwitch)
            }''',
    '''            else -> {
                // در حالت عادی از Intent می‌خوانیم؛ در استارت خودکار سیستم (ریبوت/Always-On)
                // که intent == null است، از VpnPrefs بازیابی می‌کنیم.
                var config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()
                var torEnabled = intent?.getBooleanExtra(EXTRA_TOR_ENABLED, false) ?: false
                var killSwitch = intent?.getBooleanExtra(EXTRA_KILL_SWITCH, false) ?: false
                var alwaysOnVpn = intent?.getBooleanExtra(EXTRA_ALWAYS_ON, false) ?: false

                if (intent == null || config.isBlank()) {
                    Log.d(TAG, "Intent خالی/بدون کانفیگ — بازیابی از VpnPrefs")
                    config = VpnPrefs.config(this)
                    torEnabled = VpnPrefs.torEnabled(this)
                    killSwitch = VpnPrefs.killSwitch(this)
                    alwaysOnVpn = VpnPrefs.alwaysOnVpn(this)
                } else {
                    // اتصال معمولی از UI: همه چیز برای استارت‌های بعدی ذخیره شود
                    runCatching {
                        VpnPrefs.save(this, config, torEnabled, killSwitch, alwaysOnVpn)
                    }
                }

                startVpn(config, torEnabled, killSwitch, alwaysOnVpn)
            }''',
    "بازیابی/ذخیره VpnPrefs در onStartCommand",
)

# 3.4 فیلد currentAlwaysOn
s = replace_once(
    s,
    '    private var currentKillSwitch: Boolean = false',
    '    private var currentKillSwitch: Boolean = false\n    private var currentAlwaysOn: Boolean = false',
    "فیلد currentAlwaysOn",
)

# 3.5 امضا و ابتدای بدنه startVpn
s = replace_once(
    s,
    '''    private fun startVpn(config: String, torEnabled: Boolean, killSwitch: Boolean = false) {
        stopping = false
        startForegroundSafely()''',
    '''    private fun startVpn(
        config: String,
        torEnabled: Boolean,
        killSwitch: Boolean = false,
        alwaysOnVpn: Boolean = false,
    ) {
        stopping = false
        currentAlwaysOn = alwaysOnVpn
        startForegroundSafely()''',
    "امضا/ابتدای startVpn",
)

write(SVC, s)
print("[ok] V2rayVpnService.kt ذخیره شد")

print("\n✅ تمام پچ‌ها با موفقیت اعمال شد.")
