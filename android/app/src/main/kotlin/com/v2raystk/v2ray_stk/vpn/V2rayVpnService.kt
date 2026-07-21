package com.v2raystk.v2ray_stk.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import com.v2raystk.v2ray_stk.MainActivity
import io.flutter.Log

class V2rayVpnService : VpnService() {

    companion object {
        const val CHANNEL_ID = "v2ray_stk_vpn"
        const val NOTIFICATION_ID = 1
        const val ACTION_CONNECT = "com.v2raystk.v2ray_stk.CONNECT"
        const val ACTION_DISCONNECT = "com.v2raystk.v2ray_stk.DISCONNECT"
        var isRunning = false
    }

    private var vpnInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra("config") ?: ""
                startVpn(config)
            }
            ACTION_DISCONNECT -> stopVpn()
        }
        return START_STICKY
    }

    private fun startVpn(config: String) {
        if (isRunning) return

        try {
            val builder = Builder()
                .setSession("V2ray Stk")
                .setMtu(1500)
                .addAddress("10.0.0.2", 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("8.8.8.8")
                .setBlocking(true)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e("V2rayVpn", "Failed to establish VPN interface")
                stopSelf()
                return
            }

            isRunning = true
            startForeground(NOTIFICATION_ID, createNotification("Connected"))
            Log.i("V2rayVpn", "VPN skeleton started. configLen=${config.length}")

            // TODO: libbox + tun fd
        } catch (e: Exception) {
            Log.e("V2rayVpn", "startVpn error", e)
            stopVpn()
        }
    }

    private fun stopVpn() {
        try {
            vpnInterface?.close()
        } catch (_: Exception) {
        }
        vpnInterface = null
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i("V2rayVpn", "VPN stopped")
    }

    private fun createNotification(status: String): Notification {
        createNotificationChannel()

        val intent = Intent(this, MainActivity::class.java)
        val pending = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("V2ray Stk")
            .setContentText(status)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pending)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "V2ray Stk VPN"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }
}
