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
    private const val KEY_SPLIT_MODE = "split_mode"
    private const val KEY_SPLIT_APPS = "split_apps"

    /** حالت‌های مجاز تونل تفکیکی */
    const val SPLIT_OFF = "off"
    const val SPLIT_EXCLUDE = "exclude"
    const val SPLIT_INCLUDE = "include"

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
        // SPLIT_PATCH_V2: keep split-tunnel settings when user disconnects
    fun clear(context: Context) {
        val p = prefs(context)
        val mode = p.getString(KEY_SPLIT_MODE, SPLIT_OFF) ?: SPLIT_OFF
        val apps = p.getStringSet(KEY_SPLIT_APPS, emptySet())?.toSet() ?: emptySet()
        p.edit().clear().apply()
        saveSplit(context, mode, apps)
    }

    fun config(context: Context): String =
        prefs(context).getString(KEY_CONFIG, "").orEmpty()

    fun torEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_TOR_ENABLED, false)

    fun killSwitch(context: Context): Boolean =
        prefs(context).getBoolean(KEY_KILL_SWITCH, false)

    fun alwaysOnVpn(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ALWAYS_ON, false)

    // ----------------------------------------------------- split tunneling

    /** ذخیره‌ی حالت و لیست پکیج‌ها؛ از سمت Flutter صدا زده می‌شود. */
    fun saveSplit(context: Context, mode: String, apps: Collection<String>) {
        val safeMode = when (mode) {
            SPLIT_EXCLUDE, SPLIT_INCLUDE -> mode
            else -> SPLIT_OFF
        }
        prefs(context).edit()
            .putString(KEY_SPLIT_MODE, safeMode)
            .putStringSet(KEY_SPLIT_APPS, apps.filter { it.isNotBlank() }.toSet())
            .apply()
    }

    fun splitMode(context: Context): String =
        prefs(context).getString(KEY_SPLIT_MODE, SPLIT_OFF) ?: SPLIT_OFF

    fun splitApps(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_SPLIT_APPS, emptySet()) ?: emptySet()

    // ------------- Quick Settings Tile helpers (فیچر ۳۶) -------------
    // این کلید با clear() پاک نمی‌شود تا کاشی همیشه بتواند دوباره وصل کند.
    private const val KEY_LAST_CONFIG = "last_config"

    private fun tilePrefs(context: Context) =
        context.getSharedPreferences("vpn_prefs", Context.MODE_PRIVATE)

    fun saveLastConfig(context: Context, config: String) {
        if (config.isBlank()) return
        tilePrefs(context).edit().putString(KEY_LAST_CONFIG, config).apply()
    }

    fun lastConfig(context: Context): String =
        tilePrefs(context).getString(KEY_LAST_CONFIG, "") ?: ""

    /** مثل clear() ولی آخرین کانفیگ را برای کاشی نگه می‌دارد. */
    fun clearKeepLast(context: Context) {
        val last = lastConfig(context)
        clear(context)
        if (last.isNotBlank()) saveLastConfig(context, last)
    }
}
