package com.example.v2ray_stk.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat

class V2rayVpnService : VpnService() {

    companion object {
        const val ACTION_CONNECT = "com.v2ray.stk.CONNECT"
        const val ACTION_DISCONNECT = "com.v2ray.stk.DISCONNECT"
        const val EXTRA_CONFIG = "extra_config"

        private const val TUN_ADDRESS = "172.19.0.1"
        private const val TUN_PREFIX = 28
        private const val TUN_MTU = 1500

        private const val NOTIF_CHANNEL_ID = "v2ray_stk_vpn"
        private const val NOTIF_ID = 0x5754

        @Volatile
        var instance: V2rayVpnService? = null
            private set
    }

    private var tunInterface: ParcelFileDescriptor? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            stopVpn()
            return START_NOT_STICKY
        }
        val config = intent?.getStringExtra(EXTRA_CONFIG) ?: ""
        startVpn(config)
        return START_STICKY
    }

    private fun startVpn(config: String) {
        try {
            startForegroundNotification()
            VpnState.update(VpnStatus.CONNECTING)

            if (config.isBlank()) {
                LogStore.append("app", "کانفیگ خالی است؛ اتصال لغو شد")
                stopVpn()
                return
            }

            val tun = establishTun()
            if (tun == null) {
                LogStore.append("app", "ساخت رابط TUN ناموفق بود")
                stopVpn()
                return
            }
            tunInterface = tun

            SingBoxBridge.start(this, tun.fd, config)

            // اتصال به CommandServer هسته برای آمار زنده و لاگ
            runCatching { CommandClientBridge.start() }
                .onFailure { LogStore.append("app", "CommandClient خطا: ${it.message}") }

            VpnState.update(VpnStatus.CONNECTED)
        } catch (t: Throwable) {
            LogStore.append("app", "خطا در راه‌اندازی VPN: ${t.message}")
            stopVpn()
        }
    }

    private fun establishTun(): ParcelFileDescriptor? {
        val builder = Builder()
            .setSession("V2ray Stk")
            .setMtu(TUN_MTU)
            .addAddress(TUN_ADDRESS, TUN_PREFIX)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("172.19.0.1")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }
        runCatching { builder.addDisallowedApplication(packageName) }

        return runCatching { builder.establish() }.getOrNull()
    }

    private fun stopVpn() {
        runCatching { CommandClientBridge.stop() }
        runCatching { SingBoxBridge.stop() }
        runCatching { tunInterface?.close() }
        tunInterface = null
        VpnState.update(VpnStatus.DISCONNECTED)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        }
        stopSelf()
    }

    private fun startForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager?.getNotificationChannel(NOTIF_CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    NOTIF_CHANNEL_ID,
                    "V2ray Stk",
                    NotificationManager.IMPORTANCE_LOW
                )
                manager?.createNotificationChannel(channel)
            }
        }
        val notification: Notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setContentTitle("V2ray Stk")
            .setContentText("در حال اجرا")
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setOngoing(true)
            .build()
        startForeground(NOTIF_ID, notification)
    }

    override fun onDestroy() {
        instance = null
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }
}
