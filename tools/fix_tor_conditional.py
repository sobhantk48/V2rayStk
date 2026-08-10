#!/usr/bin/env python3
import re, sys, pathlib

p = pathlib.Path("android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt")
s = p.read_text(encoding="utf-8")
orig = s

# 1) EXTRA_TOR_ENABLED constant
if "EXTRA_TOR_ENABLED" not in s:
    s = s.replace(
        'const val EXTRA_CONFIG = "extra_config"',
        'const val EXTRA_CONFIG = "extra_config"\n'
        '        const val EXTRA_TOR_ENABLED = "extra_tor_enabled"'
    )

# 2) خواندن فلگ از Intent و پاس دادن به startVpn
s = s.replace(
    """            else -> {
                val config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()
                startVpn(config)
            }""",
    """            else -> {
                val config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()
                val torEnabled = intent?.getBooleanExtra(EXTRA_TOR_ENABLED, false) ?: false
                startVpn(config, torEnabled)
            }"""
)

# 3) امضای startVpn
s = s.replace(
    "private fun startVpn(config: String) {",
    "private fun startVpn(config: String, torEnabled: Boolean) {"
)

# 4) اجرای مشروط Tor + بعد از establishTun
s = s.replace(
    """            val tun = establishTun()
            torDaemon = TorDaemon(this@V2rayVpnService)
            torDaemon?.start()
            if (tun == null) {""",
    """            val tun = establishTun()
            if (tun == null) {"""
)

s = s.replace(
    """            tunInterface = tun
            val fd = tun.detachFd()""",
    """            if (torEnabled) {
                Log.d(TAG, "Tor فعال است، در حال راه‌اندازی TorDaemon")
                runCatching {
                    torDaemon = TorDaemon(this@V2rayVpnService)
                    torDaemon?.start()
                }.onFailure { t ->
                    Log.e(TAG, "TorDaemon.start() failed: ${t.message}", t)
                }
            } else {
                Log.d(TAG, "Tor غیرفعال است، TorDaemon اجرا نمی‌شود")
            }

            tunInterface = tun
            val fd = tun.detachFd()"""
)

# 5) stopVpn امن — هر کدام runCatching جدا
s = s.replace(
    """        runCatching { SingBoxBridge.stop()
        torDaemon?.stop() }
        runCatching { tunInterface?.close() }""",
    """        runCatching { SingBoxBridge.stop() }
            .onFailure { Log.w(TAG, "SingBoxBridge.stop() failed: ${it.message}") }
        runCatching { torDaemon?.stop() }
            .onFailure { Log.w(TAG, "TorDaemon.stop() failed: ${it.message}") }
        torDaemon = null
        runCatching { tunInterface?.close() }"""
)

if s == orig:
    print("!! هیچ تغییری اعمال نشد — احتمالاً قبلا پچ شده")
    sys.exit(1)

p.write_text(s, encoding="utf-8")
print("OK: V2rayVpnService.kt پچ شد")
