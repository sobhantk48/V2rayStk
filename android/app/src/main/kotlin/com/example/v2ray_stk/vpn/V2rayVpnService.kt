package com.example.v2ray_stk.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat

class V2rayVpnService : VpnService() {

    companion object {
        const val ACTION_CONNECT = "com.v2ray.stk.CONNECT"
        const val ACTION_DISCONNECT = "com.v2ray.stk.DISCONNECT"
        const val EXTRA_CONFIG = "extra_config"

        private const val TAG = "V2rayVpnService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "v2ray_stk_vpn"

        // باید دقیقا با مقادیر _tunInbound در sing_box_config_generator.dart یکی باشد
        private const val TUN_ADDRESS = "172.19.0.1"
        private const val TUN_PREFIX = 28
        private const val TUN_MTU = 1500

        // فاصله بین تلاش‌های اتصال Bridge به هسته
        private const val BRIDGE_FIRST_DELAY_MS = 700L
        private const val BRIDGE_RETRY_MS = 3000L
        private const val BRIDGE_MAX_RETRY = 10
    }

    private var tunInterface: ParcelFileDescriptor? = null

    private val mainHandler = Handler(Looper.getMainLooper())
    private var bridgeStarted = false
    private var bridgeRetry = 0

    private val bridgeWatch = object : Runnable {
        override fun run() {
            // اگر VPN قطع شده، دیگر تلاش نکن
            if (tunInterface == null) return

            // مرحله ۱: سلامت bridgeی که در tick قبل start شده را بسنج
            val healthy = runCatching { CommandClientBridge.hasData }.getOrDefault(false)
            if (healthy) {
                Log.d(TAG, "bridge سالم است و داده دریافت می‌شود")
                return
            }

            // مرحله ۲: اگر start شده بود ولی در طول یک بازه کامل داده نداد، ری‌استارتش کن
            if (bridgeStarted) {
                Log.d(TAG, "bridge بدون داده بعد از ${BRIDGE_RETRY_MS}ms، ری‌استارت")
                runCatching { CommandClientBridge.stop() }
                bridgeStarted = false
            }

            if (bridgeRetry >= BRIDGE_MAX_RETRY) {
                Log.w(TAG, "bridge پس از $BRIDGE_MAX_RETRY تلاش داده‌ای نداد، توقف تلاش")
                return
            }

            // مرحله ۳: یک تلاش تازه، و ارزیابی نتیجه‌اش در tick بعدی
            bridgeRetry++
            runCatching { CommandClientBridge.start() }
                .onSuccess {
                    bridgeStarted = true
                    Log.d(TAG, "CommandClientBridge.start() تلاش #$bridgeRetry")
                }
                .onFailure { t ->
                    Log.w(TAG, "CommandClientBridge.start() failed: ${t.message}")
                }

            mainHandler.postDelayed(this, BRIDGE_RETRY_MS)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_DISCONNECT -> {
                stopVpn()
                return START_NOT_STICKY
            }

            else -> {
                val config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()
                startVpn(config)
            }
        }
        return START_STICKY
    }

    private fun startVpn(config: String) {
        startForegroundSafely()
        VpnState.update(VpnStatus.CONNECTING)

        if (config.isBlank()) {
            Log.e(TAG, "config خالی است")
            VpnState.update(VpnStatus.DISCONNECTED)
            stopVpn()
            return
        }

        try {
            val tun = establishTun()
        TorDaemon.start(this)
            if (tun == null) {
                Log.e(TAG, "establish() برگشت null (اجازه VPN صادر نشده؟)")
                VpnState.update(VpnStatus.DISCONNECTED)
                stopVpn()
                return
            }

            tunInterface = tun
            Log.d(
                TAG,
                "tun established fd=${tun.fd} mtu=$TUN_MTU addr=$TUN_ADDRESS/$TUN_PREFIX",
            )

            SingBoxBridge.start(this, tun.fd, config)
            VpnState.update(VpnStatus.CONNECTED)

            startBridgeWatch()
        } catch (e: Throwable) {
            Log.e(TAG, "startVpn failed", e)
            VpnState.update(VpnStatus.DISCONNECTED)
            stopVpn()
        }
    }

    private fun startBridgeWatch() {
        stopBridge()
        bridgeRetry = 0
        bridgeStarted = false
        mainHandler.postDelayed(bridgeWatch, BRIDGE_FIRST_DELAY_MS)
    }

    private fun stopBridge() {
        mainHandler.removeCallbacks(bridgeWatch)
        if (bridgeStarted) {
            runCatching { CommandClientBridge.stop() }
        }
        bridgeStarted = false
        bridgeRetry = 0
    }

    private fun establishTun()
        TorDaemon.start(this): ParcelFileDescriptor? {
        val builder = Builder()
            .setSession("V2ray Stk")
            .setMtu(TUN_MTU)
            .addAddress(TUN_ADDRESS, TUN_PREFIX)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("172.19.0.2")

        if (Build.VERSION.SDK_INT >= 29) {
            builder.setMetered(false)
        }

        if (Build.VERSION.SDK_INT >= 21) {
            builder.allowFamily(android.system.OsConstants.AF_INET)
        }

        runCatching { builder.addDisallowedApplication(packageName) }

        return builder.establish()
    }

    private fun stopVpn() {
        stopBridge()
        runCatching { SingBoxBridge.stop()
        TorDaemon.stop() }
        runCatching { tunInterface?.close() }
        tunInterface = null
        VpnState.update(VpnStatus.DISCONNECTED)
        runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
        stopSelf()
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopVpn()
        super.onRevoke()
    }

    private fun startForegroundSafely() {
        createChannel()

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("V2ray Stk")
            .setContentText("VPN در حال اجرا")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        runCatching { startForeground(NOTIFICATION_ID, notification) }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val channel = NotificationChannel(
                CHANNEL_ID,
                "V2ray Stk VPN",
                NotificationManager.IMPORTANCE_LOW,
            )
            manager.createNotificationChannel(channel)
        }
    }
}
