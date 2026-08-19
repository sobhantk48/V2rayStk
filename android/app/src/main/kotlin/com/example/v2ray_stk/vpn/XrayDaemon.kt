package com.example.v2ray_stk.vpn

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

/**
 * دیمن Xray-core به صورت پروسه native جداگانه.
 *
 * چرا پروسه جدا و نه JNI:
 *  - ایزولاسیون کامل: کرش هسته، اپ را نمی‌کشد.
 *  - دقیقا همان الگوی TorDaemon که در این پروژه تست شده است.
 *  - باینری در jniLibs با نام libxray.so قرار گرفته تا اندروید آن را
 *    در nativeLibraryDir با مجوز اجرا استخراج کند (دور زدن W^X).
 *
 * معماری زنجیره:
 *   TUN (sing-box) -> outbound socks به 127.0.0.1:10808 -> Xray -> سرور
 *
 * Xray هرگز مالک TUN نیست؛ routing و DNS همچنان کار sing-box است.
 */
class XrayDaemon(private val context: Context) {

    companion object {
        private const val TAG = "XrayDaemon"

        /** inbound socks که sing-box به آن وصل می شود */
        const val SOCKS_PORT = 10808

        /** inbound http اختیاری برای local proxy mode */
        const val HTTP_PORT = 10809

        private const val BIN_NAME = "libxray.so"
        private const val WORK_DIR_NAME = "xray"
        private const val CONFIG_NAME = "config.json"
        private const val ASSET_DIR = "xray"
        private val GEO_FILES = listOf("geoip.dat", "geosite.dat")

        private const val PROBE_INTERVAL_MS = 200L
        private const val PROBE_CONNECT_TIMEOUT_MS = 400
        private const val DEFAULT_READY_TIMEOUT_MS = 10_000L

        private const val MAX_LOG_LINES = 400
        private const val MAX_RESTARTS = 3
        private const val RESTART_BACKOFF_MS = 1_500L
        private const val WATCHDOG_POLL_MS = 1_000L
    }

    private var process: Process? = null
    private var logThread: Thread? = null
    private var watchdogThread: Thread? = null

    private val stopping = AtomicBoolean(false)
    private val running = AtomicBoolean(false)
    private val restartCount = AtomicInteger(0)

    @Volatile
    private var lastConfig: String? = null

    @Volatile
    var lastError: String? = null
        private set

    private val logBuffer = ArrayDeque<String>()

    // ------------------------------------------------------------- وضعیت

    /** آیا باینری داخل APK استخراج شده و قابل اجراست */
    val isAvailable: Boolean
        get() = binaryFile().let { it.exists() && it.canExecute() }

    /** آیا پروسه Xray زنده است */
    val isRunning: Boolean
        get() = running.get() && (process?.isAlive == true)

    /** آدرسی که در outbound سینگ باکس ست می شود */
    val socksAddress: String
        get() = "127.0.0.1:" + SOCKS_PORT

    fun binaryFile(): File =
        File(context.applicationInfo.nativeLibraryDir, BIN_NAME)

