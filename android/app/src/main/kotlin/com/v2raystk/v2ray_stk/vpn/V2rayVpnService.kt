package com.v2raystk.v2ray_stk.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.util.Log
import libbox.BoxService
import libbox.Libbox
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android VPN service backed by sing-box libbox.
 * API matches current libbox.aar:
 *  - Libbox.setup(basePath, workingPath, tempPath, fixAndroidStack)
 *  - Libbox.newService(config, platformInterface)
 *  - BoxService.start()/close()
 */
class V2rayVpnService : VpnService() {

    companion object {
        private const val TAG = "V2rayVpnService"
        private const val CHANNEL_ID = "v2ray_stk_vpn"
        private const val NOTIFICATION_ID = 1

        const val ACTION_START = "com.v2raystk.v2ray_stk.VPN_START"
        const val ACTION_STOP = "com.v2raystk.v2ray_stk.VPN_STOP"
        const val EXTRA_CONFIG = "config_json"
    }

    private var boxService: BoxService? = null
    private var platformInterface: BoxPlatformInterface? = null
    private val running = AtomicBoolean(false)

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        try {
            // Touch native lib early
            Libbox.touch()
        } catch (e: Throwable) {
            Log.e(TAG, "Libbox.touch failed", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopVpn()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val config = intent?.getStringExtra(EXTRA_CONFIG)
                if (config.isNullOrBlank()) {
                    Log.e(TAG, "missing config_json")
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, buildNotification("Connecting…"))
                Thread {
                    try {
                        startVpn(config)
                    } catch (e: Throwable) {
                        Log.e(TAG, "startVpn failed", e)
                        try {
                            Libbox.writeServiceError(e.message ?: "start failed")
                        } catch (_: Throwable) {
                        }
                        stopVpn()
                    }
                }.start()
            }
        }
        return START_STICKY
    }

    private fun startVpn(configJson: String) {
        if (!running.compareAndSet(false, true)) {
            Log.w(TAG, "already running")
            return
        }

        // Working dirs for sing-box
        val baseDir = File(filesDir, "singbox").apply { mkdirs() }
        val workingDir = File(baseDir, "workdir").apply { mkdirs() }
        val tempDir = File(cacheDir, "singbox_temp").apply { mkdirs() }

        // IMPORTANT: no SetupOptions in this AAR
        // setup(basePath, workingPath, tempPath, fixAndroidStack)
        Libbox.setup(
            baseDir.absolutePath,
            workingDir.absolutePath,
            tempDir.absolutePath,
            false,
        )

        try {
            Libbox.redirectStderr(File(baseDir, "stderr.log").absolutePath)
        } catch (e: Exception) {
            Log.w(TAG, "redirectStderr: ${e.message}")
        }

        // Optional: validate config
        try {
            Libbox.checkConfig(configJson)
        } catch (e: Exception) {
            throw IllegalArgumentException("invalid sing-box config: ${e.message}", e)
        }

        val iface = BoxPlatformInterface(this)
        platformInterface = iface

        val service = Libbox.newService(configJson, iface)
        boxService = service
        service.start()

        startForeground(NOTIFICATION_ID, buildNotification("Connected"))
        Log.i(TAG, "sing-box started, version=${try { Libbox.version() } catch (_: Throwable) { "?" }}")
    }

    private fun stopVpn() {
        running.set(false)
        try {
            boxService?.close()
        } catch (e: Exception) {
            Log.w(TAG, "box close: ${e.message}")
        }
        boxService = null

        try {
            platformInterface?.closeTun()
        } catch (_: Exception) {
        }
        platformInterface = null

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.i(TAG, "vpn stopped")
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        Log.w(TAG, "VPN revoked by system")
        stopVpn()
        super.onRevoke()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return super.onBind(intent)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                "VPN",
                NotificationManager.IMPORTANCE_LOW,
            )
            nm?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(content: String): Notification {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("V2ray Stk")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(pi)
            .setOngoing(true)
            .build()
    }
}
