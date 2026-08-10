package com.example.v2ray_stk.vpn

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
