#!/usr/bin/env python3
"""استارت sing-box را تا Bootstrapped 100% تور عقب می‌اندازد."""
import pathlib, shutil, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ROOT / "android/app/src/main/kotlin/com/example/v2ray_stk/vpn"
TRASH = ROOT / ".trash_bak"
TRASH.mkdir(exist_ok=True)

TOR_KT = r'''package com.example.v2ray_stk.vpn

import android.content.Context
import android.util.Log
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

/**
 * دیمن Tor با انتظار واقعی برای بوت‌استرپ.
 * start() غیرمسدودکننده است؛ awaitBootstrap() تا رسیدن به 100% صبر می‌کند.
 */
class TorDaemon(private val context: Context) {

    companion object {
        private const val TAG = "TorDaemon"
        const val SOCKS_PORT = 9050
        const val DNS_PORT = 5353
        private val BOOTSTRAP_RE = Regex("Bootstrapped\\s+(\\d{1,3})")
    }

    private var torProcess: Process? = null
    private var logThread: Thread? = null

    private val bootstrapLatch = CountDownLatch(1)
    private val progress = AtomicInteger(0)
    private val failed = AtomicBoolean(false)
    private val stopping = AtomicBoolean(false)

    /** آخرین درصد بوت‌استرپ گزارش‌شده توسط تور */
    val bootstrapPercent: Int
        get() = progress.get()

    /** آیا تور آماده پذیرش اتصال SOCKS است */
    val isReady: Boolean
        get() = bootstrapLatch.count == 0L && !failed.get() && progress.get() >= 100

    @Synchronized
    fun start() {
        if (torProcess != null) {
            Log.d(TAG, "Tor daemon is already running.")
            return
        }

        // باینری از nativeLibraryDir خوانده می‌شود تا با W^X اندروید سازگار باشد
        val torBinary = File(context.applicationInfo.nativeLibraryDir, "libtor.so")
        if (!torBinary.exists()) {
            Log.e(TAG, "Tor binary (libtor.so) not found at " + torBinary.absolutePath)
            failed.set(true)
            bootstrapLatch.countDown()
            return
        }

        val dataDir = File(context.filesDir, "tordata")
        if (!dataDir.exists()) dataDir.mkdirs()
        // تور روی DataDirectory مجوز 0700 می‌خواهد
        runCatching {
            dataDir.setReadable(false, false)
            dataDir.setWritable(false, false)
            dataDir.setExecutable(false, false)
            dataDir.setReadable(true, true)
            dataDir.setWritable(true, true)
            dataDir.setExecutable(true, true)
        }

        val torrc = File(context.filesDir, "torrc")
        val lines = listOf(
            "SocksPort 127.0.0.1:" + SOCKS_PORT,
            "DNSPort 127.0.0.1:" + DNS_PORT,
            "AutomapHostsOnResolve 1",
            "AutomapHostsSuffixes .onion,.exit",
            "VirtualAddrNetworkIPv4 172.30.0.0/16",
            "ClientDNSRejectInternalAddresses 1",
            "ClientOnly 1",
            "CookieAuthentication 0",
            "AvoidDiskWrites 1",
            "DataDirectory " + dataDir.absolutePath,
            "Log notice stdout",
        )
        runCatching { torrc.writeText(lines.joinToString("\n") + "\n") }
            .onFailure {
                Log.e(TAG, "cannot write torrc: " + it.message)
                failed.set(true)
                bootstrapLatch.countDown()
                return
            }

        Log.d(TAG, "Starting Tor: " + torBinary.absolutePath)

        val proc = try {
            val pb = ProcessBuilder(torBinary.absolutePath, "-f", torrc.absolutePath)
            pb.directory(context.filesDir)
            pb.redirectErrorStream(true)
            pb.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Tor daemon", e)
            failed.set(true)
            bootstrapLatch.countDown()
            return
        }

        torProcess = proc

        logThread = thread(name = "tor-log", isDaemon = true) {
            try {
                proc.inputStream.bufferedReader().useLines { seq ->
                    seq.forEach { line -> handleLine(line) }
                }
            } catch (e: Exception) {
                if (!stopping.get()) Log.w(TAG, "tor log reader ended: " + e.message)
            } finally {
                if (bootstrapLatch.count > 0L) {
                    if (!stopping.get()) {
                        Log.e(TAG, "Tor exited before bootstrap completed")
                        failed.set(true)
                    }
                    bootstrapLatch.countDown()
                }
            }
        }
    }

    private fun handleLine(line: String) {
        Log.d("TorLogs", line)

        val m = BOOTSTRAP_RE.find(line)
        if (m != null) {
            val pct = m.groupValues[1].toIntOrNull() ?: return
            if (pct > progress.get()) progress.set(pct)
            if (pct >= 100) {
                Log.i(TAG, "Tor bootstrapped 100% - SOCKS ready on 127.0.0.1:" + SOCKS_PORT)
                bootstrapLatch.countDown()
            }
            return
        }

        if (line.contains("[err]")) {
            Log.e(TAG, "Tor error: " + line)
        }
    }

    /**
     * تا آماده شدن تور صبر می‌کند. هرگز روی ترد main صدا نزنید.
     * @return true اگر بوت‌استرپ کامل شد
     */
    fun awaitBootstrap(timeoutMs: Long): Boolean {
        if (torProcess == null && bootstrapLatch.count > 0L) {
            Log.w(TAG, "awaitBootstrap فراخوانی شد ولی تور استارت نشده بود")
            return false
        }
        val done = try {
            bootstrapLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        if (!done) {
            Log.w(TAG, "تایم‌اوت بوت‌استرپ تور در " + progress.get() + "%")
            return false
        }
        return !failed.get()
    }

    @Synchronized
    fun stop() {
        stopping.set(true)
        try {
            torProcess?.let { p ->
                p.destroy()
                runCatching { p.waitFor(3, TimeUnit.SECONDS) }
                if (p.isAlive) runCatching { p.destroyForcibly() }
            }
            torProcess = null
            logThread = null
            bootstrapLatch.countDown()
            progress.set(0)
            Log.i(TAG, "Tor daemon stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Tor daemon", e)
        }
    }
}
'''

