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

import kotlin.concurrent.thread
import androidx.core.app.NotificationCompat

class V2rayVpnService : VpnService() {
    private var torDaemon: TorDaemon? = null

    companion object {
        const val ACTION_CONNECT = "com.v2ray.stk.CONNECT"
        const val ACTION_DISCONNECT = "com.v2ray.stk.DISCONNECT"
        const val EXTRA_CONFIG = "extra_config"
        const val EXTRA_TOR_ENABLED = "extra_tor_enabled"

        const val EXTRA_KILL_SWITCH = "extra_kill_switch"
        const val EXTRA_ALWAYS_ON = "extra_always_on"
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

        // حداکثر انتظار برای Bootstrapped 100% تور
        private const val TOR_BOOTSTRAP_TIMEOUT_MS = 90_000L
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var pendingTun: ParcelFileDescriptor? = null
    private var stopping = false

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
                // قطع دستی توسط کاربر: prefs پاک شود تا ریبوت باعث اتصال خودسر نشود
                runCatching { VpnPrefs.clearKeepLast(this) }
                stopVpn()
                return START_NOT_STICKY
            }

            else -> {
                // در حالت عادی از Intent می‌خوانیم؛ در استارت خودکار سیستم (ریبوت/Always-On)
                // که intent == null است، از VpnPrefs بازیابی می‌کنیم.
                var config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()
                var torEnabled = intent?.getBooleanExtra(EXTRA_TOR_ENABLED, false) ?: false
                var killSwitch = intent?.getBooleanExtra(EXTRA_KILL_SWITCH, false) ?: false
                var alwaysOnVpn = intent?.getBooleanExtra(EXTRA_ALWAYS_ON, false) ?: false

                if (intent == null || config.isBlank()) {
                    Log.d(TAG, "Intent خالی/بدون کانفیگ — بازیابی از VpnPrefs")
                    config = VpnPrefs.config(this)
                    torEnabled = VpnPrefs.torEnabled(this)
                    killSwitch = VpnPrefs.killSwitch(this)
                    alwaysOnVpn = VpnPrefs.alwaysOnVpn(this)
                } else {
                    // اتصال معمولی از UI: همه چیز برای استارت‌های بعدی ذخیره شود
                    runCatching {
                        VpnPrefs.save(this, config, torEnabled, killSwitch, alwaysOnVpn)
                        VpnPrefs.saveLastConfig(this, config)
                    }
                }

                startVpn(config, torEnabled, killSwitch, alwaysOnVpn)
            }
        }
        return START_NOT_STICKY
    }

    private fun startVpn(
        config: String,
        torEnabled: Boolean,
        killSwitch: Boolean = false,
        alwaysOnVpn: Boolean = false,
    ) {
        stopping = false
        currentAlwaysOn = alwaysOnVpn
        startForegroundSafely()
        setStatus(VpnStatus.CONNECTING)

        if (config.isBlank()) {
            Log.e(TAG, "config خالی است")
            setStatus(VpnStatus.DISCONNECTED)
            stopVpn()
            return
        }

        try {
            val tun = establishTun(killSwitch)
            if (tun == null) {
                Log.e(TAG, "establish() برگشت null (اجازه VPN صادر نشده؟)")
                setStatus(VpnStatus.DISCONNECTED)
                stopVpn()
                return
            }

            if (!torEnabled) {
                Log.d(TAG, "Tor غیرفعال است، TorDaemon اجرا نمی‌شود")
                launchCore(tun, config)
                return
            }

            // مسیر Tor: اول بوت‌استرپ، بعد استارت هسته
            Log.d(TAG, "Tor فعال است، در حال راه‌اندازی TorDaemon")
            pendingTun = tun
            updateNotification("در حال راه‌اندازی Tor…")

            val daemon = TorDaemon(this@V2rayVpnService)
            torDaemon = daemon
            runCatching { daemon.start() }.onFailure { t ->
                Log.e(TAG, "TorDaemon.start() failed: ${t.message}", t)
            }

            thread(name = "tor-bootstrap-wait", isDaemon = true) {
                val ok = runCatching {
                    daemon.awaitBootstrap(TOR_BOOTSTRAP_TIMEOUT_MS)
                }.getOrDefault(false)

                mainHandler.post {
                    if (stopping) {
                        Log.d(TAG, "انتظار تور تمام شد ولی سرویس در حال توقف است")
                        return@post
                    }
                    val waiting = pendingTun
                    if (waiting == null) {
                        Log.w(TAG, "tun معلق موجود نیست، استارت هسته لغو شد")
                        return@post
                    }
                    pendingTun = null

                    if (ok) {
                        Log.i(TAG, "Tor آماده است (100%)، استارت sing-box")
                    } else {
                        Log.w(
                            TAG,
                            "Tor آماده نشد (${daemon.bootstrapPercent}%)، sing-box با احتمال خطا استارت می‌شود",
                        )
                    }
                    updateNotification("VPN در حال اجرا")
                    launchCore(waiting, config)
                }
            }
        } catch (e: Throwable) {
            Log.e(TAG, "startVpn failed", e)
            setStatus(VpnStatus.DISCONNECTED)
            stopVpn()
        }
    }

    /** fd را به هسته می‌سپارد و watchdog را روشن می‌کند */
    private fun launchCore(tun: ParcelFileDescriptor, config: String) {
        try {
            tunInterface = tun
            val fd = tun.detachFd()
            Log.d(
                TAG,
                "tun established fd=$fd mtu=$TUN_MTU addr=$TUN_ADDRESS/$TUN_PREFIX",
            )

            SingBoxBridge.start(this, fd, config)
            setStatus(VpnStatus.CONNECTED)

            startBridgeWatch()
        } catch (e: Throwable) {
            Log.e(TAG, "launchCore failed", e)
            setStatus(VpnStatus.DISCONNECTED)
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

    /** آپدیت وضعیت + رفرش کاشی تنظیمات سریع (فیچر ۳۶) */
    private fun setStatus(status: String) {
        VpnState.update(status)
        VpnTileService.requestUpdate(this)
    }

    private var currentKillSwitch: Boolean = false
    private var currentAlwaysOn: Boolean = false

        private fun establishTun(killSwitch: Boolean = false): ParcelFileDescriptor? {
        // SPLIT_PATCH_V2
        currentKillSwitch = killSwitch
        val builder = Builder()
            .setSession("V2ray Stk")
            .setMtu(TUN_MTU)
            .addAddress(TUN_ADDRESS, TUN_PREFIX)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("172.19.0.2")

        if (Build.VERSION.SDK_INT >= 29) {
            builder.setMetered(false)
        }

        builder.allowFamily(android.system.OsConstants.AF_INET)

        if (killSwitch) {
            builder.setBlocking(true)
            Log.i(TAG, "KillSwitch enabled: blocking mode ON")
        }

        applySplitTunnel(builder)

        return builder.establish()
    }

    /**
     * Split Tunneling — اعمال لیست اپ‌ها روی VpnService.Builder
     *
     * exclude: اپ‌های انتخاب‌شده از تونل خارج می‌مانند (بقیه داخل تونل)
     * include: فقط اپ‌های انتخاب‌شده داخل تونل می‌روند (بقیه مستقیم)
     *
     * نکته: اندروید اجازه نمی‌دهد هر دو متد addAllowed/addDisallowed با هم استفاده شوند،
     * و چون پکیج خودمان بالاتر با addDisallowedApplication ثبت شده، در حالت include
     * ابتدا Builder از نو ساخته نمی‌شود بلکه پکیج خودمان از لیست allowed کنار گذاشته می‌شود.
     */
        private fun applySplitTunnel(builder: Builder) {
        // SPLIT_PATCH_V2
        // Android forbids mixing addAllowedApplication with addDisallowedApplication.
        // In INCLUDE mode we simply never add our own package to the allowed list.
        val mode = runCatching { VpnPrefs.splitMode(this) }.getOrDefault(VpnPrefs.SPLIT_OFF)
        val apps = runCatching { VpnPrefs.splitApps(this) }.getOrDefault(emptySet())

        if (mode == VpnPrefs.SPLIT_INCLUDE && apps.isNotEmpty()) {
            var ok = 0
            for (pkg in apps) {
                if (pkg == packageName) continue
                runCatching { builder.addAllowedApplication(pkg) }
                    .onSuccess { ok++ }
                    .onFailure { e -> Log.w(TAG, "allow failed for " + pkg + ": " + e.message) }
            }
            Log.i(TAG, "SplitTunnel INCLUDE applied to " + ok + " app(s)")
            return
        }

        runCatching { builder.addDisallowedApplication(packageName) }

        if (mode == VpnPrefs.SPLIT_EXCLUDE && apps.isNotEmpty()) {
            var ok = 0
            for (pkg in apps) {
                if (pkg == packageName) continue
                runCatching { builder.addDisallowedApplication(pkg) }
                    .onSuccess { ok++ }
                    .onFailure { e -> Log.w(TAG, "disallow failed for " + pkg + ": " + e.message) }
            }
            Log.i(TAG, "SplitTunnel EXCLUDE applied to " + ok + " app(s)")
        } else {
            Log.d(TAG, "SplitTunnel OFF (mode=" + mode + " apps=" + apps.size + ")")
        }
    }

    private fun stopVpn() {
        closeTunFd()
        stopping = true
        stopBridge()
        runCatching { SingBoxBridge.stop() }
            .onFailure { Log.w(TAG, "SingBoxBridge.stop() failed: ${it.message}") }
        runCatching { torDaemon?.stop() }
            .onFailure { Log.w(TAG, "TorDaemon.stop() failed: ${it.message}") }
        torDaemon = null
        runCatching { pendingTun?.close() }
        pendingTun = null
        runCatching { tunInterface?.close() }
        tunInterface = null
        setStatus(VpnStatus.DISCONNECTED)
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

    private fun buildNotification(text: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("V2ray Stk")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun startForegroundSafely() {
        createChannel()
        runCatching { startForeground(NOTIFICATION_ID, buildNotification("VPN در حال اجرا")) }
    }

    private fun updateNotification(text: String) {
        runCatching {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(text))
        }
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


    @Synchronized
    private fun closeTunFd() {
        try {
            tunFd?.close()
            android.util.Log.i("V2rayVpnService", "tunFd closed")
        } catch (e: Throwable) {
            android.util.Log.w("V2rayVpnService", "tunFd close failed: ${e.message}")
        } finally {
            tunFd = null
        }
    }

}
