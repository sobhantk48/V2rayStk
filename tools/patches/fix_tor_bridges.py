#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_tor_bridges.py
اتصال بریج‌های Tor به torrc + زنجیره fallback + تمیزکاری tor_bridges.dart
"""
import os
import re
import shutil
import sys
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")

TOR_DAEMON = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/TorDaemon.kt"
VPN_SERVICE = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"
BRIDGES_DART = "lib/core/constants/tor_bridges.dart"


def backup(rel):
    src = os.path.join(ROOT, rel)
    if os.path.exists(src):
        dst = src + ".torfix.bak_" + STAMP
        shutil.copy2(src, dst)
        print("  backup -> " + os.path.basename(dst))


def write(rel, content):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("  written: " + rel + " (" + str(len(content.splitlines())) + " lines)")


# ---------------------------------------------------------------- TorDaemon.kt
TOR_DAEMON_KT = r'''package com.example.v2ray_stk.vpn

import android.content.Context
import android.util.Log
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

/**
 * دیمن Tor با پشتیبانی کامل از Pluggable Transport (Snowflake / obfs4).
 *
 * منطق کار:
 *  - start() غیرمسدودکننده است و یک ترد supervisor راه می‌اندازد.
 *  - supervisor به ترتیب پروفایل‌های اتصال را امتحان می‌کند تا یکی به 100% برسد.
 *  - awaitBootstrap() تا موفقیت یا شکست کل زنجیره صبر می‌کند.
 */
class TorDaemon(private val context: Context) {

    companion object {
        private const val TAG = "TorDaemon"
        const val SOCKS_PORT = 9050
        const val DNS_PORT = 5353

        private val BOOTSTRAP_RE = Regex("Bootstrapped\\s+(\\d{1,3})")

        // ------------------------------------------------- Snowflake (فعلی)
        // بروکر رسمی روی cdn77 - جایگزین fastly بازنشسته
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

        // ------------------------------------------------- obfs4 (محلی)
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
    }

    /** یک پروفایل تلاش برای اتصال */
    private data class Attempt(
        val label: String,
        val transport: String?,      // null = اتصال مستقیم بدون بریج
        val bridges: List<String>,
        val timeoutMs: Long
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
        if (snowflakeBin.exists()) {
            plan.add(Attempt("Snowflake/cdn77", "snowflake", listOf(SNOWFLAKE_CDN77), 60_000L))
            plan.add(Attempt("Snowflake/fastly", "snowflake", listOf(SNOWFLAKE_FASTLY), 60_000L))
        }
        if (obfs4Bin.exists()) {
            plan.add(Attempt("obfs4", "obfs4", listOf(OBFS4_1, OBFS4_2), 50_000L))
        }
        plan.add(Attempt("Direct", null, emptyList(), 40_000L))

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

            val done = try {
                latch.await(attempt.timeoutMs, TimeUnit.MILLISECONDS)
            } catch (e: InterruptedException) {
                Thread.currentThread().interrupt()
                false
            }

            if (done && attemptProgress.get() >= 100) {
                succeeded.set(true)
                Log.i(TAG, "✓ تور با " + attempt.label + " آماده شد - SOCKS 127.0.0.1:" + SOCKS_PORT)
                overallLatch.countDown()
                return
            }

            Log.w(TAG, "✗ " + attempt.label + " روی " + attemptProgress.get() + "% متوقف شد")
            killProcess()
        }

        if (!stopping.get()) {
            Log.e(TAG, "همه پروفایل‌های اتصال تور شکست خوردند (بهترین: " + bestProgress.get() + "%)")
            failed.set(true)
        }
        overallLatch.countDown()
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

# ------------------------------------------------------------- tor_bridges.dart
BRIDGES_DART_SRC = r'''/// بریج‌های Tor برای نمایش در UI و ارسال به لایه native.
///
/// نکته: منبع حقیقت (source of truth) برای اتصال واقعی،
/// فایل TorDaemon.kt است. این کلاس فقط برای نمایش و انتخاب کاربر است.
class TorBridges {
  const TorBridges._();

  /// Snowflake روی بروکر فعلی (cdn77)
  static const String snowflakeCdn77 =
      'snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
      'fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
      'url=https://1098762253.rsc.cdn77.org/ '
      'fronts=www.cdn77.com,www.phpmyadmin.net '
      'ice=stun:stun.l.google.com:19302,stun:stun.antisip.com:3478,'
      'stun:stun.bluesip.net:3478,stun:stun.dus.net:3478,'
      'stun:stun.epygi.com:3478,stun:stun.sonetel.com:3478,'
      'stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,'
      'stun:stun.voys.nl:3478 '
      'utls-imitate=hellorandomizedalpn';

  /// Snowflake روی بروکر قدیمی (fastly) - به عنوان fallback
  static const String snowflakeFastly =
      'snowflake 192.0.2.4:80 8838024498816A039FCBBAB14E6F40A0843051FA '
      'fingerprint=8838024498816A039FCBBAB14E6F40A0843051FA '
      'url=https://snowflake-broker.torproject.net.global.prod.fastly.net/ '
      'front=foursquare.com '
      'ice=stun:stun.l.google.com:19302,stun:stun.voip.blackberry.com:3478 '
      'utls-imitate=hellorandomizedalpn';

  static const String obfs4_1 =
      'obfs4 193.11.166.194:27015 '
      '2D82C2E354D531A68469ADF7F878FA6060C6BACA '
      'cert=4TLQPJrTSaDffMK7Nbao6LC7G9OW/NHkUwIdjLSS3KYf0Nv4/nQiiI8dY2TcsQx01NniOg '
      'iat-mode=0';

  static const String obfs4_2 =
      'obfs4 209.148.46.65:443 '
      '74FAD13168806246602538555B5521A0383A1875 '
      'cert=ssH+9rP8dG2NLDN2XuFw63hIO/9MNNinLmxQDpVa+7kTOa9/m+tGWT1SmSYpQ9uTBGa6Hw '
      'iat-mode=0';

  /// نگه‌داشتن نام قدیمی برای سازگاری با کدهای موجود
  static const String snowflake = snowflakeCdn77;

  /// لیست همه پروفایل‌ها برای نمایش در UI
  static List<Map<String, String>> getAllProfiles() {
    return const [
      {
        'name': 'Snowflake (cdn77)',
        'config': snowflakeCdn77,
        'type': 'snowflake',
      },
      {
        'name': 'Snowflake (fastly)',
        'config': snowflakeFastly,
        'type': 'snowflake',
      },
      {
        'name': 'obfs4 - 1',
        'config': obfs4_1,
        'type': 'obfs4',
      },
      {
        'name': 'obfs4 - 2',
        'config': obfs4_2,
        'type': 'obfs4',
      },
    ];
  }
}
'''


def patch_vpn_service():
    """timeout انتظار تور را بالا می‌برد تا کل زنجیره fallback فرصت اجرا داشته باشد."""
    path = os.path.join(ROOT, VPN_SERVICE)
    if not os.path.exists(path):
        print("  !! " + VPN_SERVICE + " پیدا نشد")
        return False

    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    original = src
    # هر عدد ~90000 که در خط awaitBootstrap باشد -> 230000
    pattern = re.compile(r"(awaitBootstrap\s*\(\s*)(90_?000|90_?000|90000)(\s*[LlF]?\s*\))")
    src, n = pattern.subn(r"\g<1>230_000L\g<3>", src)

    if n == 0:
        # حالت جایگزین: هر awaitBootstrap با عدد
        pattern2 = re.compile(r"(awaitBootstrap\s*\(\s*)(\d[\d_]*)(\s*[LlF]?\s*\))")
        src, n = pattern2.subn(r"\g<1>230_000L\g<3>", src)

    if n == 0:
        print("  !! فراخوانی awaitBootstrap با عدد ثابت پیدا نشد - دستی باید تغییر کند")
        return False

    if src != original:
        backup(VPN_SERVICE)
        with open(path, "w", encoding="utf-8") as f:
            f.write(src)
        print("  patched: " + VPN_SERVICE + " (" + str(n) + " مورد awaitBootstrap -> 230_000L)")
    return True


def main():
    print("=" * 62)
    print("Tor Bridges Fix  |  root=" + ROOT)
    print("=" * 62)

    print("\n[1/3] TorDaemon.kt")
    backup(TOR_DAEMON)
    write(TOR_DAEMON, TOR_DAEMON_KT)

    print("\n[2/3] tor_bridges.dart")
    backup(BRIDGES_DART)
    write(BRIDGES_DART, BRIDGES_DART_SRC)

    print("\n[3/3] V2rayVpnService.kt (timeout)")
    patch_vpn_service()

    print("\n" + "=" * 62)
    print("تمام شد. مرحله بعد:")
    print("  flutter analyze")
    print("=" * 62)
    return 0


if __name__ == "__main__":
    sys.exit(main())