    private fun workDir(): File {
        val dir = File(context.filesDir, WORK_DIR_NAME)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    // ------------------------------------------------------------- نسخه

    /**
     * نسخه Xray را با اجرای کوتاه باینری می خواند.
     * برای تشخیص سالم بودن باینری قبل از اتصال واقعی مفید است.
     */
    fun version(): String? {
        val bin = binaryFile()
        if (!bin.exists()) {
            lastError = "libxray.so در " + bin.absolutePath + " پیدا نشد"
            Log.e(TAG, lastError!!)
            return null
        }
        return try {
            val pb = ProcessBuilder(bin.absolutePath, "version")
            pb.directory(workDir())
            pb.redirectErrorStream(true)
            val p = pb.start()
            val line = p.inputStream.bufferedReader().use { it.readLine() }
            p.waitFor(3, TimeUnit.SECONDS)
            if (p.isAlive) p.destroyForcibly()
            Log.i(TAG, "نسخه Xray: " + line)
            line
        } catch (e: Exception) {
            lastError = "اجرای باینری Xray ناموفق: " + e.message
            Log.e(TAG, lastError!!, e)
            null
        }
    }

    // ------------------------------------------------------------- start

    /**
     * Xray را با کانفیگ داده شده بالا می آورد و تا باز شدن پورت socks صبر می کند.
     * هرگز روی ترد main صدا نزنید.
     *
     * @return true اگر پورت socks آماده پذیرش اتصال شد
     */
    @Synchronized
    fun start(configJson: String, readyTimeoutMs: Long = DEFAULT_READY_TIMEOUT_MS): Boolean {
        if (isRunning) {
            Log.d(TAG, "Xray از قبل در حال اجراست، ابتدا stop می شود")
            stopInternal()
        }

        stopping.set(false)
        lastError = null
        lastConfig = configJson
        restartCount.set(0)
        clearLogs()

        if (!launch(configJson)) return false

        val ready = waitForSocks(readyTimeoutMs)
        if (!ready) {
            lastError = "پورت socks " + SOCKS_PORT + " در " + readyTimeoutMs + "ms باز نشد"
            Log.e(TAG, lastError!!)
            dumpRecentLogs()
            stopInternal()
            return false
        }

        running.set(true)
        startWatchdog()
        Log.i(TAG, "✓ Xray آماده شد - SOCKS " + socksAddress)
        return true
    }

    private fun launch(configJson: String): Boolean {
        val bin = binaryFile()
        if (!bin.exists()) {
            lastError = "libxray.so پیدا نشد: " + bin.absolutePath
            Log.e(TAG, lastError!!)
            return false
        }

        val dir = workDir()
        ensureGeoAssets(dir)
        val cfg = File(dir, CONFIG_NAME)
        val ok = runCatching { cfg.writeText(configJson) }
            .onFailure {
                lastError = "نوشتن config.json ناموفق: " + it.message
                Log.e(TAG, lastError!!)
            }.isSuccess
        if (!ok) return false

        Log.i(TAG, "config نوشته شد (" + configJson.length + " بایت) در " + cfg.absolutePath)

        val proc = try {
            val pb = ProcessBuilder(bin.absolutePath, "run", "-c", cfg.absolutePath)
            pb.directory(dir)
            pb.redirectErrorStream(true)
            val env = pb.environment()
            env["HOME"] = dir.absolutePath
            env["TMPDIR"] = context.cacheDir.absolutePath
            // geo assets در ensureGeoAssets داخل همین dir کپی شده اند.
            env["XRAY_LOCATION_ASSET"] = dir.absolutePath
            env["XRAY_LOCATION_CONFIG"] = dir.absolutePath
            pb.start()
        } catch (e: Exception) {
            lastError = "start پروسه Xray ناموفق: " + e.message
            Log.e(TAG, lastError!!, e)
            return false
        }

        process = proc

        logThread = thread(name = "xray-log", isDaemon = true) {
            try {
                proc.inputStream.bufferedReader().useLines { seq ->
                    seq.forEach { handleLine(it) }
                }
            } catch (e: Exception) {
                if (!stopping.get()) Log.w(TAG, "xray log reader ended: " + e.message)
            }
        }
        return true
    }

    // ------------------------------------------------------------- آمادگی

    /**
     * آمادگی را با اتصال واقعی TCP به پورت socks می سنجد، نه با پارس لاگ.
     * دلیل: در loglevel های پایین Xray هیچ خط started چاپ نمی کند.
     */
    /**
     * geoip.dat / geosite.dat را از assets به filesDir/xray کپی می کند.
     * Xray فقط از مسیر XRAY_LOCATION_ASSET می خواند و به assets اندروید
     * دسترسی مستقیم ندارد، پس کپی یکبار در اولین اجرا لازم است.
     * اگر اندازه فایل مقصد با assets فرق کند دوباره کپی می شود (آپدیت).
     */
    private fun ensureGeoAssets(dir: File) {
        for (name in GEO_FILES) {
            val target = File(dir, name)
            val assetPath = ASSET_DIR + "/" + name
            try {
                val expected = context.assets.openFd(assetPath).use { it.length }
                if (target.exists() && target.length() == expected) continue
            } catch (e: Exception) {
                // openFd روی فایل های فشرده شده خطا می دهد؛ با اندازه صفر ادامه می دهیم
                if (target.exists() && target.length() > 0L) continue
            }
            try {
                context.assets.open(assetPath).use { input ->
                    FileOutputStream(target).use { out -> input.copyTo(out, 64 * 1024) }
                }
                Log.i(TAG, "geo asset کپی شد: " + name + " (" + target.length() + " بایت)")
            } catch (e: Exception) {
                Log.w(TAG, "geo asset " + name + " کپی نشد: " + e.message)
            }
        }
    }

    private fun waitForSocks(timeoutMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < deadline) {
            if (stopping.get()) return false

            val proc = process
            if (proc != null && !proc.isAlive) {
                val code = runCatching { proc.exitValue() }.getOrNull()
                lastError = "پروسه Xray بلافاصله خاتمه یافت (exit=" + code + ")"
                Log.e(TAG, lastError!!)
                return false
            }

            if (probePort(SOCKS_PORT)) return true

            try {
                Thread.sleep(PROBE_INTERVAL_MS)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
                return false
            }
        }
        return probePort(SOCKS_PORT)
    }

