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
    private fun setStatus(newStatus: String) {
        if (VpnState.status == newStatus) return
        VpnState.update(newStatus)
        android.util.Log.i(TAG, "status -> " + newStatus)
    }

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
        private const val TUN_MTU = 1412

        // فاصله بین تلاش‌های اتصال Bridge به هسته
        private const val BRIDGE_FIRST_DELAY_MS = 700L
        private const val BRIDGE_RETRY_MS = 3000L
        private const val BRIDGE_MAX_RETRY = 10

        // حداکثر انتظار برای Bootstrapped 100% تور
        private const val TOR_BOOTSTRAP_TIMEOUT_MS = 90_000L
    }

    private var tunInterface: ParcelFileDescriptor? = null
    private var pendingTun: ParcelFileDescriptor? = null

    /**
     * fd کپی‌شده‌ای که به هسته سپرده می‌شود.
     *  > 0  : هنوز تحویل libbox نشده، مالکش خودمانیم و باید ببندیمش
     *  -1   : تحویل داده شده؛ libbox موقع close خودش می‌بنددش
     */
    @Volatile
    private var coreTunFd: Int = -1

    @Volatile
    private var stopping = false

    /** جلوگیری از اجرای چندبارهٔ teardown (stopSelf → onDestroy → stopVpn) */
    @Volatile
    private var teardownDone = false

    private val mainHandler = Handler(Looper.getMainLooper())
    private var bridgeStarted = false
    private var bridgeRetry = 0

    private val bridgeWatch = object : Runnable {
        override fun run() {
            // اگر VPN قطع شده، دیگر تلاش نکن
            if (tunInterface == null || stopping) return

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

    override fun onCreate() {
        super.onCreate()
        // لاگ‌ها باید قبل از هر خط هسته روی دیسک آماده باشند
        runCatching { LogStore.init(applicationContext) }
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
        teardownDone = false
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

    /**
     * یک کپی از fd را به هسته می‌سپارد و watchdog را روشن می‌کند.
     *
     * چرا dup؟ اگر detachFd() روی خود tun صدا زده شود، ParcelFileDescriptor دیگر
     * مالک fd نیست و close() ما بی‌اثر می‌شود؛ تنها مالک fd خام libbox است و اگر
     * آن را رها نکند، رفرنس tun باز می‌ماند و آیکون VPN اندروید پاک نمی‌شود.
     * با dup هر طرف کپی خودش را می‌بندد و tun قطعا تخریب می‌شود.
     */
    private fun launchCore(tun: ParcelFileDescriptor, config: String) {
        try {
            tunInterface = tun

            val coreFd = tun.dup().detachFd()
            coreTunFd = coreFd

            Log.d(
                TAG,
                "tun established fd=$coreFd mtu=$TUN_MTU addr=$TUN_ADDRESS/$TUN_PREFIX",
            )

            SingBoxBridge.start(this, coreFd, config)

            // از این لحظه مالکیت کپی با libbox است
            coreTunFd = -1

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
        bridgeRetry = 0
        bridgeStarted = false
        runCatching { CommandClientBridge.stop() }
    }

    private var currentAlwaysOn: Boolean = false
    private var currentKillSwitch: Boolean = false

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

    /**
     * ترتیب teardown مهم است:
     * 1) واچ‌داگ/کلاینت آمار  2) هستهٔ sing-box  3) تور  4) بستن fdها
     * اگر fd قبل از هسته بسته شود، libbox روی fd بی‌اعتبار گیر می‌کند و رفرنس tun
     * آزاد نمی‌شود؛ نتیجه‌اش باقی ماندن آیکون VPN در نوار وضعیت است.
     */
    @Synchronized
    private fun stopVpn() {
        if (teardownDone) {
            runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
            runCatching { stopSelf() }
            return
        }
        teardownDone = true
        stopping = true

        stopBridge()

        runCatching { SingBoxBridge.stop() }
            .onFailure { Log.w(TAG, "SingBoxBridge.stop() failed: ${it.message}") }

        runCatching { torDaemon?.stop() }
            .onFailure { Log.w(TAG, "TorDaemon.stop() failed: ${it.message}") }
        torDaemon = null

        // حالا هیچ‌کس روی tun کار نمی‌کند
        closeTunFd()

        setStatus(VpnStatus.DISCONNECTED)

        runCatching {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(NOTIFICATION_ID)
        }
        runCatching { stopForeground(STOP_FOREGROUND_REMOVE) }
        stopSelf()
        Log.i(TAG, "stopVpn تکمیل شد؛ همهٔ رفرنس‌های tun آزاد شدند")
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
        if (stopping) return
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

    /** بستن قطعی همهٔ fdهای مربوط به tun */
    @Synchronized
    private fun closeTunFd() {
        val pending = pendingTun
        val active = tunInterface
        pendingTun = null
        tunInterface = null

        if (pending != null) {
            runCatching { pending.close() }
                .onSuccess { Log.i(TAG, "pendingTun closed") }
                .onFailure { Log.w(TAG, "pendingTun close failed: ${it.message}") }
        }
        if (active != null) {
            runCatching { active.close() }
                .onSuccess { Log.i(TAG, "tunInterface closed") }
                .onFailure { Log.w(TAG, "tunInterface close failed: ${it.message}") }
        }

        // اگر هسته هرگز استارت نشد، کپی fd هنوز مال ماست و باید بسته شود
        val orphan = coreTunFd
        coreTunFd = -1
        if (orphan > 0) {
            runCatching { ParcelFileDescriptor.adoptFd(orphan).close() }
                .onSuccess { Log.i(TAG, "coreTunFd($orphan) closed") }
                .onFailure { Log.w(TAG, "coreTunFd close failed: ${it.message}") }
        }
    }
}
