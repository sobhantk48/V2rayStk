#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
رفع مشکل توقف Tor روی 50%:
  1. جایگزینی timeout مطلق با stall-detection (تا وقتی درصد بالا می‌رود، صبر کن)
  2. تغییر ترتیب: obfs4 اول (سریع‌تر)، Snowflake بعد
  3. تشخیص مرگ پروسه tor و رد شدن سریع به پروفایل بعدی
  4. افزودن پارامترهای torrc برای سبک کردن مرحله loading_descriptors
  5. افزایش TOR_BOOTSTRAP_TIMEOUT_MS به 300 ثانیه
"""
import os
import re
import shutil
import sys
from datetime import datetime

ROOT = os.path.abspath(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
VPN = os.path.join(ROOT, "android/app/src/main/kotlin/com/example/v2ray_stk/vpn")
TOR_DAEMON = os.path.join(VPN, "TorDaemon.kt")
VPN_SERVICE = os.path.join(VPN, "V2rayVpnService.kt")
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")


def backup(path):
    if not os.path.exists(path):
        print("  ! پیدا نشد: %s" % path)
        return False
    dst = "%s.torstall.bak_%s" % (path, STAMP)
    shutil.copy2(path, dst)
    print("  + بکاپ: %s" % os.path.basename(dst))
    return True


TOR_DAEMON_SRC = r'''package com.example.v2ray_stk.vpn

import android.content.Context
import android.util.Log
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

/**
 * دیمن Tor با پشتیبانی کامل از Pluggable Transport (obfs4 / Snowflake).
 *
 * منطق کار:
 *  - start() غیرمسدودکننده است و یک ترد supervisor راه می‌اندازد.
 *  - supervisor به ترتیب پروفایل‌ها را امتحان می‌کند تا یکی به 100% برسد.
 *  - هر تلاش با «تشخیص توقف» سنجیده می‌شود، نه تایم‌اوت مطلق:
 *      تا وقتی درصد بوت‌استرپ بالا می‌رود، صبر می‌کنیم.
 *      فقط اگر درصد برای stallMs ثابت بماند یا از capMs بگذرد، شکست است.
 *    دلیل: مرحله «loading_descriptors» (50%) روی Snowflake می‌تواند
 *    چند دقیقه طول بکشد و تایم‌اوت مطلق آن را وسط کار می‌کشت.
 */
class TorDaemon(private val context: Context) {

    companion object {
        private const val TAG = "TorDaemon"
        const val SOCKS_PORT = 9050
        const val DNS_PORT = 5353

        private val BOOTSTRAP_RE = Regex("Bootstrapped\\s+(\\d{1,3})")

        /** فاصله نمونه‌برداری از پیشرفت */
        private const val POLL_MS = 1000L

        // ------------------------------------------------- obfs4 (سریع‌ترین)
        private const val OBFS4_1 =
            "obfs4 193.11.166.194:27015 " +
            "2D82C2E354D531A68469ADF7F878FA6060C6BACA " +
            "cert=4TLQPJrTSaDffMK7Nbao6LC7G9OW/NHkUwIdjLSS3KYf0Nv4/nQiiI8dY2TcsQx01NniOg " +
            "iat-mode=0"

        private const val OBFS4_2 =
            "obfs4 209.148.46.65:443 " +
            "74FAD13168806246602538555B5521A0383A1875 " +
            "cert=ssH+9rP8dG2NLDN2XuFw63hIO/9MNNinLmxQDpVa+7kTOa9/m+tGWT1SmSYpQ9uTBGa6Hw " +
            "iat-mode=0"

        // ------------------------------------------------- Snowflake (cdn77)
        private const val SNOWFLAKE_CDN77 =
            "snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 " +
            "fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 " +
            "url=https://1098762253.rsc.cdn77.org/ " +
            "fronts=www.cdn77.com,www.phpmyadmin.net " +
            "ice=stun:stun.l.google.com:19302,stun:stun.antisip.com:3478," +
            "stun:stun.bluesip.net:3478,stun:stun.dus.net:3478," +
            "stun:stun.epygi.com:3478,stun:stun.sonetel.com:3478," +
            "stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478," +
            "stun:stun.voys.nl:3478 " +
            "utls-imitate=hellorandomizedalpn"

        // ------------------------------------------------- Snowflake (fastly)
        private const val SNOWFLAKE_FASTLY =
            "snowflake 192.0.2.4:80 8838024498816A039FCBBAB14E6F40A0843051FA " +
            "fingerprint=8838024498816A039FCBBAB14E6F40A0843051FA " +
            "url=https://snowflake-broker.torproject.net.global.prod.fastly.net/ " +
            "front=foursquare.com " +
            "ice=stun:stun.l.google.com:19302,stun:stun.voip.blackberry.com:3478 " +
            "utls-imitate=hellorandomizedalpn"
    }

    /**
     * یک پروفایل تلاش برای اتصال.
     *
     * @param stallMs حداکثر مدتی که درصد بوت‌استرپ می‌تواند بی‌حرکت بماند.
     *   برای Snowflake بلند است، چون بین 50% و 75% هیچ درصد میانی چاپ نمی‌شود.
     * @param capMs سقف مطلق کل این تلاش، حتی اگر پیشرفت ادامه داشته باشد.
     */
    private data class Attempt(
        val label: String,
        val transport: String?,      // null = اتصال مستقیم بدون بریج
        val bridges: List<String>,
        val stallMs: Long,
        val capMs: Long
    )

    private var torProcess: Process? = null
    private var logThread: Thread? = null
    private var supervisor: Thread? = null

    // latch کل زنجیره
    private val overallLatch = CountDownLatch(1)

    // latch تلاش جاری
    @Volatile
    private var attemptLatch: CountDownLatch? = null

    private val bestProgress = AtomicInteger(0)
    private val attemptProgress = AtomicInteger(0)
    private val failed = AtomicBoolean(false)
    private val stopping = AtomicBoolean(false)
    private val succeeded = AtomicBoolean(false)

    @Volatile
    private var activeLabel: String = "-"

    /** آخرین بهترین درصد بوت‌استرپ */
    val bootstrapPercent: Int
        get() = bestProgress.get()

    /** برچسب پروفایلی که در حال استفاده است */
    val activeProfile: String
        get() = activeLabel

    /** آیا تور آماده پذیرش اتصال SOCKS است */
    val isReady: Boolean
        get() = succeeded.get() && !stopping.get()

    // ------------------------------------------------------------------ start

    @Synchronized
    fun start() {
        if (supervisor != null) {
            Log.d(TAG, "Tor supervisor is already running.")
            return
        }
        val ptDir = File(context.applicationInfo.nativeLibraryDir)
        val snowflakeBin = File(ptDir, "libsnowflake.so")
        val obfs4Bin = File(ptDir, "libobfs4proxy.so")

        Log.i(TAG, "PT dir: " + ptDir.absolutePath)
        Log.i(TAG, "snowflake=" + snowflakeBin.exists() + " obfs4=" + obfs4Bin.exists())

        val plan = ArrayList<Attempt>()

        // obfs4 اول: تونل TCP مستقیم، دانلود descriptor چند برابر سریع‌تر از WebRTC
        if (obfs4Bin.exists()) {
            plan.add(
                Attempt(
                    label = "obfs4",
                    transport = "obfs4",
                    bridges = listOf(OBFS4_1, OBFS4_2),
                    stallMs = 60_000L,
                    capMs = 150_000L
                )
            )
        }

        // Snowflake بعد: مقاوم‌تر در برابر فیلترینگ ولی کندتر
        if (snowflakeBin.exists()) {
            plan.add(
                Attempt(
                    label = "Snowflake/cdn77",
                    transport = "snowflake",
                    bridges = listOf(SNOWFLAKE_CDN77),
                    stallMs = 90_000L,
                    capMs = 200_000L
                )
            )
            plan.add(
                Attempt(
                    label = "Snowflake/fastly",
                    transport = "snowflake",
                    bridges = listOf(SNOWFLAKE_FASTLY),
                    stallMs = 90_000L,
                    capMs = 180_000L
                )
            )
        }

        plan.add(
            Attempt(
                label = "Direct",
                transport = null,
                bridges = emptyList(),
                stallMs = 45_000L,
                capMs = 90_000L
            )
        )

        Log.i(TAG, "پلن اتصال: " + plan.joinToString(" -> ") { it.label })

        supervisor = thread(name = "tor-supervisor", isDaemon = true) {
            runPlan(plan)
        }
    }

    private fun runPlan(plan: List<Attempt>) {
        for (attempt in plan) {
            if (stopping.get()) break

            activeLabel = attempt.label
            attemptProgress.set(0)
            val latch = CountDownLatch(1)
            attemptLatch = latch

            Log.i(TAG, "=== تلاش اتصال: " + attempt.label + " ===")

            if (!launchTor(attempt)) {
                Log.e(TAG, "راه‌اندازی پروسه تور برای " + attempt.label + " ناموفق بود")
                killProcess()
                continue
            }

            if (awaitAttempt(attempt, latch)) {
                succeeded.set(true)
                Log.i(
                    TAG,
                    "✓ تور با " + attempt.label + " آماده شد - SOCKS 127.0.0.1:" + SOCKS_PORT
                )
                overallLatch.countDown()
                return
            }

            Log.w(TAG, "✗ " + attempt.label + " ناموفق (آخرین درصد: " + attemptProgress.get() + "%)")
            killProcess()
        }

        if (!stopping.get()) {
            Log.e(
                TAG,
                "همه پروفایل‌های اتصال تور شکست خوردند (بهترین: " + bestProgress.get() + "%)"
            )
            failed.set(true)
        }
        overallLatch.countDown()
    }

    /**
     * منتظر یک تلاش می‌ماند با منطق «تشخیص توقف».
     *
     * تا وقتی درصد بوت‌استرپ در حال افزایش است صبر می‌کنیم؛ شکست فقط وقتی است که:
     *  - درصد به مدت stallMs بی‌حرکت بماند، یا
     *  - کل تلاش از capMs بگذرد، یا
     *  - پروسه tor بمیرد.
     *
     * @return true اگر به 100% رسید
     */
    private fun awaitAttempt(attempt: Attempt, latch: CountDownLatch): Boolean {
        val startedAt = System.currentTimeMillis()
        var lastPct = -1
        var lastChangeAt = startedAt

        while (true) {
            if (stopping.get()) return false

            // اگر latch باز شد یعنی 100% رسیدیم یا استریم لاگ بسته شد
            val opened = try {
                latch.await(POLL_MS, TimeUnit.MILLISECONDS)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
                return false
            }
            if (opened) {
                val pct = attemptProgress.get()
                if (pct >= 100) return true
                Log.w(TAG, attempt.label + ": استریم لاگ تور بسته شد در " + pct + "%")
                return false
            }

            val now = System.currentTimeMillis()
            val pct = attemptProgress.get()

            if (pct != lastPct) {
                lastPct = pct
                lastChangeAt = now
                Log.d(
                    TAG,
                    "پیشرفت " + attempt.label + ": " + pct + "% (" +
                        ((now - startedAt) / 1000) + "s)"
                )
            }

            // پروسه tor کرش کرده؟ منتظر ماندن بی‌فایده است
            val proc = torProcess
            if (proc != null && !proc.isAlive) {
                Log.w(TAG, attempt.label + ": پروسه tor خاتمه یافت در " + pct + "%")
                return false
            }

            val stalledFor = now - lastChangeAt
            if (stalledFor >= attempt.stallMs) {
                Log.w(
                    TAG,
                    attempt.label + ": درصد " + pct + "% به مدت " +
                        (stalledFor / 1000) + "s ثابت ماند، رد شدن به پروفایل بعدی"
                )
                return false
            }

            val elapsed = now - startedAt
            if (elapsed >= attempt.capMs) {
                Log.w(
                    TAG,
                    attempt.label + ": سقف کل " + (attempt.capMs / 1000) +
                        "s رسید (در " + pct + "%)"
                )
                return false
            }
        }
    }

    // ------------------------------------------------------------ launch tor

    private fun launchTor(attempt: Attempt): Boolean {
        val torBinary = File(context.applicationInfo.nativeLibraryDir, "libtor.so")
        if (!torBinary.exists()) {
            Log.e(TAG, "Tor binary (libtor.so) not found at " + torBinary.absolutePath)
            return false
        }

        val dataDir = File(context.filesDir, "tordata")
        if (!dataDir.exists()) dataDir.mkdirs()
        runCatching {
            dataDir.setReadable(false, false)
            dataDir.setWritable(false, false)
            dataDir.setExecutable(false, false)
            dataDir.setReadable(true, true)
            dataDir.setWritable(true, true)
            dataDir.setExecutable(true, true)
        }

        val ptStateDir = File(dataDir, "pt_state")
        if (!ptStateDir.exists()) ptStateDir.mkdirs()

        val torrc = File(context.filesDir, "torrc")
        if (!writeTorrc(torrc, dataDir, attempt)) return false

        val proc = try {
            val pb = ProcessBuilder(torBinary.absolutePath, "-f", torrc.absolutePath)
            pb.directory(context.filesDir)
            pb.redirectErrorStream(true)
            // بدون این متغیرها، pluggable transport روی اندروید بالا نمی‌آید
            val env = pb.environment()
            env["HOME"] = context.filesDir.absolutePath
            env["TMPDIR"] = context.cacheDir.absolutePath
            env["TOR_PT_STATE_LOCATION"] = ptStateDir.absolutePath
            env["TOR_PT_MANAGED_TRANSPORT_VER"] = "1"
            env["TOR_PT_EXIT_ON_STDIN_CLOSE"] = "1"
            pb.start()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Tor daemon", e)
            return false
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
                // پایان پروسه = پایان این تلاش
                attemptLatch?.countDown()
            }
        }
        return true
    }

    private fun writeTorrc(torrc: File, dataDir: File, attempt: Attempt): Boolean {
        val ptDir = context.applicationInfo.nativeLibraryDir
        val lines = ArrayList<String>()

        lines.add("SocksPort 127.0.0.1:" + SOCKS_PORT)
        lines.add("DNSPort 127.0.0.1:" + DNS_PORT)
        lines.add("AutomapHostsOnResolve 1")
        lines.add("AutomapHostsSuffixes .onion,.exit")
        lines.add("VirtualAddrNetworkIPv4 172.30.0.0/16")
        lines.add("ClientDNSRejectInternalAddresses 1")
        lines.add("ClientOnly 1")
        lines.add("CookieAuthentication 0")
        lines.add("AvoidDiskWrites 1")
        lines.add("DataDirectory " + dataDir.absolutePath)
        lines.add("DormantCanceledByStartup 1")
        lines.add("DormantClientTimeout 24 hours")
        lines.add("ClientUseIPv6 1")

        // ---- سبک کردن مرحله «loading_descriptors» که روی 50% گیر می‌کرد ----
        // فقط microdescriptor بگیر، نه descriptor کامل (حجم بسیار کمتر)
        lines.add("UseMicrodescriptors 1")
        // اطلاعات دایرکتوری را زودتر/اضافه‌تر از نیاز نگیر
        lines.add("FetchDirInfoEarly 0")
        lines.add("FetchDirInfoExtraEarly 0")
        // descriptor رله‌هایی که هرگز استفاده نمی‌شوند را دانلود نکن
        lines.add("FetchUselessDescriptors 0")
        // padding کمتر: مصرف باتری و پهنای باند موبایل را پایین می‌آورد
        lines.add("ReducedConnectionPadding 1")
        // روی لینک کند، تخمین خودکار CBT باعث قطع مدارهای سالم می‌شود
        lines.add("LearnCircuitBuildTimeout 0")
        lines.add("CircuitBuildTimeout 90")

        lines.add("Log notice stdout")

        if (attempt.transport != null && attempt.bridges.isNotEmpty()) {
            lines.add("UseBridges 1")
            when (attempt.transport) {
                "snowflake" -> lines.add(
                    "ClientTransportPlugin snowflake exec " + ptDir + "/libsnowflake.so"
                )
                "obfs4" -> lines.add(
                    "ClientTransportPlugin obfs4 exec " + ptDir + "/libobfs4proxy.so"
                )
            }
            for (b in attempt.bridges) {
                lines.add("Bridge " + b)
            }
        } else {
            lines.add("UseBridges 0")
        }

        return runCatching {
            torrc.writeText(lines.joinToString("\n") + "\n")
            Log.d(TAG, "torrc نوشته شد (" + lines.size + " خط) برای " + attempt.label)
        }.onFailure {
            Log.e(TAG, "cannot write torrc: " + it.message)
        }.isSuccess
    }

    // --------------------------------------------------------------- logging

    private fun handleLine(line: String) {
        Log.d("TorLogs", line)

        val m = BOOTSTRAP_RE.find(line)
        if (m != null) {
            val pct = m.groupValues[1].toIntOrNull() ?: return
            attemptProgress.set(pct)
            if (pct > bestProgress.get()) bestProgress.set(pct)
            if (pct >= 100) {
                attemptLatch?.countDown()
            }
            return
        }

        if (line.contains("[err]")) {
            Log.e(TAG, "Tor error: " + line)
        } else if (line.contains("[warn]")) {
            Log.w(TAG, "Tor warn: " + line)
        }
    }

    // ----------------------------------------------------------------- await

    /**
     * تا آماده شدن تور صبر می‌کند. هرگز روی ترد main صدا نزنید.
     * @return true اگر یکی از پروفایل‌ها به 100% رسید
     */
    fun awaitBootstrap(timeoutMs: Long): Boolean {
        if (supervisor == null) {
            Log.w(TAG, "awaitBootstrap فراخوانی شد ولی تور استارت نشده بود")
            return false
        }
        val done = try {
            overallLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        if (!done) {
            Log.w(TAG, "تایم‌اوت کلی بوت‌استرپ تور در " + bestProgress.get() + "%")
            return false
        }
        return succeeded.get() && !failed.get()
    }

    // ------------------------------------------------------------------ stop

    private fun killProcess() {
        runCatching {
            torProcess?.let { p ->
                p.destroy()
                runCatching { p.waitFor(3, TimeUnit.SECONDS) }
                if (p.isAlive) runCatching { p.destroyForcibly() }
            }
        }
        torProcess = null
        logThread = null
    }

    @Synchronized
    fun stop() {
        stopping.set(true)
        try {
            killProcess()
            supervisor = null
            attemptLatch?.countDown()
            overallLatch.countDown()
            succeeded.set(false)
            bestProgress.set(0)
            attemptProgress.set(0)
            activeLabel = "-"
            Log.i(TAG, "Tor daemon stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Tor daemon", e)
        }
    }
}
'''


def patch_tor_daemon():
    print("[1/2] بازنویسی TorDaemon.kt")
    if not backup(TOR_DAEMON):
        return False
    with open(TOR_DAEMON, "w", encoding="utf-8") as f:
        f.write(TOR_DAEMON_SRC)
    n = TOR_DAEMON_SRC.count("\n")
    print("  ✓ نوشته شد (%d خط)" % n)
    return True


def patch_vpn_service():
    print("[2/2] افزایش TOR_BOOTSTRAP_TIMEOUT_MS")
    if not backup(VPN_SERVICE):
        return False
    with open(VPN_SERVICE, "r", encoding="utf-8") as f:
        src = f.read()

    pat = re.compile(r"(TOR_BOOTSTRAP_TIMEOUT_MS\s*=\s*)(\d[\d_]*L)")
    m = pat.search(src)
    if not m:
        print("  ! ثابت TOR_BOOTSTRAP_TIMEOUT_MS پیدا نشد")
        return False

    old = m.group(2)
    if old == "300_000L":
        print("  = از قبل 300_000L است")
        return True

    src = pat.sub(r"\g<1>300_000L", src, count=1)
    with open(VPN_SERVICE, "w", encoding="utf-8") as f:
        f.write(src)
    print("  ✓ %s -> 300_000L" % old)
    return True


def main():
    print("=" * 60)
    print("پچ رفع توقف Tor روی 50%")
    print("ریشه پروژه: %s" % ROOT)
    print("=" * 60)

    ok = patch_tor_daemon()
    ok = patch_vpn_service() and ok

    print("=" * 60)
    if ok:
        print("✓ تمام شد")
    else:
        print("✗ با خطا تمام شد — بکاپ‌ها با پسوند .torstall.bak_%s موجودند" % STAMP)
        sys.exit(1)


if __name__ == "__main__":
    main()