SVC_KT = r'''package com.example.v2ray_stk.vpn

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
                stopVpn()
                return START_NOT_STICKY
            }

            else -> {
                val config = intent?.getStringExtra(EXTRA_CONFIG).orEmpty()
                val torEnabled = intent?.getBooleanExtra(EXTRA_TOR_ENABLED, false) ?: false
                startVpn(config, torEnabled)
            }
        }
        return START_STICKY
    }

    private fun startVpn(config: String, torEnabled: Boolean) {
        stopping = false
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
            if (tun == null) {
                Log.e(TAG, "establish() برگشت null (اجازه VPN صادر نشده؟)")
                VpnState.update(VpnStatus.DISCONNECTED)
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
            VpnState.update(VpnStatus.DISCONNECTED)
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
            VpnState.update(VpnStatus.CONNECTED)

            startBridgeWatch()
        } catch (e: Throwable) {
            Log.e(TAG, "launchCore failed", e)
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

    private fun establishTun(): ParcelFileDescriptor? {
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

        // ترافیک خود اپ (و پروسه tor) از تونل خارج می‌ماند تا حلقه ایجاد نشود
        runCatching { builder.addDisallowedApplication(packageName) }

        return builder.establish()
    }

    private fun stopVpn() {
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

}
'''

targets = {
    "TorDaemon.kt": TOR_KT,
    "V2rayVpnService.kt": SVC_KT,
}

for name, content in targets.items():
    path = BASE / name
    if not path.exists():
        print("MISSING: " + str(path))
        sys.exit(1)
    shutil.copy2(path, TRASH / (name + ".bak_bootstrap"))
    path.write_text(content, encoding="utf-8")
    print("OK  " + name + "  (" + str(len(content.splitlines())) + " lines)")

print("backup -> .trash_bak/*.bak_bootstrap")
