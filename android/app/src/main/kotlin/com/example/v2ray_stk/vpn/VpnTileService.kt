package com.example.v2ray_stk.vpn

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import android.widget.Toast
import com.example.v2ray_stk.MainActivity
import com.example.v2ray_stk.R

/**
 * کاشی تنظیمات سریع (Quick Settings Tile) — فیچر ۳۶
 *
 * تپ اول (قطع + کانفیگ موجود + مجوز موجود) -> اتصال بی‌واسطه، بدون باز شدن اپ
 * تپ دوم (متصل/در حال اتصال)               -> ACTION_DISCONNECT
 * فقط اگر مجوز VPN یا کانفیگ نبود           -> اپ باز می‌شود
 *
 * کانفیگ از VpnPrefs.config خوانده می‌شود و اگر خالی بود از last_config
 * (کلیدی که هنگام disconnect پاک نمی‌شود) بازیابی می‌گردد.
 */
class VpnTileService : TileService() {

    companion object {
        private const val TAG = "VpnTileService"

        /** از سرویس/اکتیویتی صدا زده می‌شود تا سیستم onStartListening را دوباره اجرا کند. */
        fun requestUpdate(context: Context) {
            runCatching {
                requestListeningState(
                    context,
                    ComponentName(context, VpnTileService::class.java),
                )
            }.onFailure { Log.w(TAG, "requestListeningState failed: " + it.message) }
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onTileAdded() {
        super.onTileAdded()
        renderTile()
    }

    override fun onStartListening() {
        super.onStartListening()
        renderTile()
    }

    override fun onStopListening() {
        handler.removeCallbacksAndMessages(null)
        super.onStopListening()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onClick() {
        super.onClick()
        if (isLocked) {
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
        scheduleRefresh()
    }

    /** وضعیت واقعی با تأخیر عوض می‌شود؛ چند بار رندر می‌کنیم تا آیکون یخ نزند. */
    private fun scheduleRefresh() {
        handler.removeCallbacksAndMessages(null)
        for (delay in longArrayOf(300L, 900L, 2000L, 4000L, 7000L)) {
            handler.postDelayed({ renderTile() }, delay)
        }
    }

    private fun disconnect() {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_DISCONNECT
        }
        runCatching { startService(intent) }
            .onFailure { Log.w(TAG, "disconnect failed: " + it.message) }
    }

    private fun connect() {
        val config = runCatching {
            val saved = VpnPrefs.config(this)
            if (saved.isNotBlank()) saved else VpnPrefs.lastConfig(this)
        }.getOrDefault("")

        if (config.isBlank()) {
            Log.i(TAG, "کانفیگی ذخیره نشده است؛ اپ باز می‌شود")
            toast(getString(R.string.qs_tile_no_config))
            openApp()
            return
        }

        val needsPermission = runCatching { VpnService.prepare(this) != null }.getOrDefault(true)
        if (needsPermission) {
            Log.i(TAG, "مجوز VPN موجود نیست؛ اپ باز می‌شود")
            toast(getString(R.string.qs_tile_need_permission))
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

    private fun toast(msg: String) {
        runCatching {
            handler.post { Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show() }
        }
    }

    // ------------------------------------------------------------- render

    private fun renderTile() {
        val tile = qsTile ?: return
        val status = VpnState.status

        val subRes: Int
        val state: Int
        when (status) {
            VpnStatus.CONNECTED -> {
                subRes = R.string.qs_tile_connected
                state = Tile.STATE_ACTIVE
            }
            VpnStatus.CONNECTING -> {
                subRes = R.string.qs_tile_connecting
                // ACTIVE نگه می‌داریم تا کلیک بعدی برای کنسل کردن به ما برسد
                state = Tile.STATE_ACTIVE
            }
            else -> {
                subRes = R.string.qs_tile_disconnected
                state = Tile.STATE_INACTIVE
            }
        }

        tile.state = state
        tile.label = getString(R.string.qs_tile_label)
        tile.icon = Icon.createWithResource(this, R.drawable.ic_qs_vpn)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tile.subtitle = getString(subRes)
            tile.stateDescription = getString(subRes)
        }

        runCatching { tile.updateTile() }
            .onFailure { Log.w(TAG, "updateTile failed: " + it.message) }
    }
}
