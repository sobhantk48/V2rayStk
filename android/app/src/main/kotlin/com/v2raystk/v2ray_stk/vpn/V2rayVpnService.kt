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
        const val ACTION_STATUS = "com.v2raystk.v2ray_stk.STATUS"
        const val EXTRA_STATUS = "status"
        const val EXTRA_UPLOAD = "upload"
        const val EXTRA_DOWNLOAD = "download"

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        var uploadBytes: Long = 0L

        @Volatile
        var downloadBytes: Long = 0L
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
        if (isRunning) {
            broadcastStatus("connected")
            return
        }

        try {
            broadcastStatus("connecting")

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

            // Avoid routing our own app traffic into the tunnel in this skeleton phase
            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Exception) {
            }

            vpnInterface = builder.establish()
            if (vpnInterface == null) {
                Log.e("V2rayVpn", "Failed to establish VPN interface")
                broadcastStatus("disconnected")
                stopSelf()
                return
            }

            isRunning = true
            uploadBytes = 0L
            downloadBytes = 0L
            startForeground(NOTIFICATION_ID, createNotification("Connected"))
            broadcastStatus("connected")
            Log.i("V2rayVpn", "VPN skeleton started. configLen=${config.length}")
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
        uploadBytes = 0L
        downloadBytes = 0L

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
        }

        broadcastStatus("disconnected")
        stopSelf()
        Log.i("V2rayVpn", "VPN stopped")
    }

    private fun broadcastStatus(status: String) {
        val intent = Intent(ACTION_STATUS).apply {
            setPackage(packageName)
            putExtra(EXTRA_STATUS, status)
            putExtra(EXTRA_UPLOAD, uploadBytes)
            putExtra(EXTRA_DOWNLOAD, downloadBytes)
        }
        sendBroadcast(intent)
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
        if (isRunning) {
            try {
                vpnInterface?.close()
            } catch (_: Exception) {
            }
            vpnInterface = null
            isRunning = false
            broadcastStatus("disconnected")
        }
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }
}
