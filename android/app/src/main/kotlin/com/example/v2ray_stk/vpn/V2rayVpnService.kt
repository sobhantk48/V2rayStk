package com.example.v2ray_stk.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import com.example.v2ray_stk.MainActivity

class V2rayVpnService : VpnService() {

    companion object {
        const val ACTION_CONNECT = "com.v2ray.stk.CONNECT"
        const val ACTION_DISCONNECT = "com.v2ray.stk.DISCONNECT"
        const val EXTRA_CONFIG = "extra_config"

        private const val TAG = "V2rayVpnService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "v2ray_stk_vpn"
    }

    private var tunInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_DISCONNECT) {
            LogStore.add("درخواست قطع اتصال", "info", "app")
            stopVpn()
            return START_NOT_STICKY
        }
        startVpn(intent?.getStringExtra(EXTRA_CONFIG) ?: "")
        return START_STICKY
    }

    private fun startVpn(config: String) {
        startForegroundSafely()
        VpnState.update(VpnStatus.CONNECTING)
        LogStore.add("شروع اتصال... (طول کانفیگ: ${config.length})", "info", "app")

        if (!SingBoxBridge.isCoreAvailable) {
            LogStore.add("libbox موجود نیست؛ tun ساخته نمی‌شود", "fatal", "app")
            VpnState.update(VpnStatus.DISCONNECTED)
            stopVpn()
            return
        }

        if (config.isBlank()) {
            LogStore.add("کانفیگ خالی است؛ اتصال لغو شد", "error", "app")
            VpnState.update(VpnStatus.DISCONNECTED)
            stopVpn()
            return
        }

        try {
            val tun = establishTun()
            if (tun == null) {
                LogStore.add("ساخت TUN ناموفق بود (establish برگشت null)", "error", "app")
                VpnState.update(VpnStatus.DISCONNECTED)
                stopVpn()
                return
            }
            tunInterface = tun
            LogStore.add("TUN ساخته شد، fd=${tun.fd}", "info", "app")

            SingBoxBridge.start(this, tun.fd, config)
            VpnState.update(VpnStatus.CONNECTED)
            LogStore.add("وضعیت: متصل", "info", "app")
        } catch (e: Exception) {
            Log.e(TAG, "startVpn failed", e)
            LogStore.add("خطا در راه‌اندازی: ${e.javaClass.simpleName}: ${e.message}", "fatal", "app")
            VpnState.update(VpnStatus.DISCONNECTED)
            stopVpn()
        }
    }

    private fun establishTun(): ParcelFileDescriptor? {
        return Builder()
            .setSession("V2ray Stk")
            .setMtu(9000)
            .addAddress("172.19.0.1", 30)
            .addDnsServer("8.8.8.8")
            .addRoute("0.0.0.0", 0)
            .establish()
    }

    private fun stopVpn() {
        runCatching { SingBoxBridge.stop() }
            .onFailure { LogStore.add("توقف هسته با خطا: ${it.message}", "warn", "app") }
        runCatching { tunInterface?.close() }
        tunInterface = null
        VpnState.update(VpnStatus.DISCONNECTED)
        LogStore.add("وضعیت: قطع", "info", "app")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        LogStore.add("مجوز VPN توسط سیستم لغو شد", "warn", "app")
        stopVpn()
        super.onRevoke()
    }

    private fun startForegroundSafely() {
        createChannel()
        val n = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "VPN", NotificationManager.IMPORTANCE_LOW)
            )
        }
    }

    private fun buildNotification(): Notification {
        val pi = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return b.setContentTitle("V2ray Stk")
            .setContentText("سرویس VPN در حال اجراست")
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }
}
