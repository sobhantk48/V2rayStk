package com.example.v2ray_stk.vpn

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import com.example.v2ray_stk.MainActivity
import com.example.v2ray_stk.R

/**
 * کاشی تنظیمات سریع (Quick Settings Tile) — فیچر ۳۶
 *
 * رفتار:
 *  - متصل / در حال اتصال  -> ACTION_DISCONNECT به V2rayVpnService
 *  - قطع                  -> اگر کانفیگ ذخیره‌شده و مجوز VPN موجود باشد، مستقیم وصل می‌شود
 *                            وگرنه اپ باز می‌شود تا کاربر پروفایل/مجوز را تعیین کند
 *
 * منبع وضعیت: VpnState (هم‌پروسه با سرویس). برای رفرش آنی،
 * V2rayVpnService متد requestUpdate() را صدا می‌زند.
 */
class VpnTileService : TileService() {

    companion object {
        private const val TAG = "VpnTileService"

        /** از سرویس صدا زده می‌شود تا سیستم onStartListening را دوباره اجرا کند. */
        fun requestUpdate(context: Context) {
            runCatching {
                requestListeningState(
                    context,
                    ComponentName(context, VpnTileService::class.java),
                )
            }.onFailure { Log.w(TAG, "requestListeningState failed: " + it.message) }
        }
    }

    override fun onTileAdded() {
        super.onTileAdded()
        renderTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        renderTile()
    }

    override fun onClick() {
        super.onClick()
        if (isLocked) {
            // دستگاه قفل است: اول باز شود، بعد سوییچ
            unlockAndRun { toggle() }
        } else {
            toggle()
        }
    }

    // ------------------------------------------------------------ actions

    private fun toggle() {
        when (VpnState.status) {
            VpnStatus.CONNECTED, VpnStatus.CONNECTING -> disconnect()
            else -> connect()
        }
        renderTile()
    }

    private fun disconnect() {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_DISCONNECT
        }
        runCatching { startService(intent) }
            .onFailure { Log.w(TAG, "disconnect failed: " + it.message) }
    }

    private fun connect() {
        val config = runCatching { VpnPrefs.config(this) }.getOrDefault("")
        val prepared = runCatching { VpnService.prepare(this) == null }.getOrDefault(false)

        if (config.isBlank() || !prepared) {
            Log.i(TAG, "کانفیگ یا مجوز VPN موجود نیست، اپ باز می‌شود")
            openApp()
            return
        }

        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra(V2rayVpnService.EXTRA_CONFIG, config)
            putExtra(V2rayVpnService.EXTRA_TOR_ENABLED, VpnPrefs.torEnabled(this@VpnTileService))
            putExtra(V2rayVpnService.EXTRA_KILL_SWITCH, VpnPrefs.killSwitch(this@VpnTileService))
            putExtra(V2rayVpnService.EXTRA_ALWAYS_ON, VpnPrefs.alwaysOnVpn(this@VpnTileService))
        }

        val ok = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            true
        }.getOrElse { t ->
            Log.w(TAG, "استارت سرویس از کاشی ناموفق: " + t.message)
            false
        }

        // اگر سیستم اجازه استارت فورگراند از پس‌زمینه نداد، اپ را باز می‌کنیم
        if (!ok) openApp()
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= 34) {
                val pending = PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                startActivityAndCollapse(pending)
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
        }.onFailure { Log.w(TAG, "openApp failed: " + it.message) }
    }

    // ------------------------------------------------------------- render

    private fun renderTile() {
        val tile = qsTile ?: return
        val status = VpnState.status

        val labelRes: Int
        val state: Int
        when (status) {
            VpnStatus.CONNECTED -> {
                labelRes = R.string.qs_tile_connected
                state = Tile.STATE_ACTIVE
            }
            VpnStatus.CONNECTING -> {
                labelRes = R.string.qs_tile_connecting
                state = Tile.STATE_UNAVAILABLE
            }
            else -> {
                labelRes = R.string.qs_tile_disconnected
                state = Tile.STATE_INACTIVE
            }
        }

        tile.state = state
        tile.label = getString(R.string.qs_tile_label)
        tile.icon = Icon.createWithResource(this, R.drawable.ic_qs_vpn)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = getString(labelRes)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.stateDescription = getString(labelRes)
        }

        runCatching { tile.updateTile() }
            .onFailure { Log.w(TAG, "updateTile failed: " + it.message) }
    }
}