    private fun probePort(port: Int): Boolean = try {
        Socket().use { s ->
            s.connect(InetSocketAddress("127.0.0.1", port), PROBE_CONNECT_TIMEOUT_MS)
            true
        }
    } catch (e: Exception) {
        false
    }

    // ------------------------------------------------------------ watchdog

    private fun startWatchdog() {
        watchdogThread = thread(name = "xray-watchdog", isDaemon = true) {
            while (!stopping.get()) {
                try {
                    Thread.sleep(WATCHDOG_POLL_MS)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    return@thread
                }
                if (stopping.get()) return@thread

                val proc = process
                if (proc == null || proc.isAlive) continue

                val code = runCatching { proc.exitValue() }.getOrNull()
                Log.w(TAG, "پروسه Xray مرد (exit=" + code + ")")
                dumpRecentLogs()

                val cfg = lastConfig
                val attempt = restartCount.incrementAndGet()
                if (cfg == null || attempt > MAX_RESTARTS) {
                    lastError = "Xray پس از " + (attempt - 1) + " تلاش restart بالا نیامد"
                    Log.e(TAG, lastError!!)
                    running.set(false)
                    return@thread
                }

                Log.i(TAG, "restart خودکار Xray - تلاش " + attempt + "/" + MAX_RESTARTS)
                try {
                    Thread.sleep(RESTART_BACKOFF_MS)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    return@thread
                }
                if (stopping.get()) return@thread

                if (launch(cfg) && waitForSocks(DEFAULT_READY_TIMEOUT_MS)) {
                    Log.i(TAG, "✓ Xray بازیابی شد")
                } else {
                    Log.w(TAG, "restart تلاش " + attempt + " ناموفق بود")
                }
            }
        }
    }

    // ------------------------------------------------------------- logging

    private fun handleLine(line: String) {
        Log.d("XrayLogs", line)
        synchronized(logBuffer) {
            logBuffer.addLast(line)
            while (logBuffer.size > MAX_LOG_LINES) logBuffer.removeFirst()
        }
        if (line.contains("failed to", true) || line.contains("[Error]")) {
            Log.e(TAG, "Xray error: " + line)
        }
    }

    /** آخرین خطوط لاگ برای نمایش در Log Viewer اپ */
    fun recentLogs(limit: Int = 100): List<String> = synchronized(logBuffer) {
        logBuffer.toList().takeLast(limit)
    }

    private fun clearLogs() = synchronized(logBuffer) { logBuffer.clear() }

    private fun dumpRecentLogs() {
        val logs = recentLogs(25)
        if (logs.isEmpty()) {
            Log.w(TAG, "هیچ لاگی از Xray ثبت نشد (باینری اجرا نشد؟)")
            return
        }
        Log.w(TAG, "--- آخرین لاگ های Xray ---")
        logs.forEach { Log.w(TAG, "  " + it) }
    }

    // ---------------------------------------------------------------- stop

    @Synchronized
    fun stop() {
        Log.i(TAG, "Stopping Xray daemon...")
        stopping.set(true)
        stopInternal()
        stopping.set(false)
        restartCount.set(0)
        lastConfig = null
    }

    private fun stopInternal() {
        running.set(false)
        runCatching {
            process?.let { p ->
                p.destroy()
                runCatching { p.waitFor(3, TimeUnit.SECONDS) }
                if (p.isAlive) runCatching { p.destroyForcibly() }
            }
        }
        process = null
        logThread = null
        watchdogThread = null
    }
}
