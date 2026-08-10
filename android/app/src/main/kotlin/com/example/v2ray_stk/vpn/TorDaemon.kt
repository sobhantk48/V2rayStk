package com.example.v2ray_stk.vpn

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
