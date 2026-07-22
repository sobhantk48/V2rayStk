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
import libbox.BoxService
import libbox.Libbox
import libbox.SetupOptions
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

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

        private val libboxReady = AtomicBoolean(false)
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var boxService: BoxService? = null
    private val worker = Executors.newSingleThreadExecutor()

    override fun onCreate() {
        super.onCreate()
        ensureLibboxSetup()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra("config") ?: ""
                worker.execute { startVpn(config) }
            }
            ACTION_DISCONNECT -> {
                worker.execute { stopVpn() }
            }
        }
        return START_STICKY
    }

    private fun ensureLibboxSetup() {
        if (libboxReady.get()) return
        synchronized(libboxReady) {
            if (libboxReady.get()) return
            try {
                val base = File(filesDir, "singbox").apply { mkdirs() }
                val working = File(base, "working").apply { mkdirs() }
                val temp = File(cacheDir, "singbox_tmp").apply { mkdirs() }

                val options = SetupOptions()
                options.basePath = base.absolutePath
                options.workingPath = working.absolutePath
                options.tempPath = temp.absolutePath
                // optional fields differ by libbox version; ignore if missing at compile time

                Libbox.setup(options)
                try {
                    Libbox.setMemoryLimit(false)
                } catch (_: Throwable) {
                }

                libboxReady.set(true)
                Log.i("V2rayVpn", "Libbox setup OK base=${base.absolutePath}")
            } catch (e: Exception) {
                Log.e("V2rayVpn", "Libbox setup failed", e)
            }
        }
    }

    private fun startVpn(config: String) {
        if (isRunning) {
            broadcastStatus("connected")
            return
        }

        if (config.isBlank()) {
            Log.e("V2rayVpn", "Empty config")
            broadcastStatus("error")
            stopSelf()
            return
        }

        try {
            broadcastStatus("connecting")
            ensureLibboxSetup()
            if (!libboxReady.get()) {
                throw IllegalStateException("Libbox is not ready")
            }

            // Minimal sanity: sing-box JSON usually starts with {
            val trimmed = config.trim()
            if (!trimmed.startsWith("{")) {
                throw IllegalArgumentException(
                    "Config must be sing-box JSON object. Got: ${trimmed.take(40)}"
                )
            }

            val platform = BoxPlatformInterface(this) { pfd ->
                vpnInterface = pfd
            }

            val service = Libbox.newService(trimmed, platform)
            service.start()
            boxService = service

            isRunning = true
            uploadBytes = 0L
            downloadBytes = 0L
            startForeground(NOTIFICATION_ID, createNotification("Connected"))
            broadcastStatus("connected")
            Log.i("V2rayVpn", "libbox started, configLen=${trimmed.length}")
        } catch (e: Exception) {
            Log.e("V2rayVpn", "startVpn error: ${e.message}", e)
            cleanupBox()
            isRunning = false
            broadcastStatus("error")
            try {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } catch (_: Exception) {
            }
            stopSelf()
        }
    }

    private fun stopVpn() {
        try {
            cleanupBox()
        } catch (e: Exception) {
            Log.e("V2rayVpn", "stopVpn cleanup error", e)
        }

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

    private fun cleanupBox() {
        try {
            boxService?.close()
        } catch (_: Exception) {
        }
        boxService = null

        try {
            vpnInterface?.close()
        } catch (_: Exception) {
        }
        vpnInterface = null
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
        worker.execute {
            try {
                cleanupBox()
            } catch (_: Exception) {
            }
            isRunning = false
            broadcastStatus("disconnected")
        }
        super.onDestroy()
    }

    override fun onRevoke() {
        worker.execute { stopVpn() }
        super.onRevoke()
    }
}
