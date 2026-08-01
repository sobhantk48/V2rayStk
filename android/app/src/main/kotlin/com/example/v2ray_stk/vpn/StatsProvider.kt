package com.example.v2ray_stk.vpn

import android.net.TrafficStats
import android.os.Handler
import android.os.Looper
import android.os.Process
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * تامین‌کننده آمار اتصال برای MethodChannel:
 *  - سرعت و حجم دانلود/آپلود از TrafficStats روی UID اپ
 *  - پینگ از طریق یک درخواست HTTP سبک (از داخل تونل)
 *  - موقعیت جغرافیایی از GeoIP با کش
 * تمام کارهای شبکه در ترد پس‌زمینه انجام می‌شود و snapshot() هرگز بلاک نمی‌کند.
 */
object StatsProvider {

    private const val LATENCY_URL = "http://cp.cloudflare.com/generate_204"
    private const val GEO_URL =
        "http://ip-api.com/json/?fields=status,country,countryCode,city"

    private const val PING_INTERVAL_MS = 5_000L
    private const val GEO_TTL_MS = 5 * 60 * 1000L
    private const val TIMEOUT_MS = 5_000

    /** پورت‌های محتملِ inbound محلی (mixed/socks) برای عبور درخواست‌ها از هسته */
    private val PROXY_PORTS = intArrayOf(2080, 2081, 1080, 10808, 10809, 7890)

    private val io = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val pingBusy = AtomicBoolean(false)
    private val geoBusy = AtomicBoolean(false)

    @Volatile private var baseRx = -1L
    @Volatile private var baseTx = -1L
    @Volatile private var lastRx = -1L
    @Volatile private var lastTx = -1L
    @Volatile private var lastSampleAt = 0L

    @Volatile private var downloadBps = 0L
    @Volatile private var uploadBps = 0L

    @Volatile private var pingMs = -1
    @Volatile private var pingAt = 0L

    @Volatile private var location: String? = null
    @Volatile private var locationAt = 0L

    @Volatile private var cachedPort = -1

    /** هنگام connect/disconnect صدا زده می‌شود تا شمارنده‌ها صفر شوند. */
    fun reset() {
        baseRx = -1L
        baseTx = -1L
        lastRx = -1L
        lastTx = -1L
        lastSampleAt = 0L
        downloadBps = 0L
        uploadBps = 0L
        pingMs = -1
        pingAt = 0L
        location = null
        locationAt = 0L
        cachedPort = -1
    }

    /** نقشه‌ای که Dart در VpnStats.fromMap انتظار دارد. */
    fun snapshot(): Map<String, Any?> {
        sampleTraffic()
        schedulePingIfStale()
        scheduleGeoIfStale()

        return mapOf(
            "ping" to if (pingMs >= 0) pingMs else null,
            "location" to location,
            "downloadBps" to downloadBps,
            "uploadBps" to uploadBps,
            "totalDownload" to totalDownload(),
            "totalUpload" to totalUpload()
        )
    }

    /** تست پینگ فوری؛ نتیجه روی ترد اصلی برگردانده می‌شود. */
    fun testLatency(callback: (Int?) -> Unit) {
        io.execute {
            val value = measureLatency()
            if (value != null) {
                pingMs = value
                pingAt = System.currentTimeMillis()
            }
            mainHandler.post { callback(value) }
        }
    }

    // ---------------------------------------------------------------- traffic

    private fun sampleTraffic() {
        val rx = readRx()
        val tx = readTx()
        if (rx < 0L || tx < 0L) return

        if (baseRx < 0L) {
            baseRx = rx
            baseTx = tx
        }

        val now = System.currentTimeMillis()
        if (lastRx >= 0L && now > lastSampleAt) {
            val deltaMs = (now - lastSampleAt).coerceAtLeast(1L)
            downloadBps = ((rx - lastRx) * 1000L / deltaMs).coerceAtLeast(0L)
            uploadBps = ((tx - lastTx) * 1000L / deltaMs).coerceAtLeast(0L)
        }

        lastRx = rx
        lastTx = tx
        lastSampleAt = now
    }

    private fun readRx(): Long {
        val uid = TrafficStats.getUidRxBytes(Process.myUid())
        return if (uid > 0L) uid else TrafficStats.getTotalRxBytes()
    }

    private fun readTx(): Long {
        val uid = TrafficStats.getUidTxBytes(Process.myUid())
        return if (uid > 0L) uid else TrafficStats.getTotalTxBytes()
    }

    private fun totalDownload(): Long =
        if (baseRx < 0L || lastRx < 0L) 0L else (lastRx - baseRx).coerceAtLeast(0L)

    private fun totalUpload(): Long =
        if (baseTx < 0L || lastTx < 0L) 0L else (lastTx - baseTx).coerceAtLeast(0L)

    // ------------------------------------------------------------------- ping

    private fun schedulePingIfStale() {
        val now = System.currentTimeMillis()
        if (now - pingAt < PING_INTERVAL_MS) return
        if (!pingBusy.compareAndSet(false, true)) return

        io.execute {
            try {
                val value = measureLatency()
                if (value != null) {
                    pingMs = value
                }
                pingAt = System.currentTimeMillis()
            } finally {
                pingBusy.set(false)
            }
        }
    }

    private fun measureLatency(): Int? {
        val started = System.nanoTime()
        return try {
            val connection = openConnection(LATENCY_URL)
            connection.requestMethod = "GET"
            connection.useCaches = false
            connection.connect()
            connection.responseCode
            connection.disconnect()
            ((System.nanoTime() - started) / 1_000_000L).toInt().coerceAtLeast(1)
        } catch (error: Exception) {
            null
        }
    }

    // --------------------------------------------------------------- location

    private fun scheduleGeoIfStale() {
        val now = System.currentTimeMillis()
        if (location != null && now - locationAt < GEO_TTL_MS) return
        if (!geoBusy.compareAndSet(false, true)) return

        io.execute {
            try {
                val resolved = resolveLocation()
                if (resolved != null) {
                    location = resolved
                    locationAt = System.currentTimeMillis()
                }
            } finally {
                geoBusy.set(false)
            }
        }
    }

    private fun resolveLocation(): String? {
        return try {
            val connection = openConnection(GEO_URL)
            connection.requestMethod = "GET"
            connection.useCaches = false
            val body = connection.inputStream.use { stream ->
                val buffer = ByteArrayOutputStream()
                val chunk = ByteArray(2048)
                while (true) {
                    val read = stream.read(chunk)
                    if (read <= 0) break
                    buffer.write(chunk, 0, read)
                }
                buffer.toString("UTF-8")
            }
            connection.disconnect()

            val json = JSONObject(body)
            if (json.optString("status") != "success") return null

            val country = json.optString("country").trim()
            val code = json.optString("countryCode").trim()
            val city = json.optString("city").trim()

            when {
                country.isEmpty() && code.isEmpty() -> null
                city.isNotEmpty() && country.isNotEmpty() -> "$city, $country"
                country.isNotEmpty() -> country
                else -> code
            }
        } catch (error: Exception) {
            null
        }
    }

    // ---------------------------------------------------------------- helpers

    /** ابتدا تلاش برای عبور از inbound محلی هسته، در غیر این صورت مسیر مستقیم (تونل). */
    private fun openConnection(url: String): HttpURLConnection {
        val proxy = detectProxy()
        val connection = if (proxy == null) {
            URL(url).openConnection()
        } else {
            URL(url).openConnection(proxy)
        } as HttpURLConnection

        connection.connectTimeout = TIMEOUT_MS
        connection.readTimeout = TIMEOUT_MS
        connection.instanceFollowRedirects = false
        connection.setRequestProperty("User-Agent", "V2rayStk/1.0")
        return connection
    }

    private fun detectProxy(): Proxy? {
        val known = cachedPort
        if (known > 0) {
            return Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", known))
        }

        for (port in PROXY_PORTS) {
            if (isPortOpen(port)) {
                cachedPort = port
                return Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", port))
            }
        }
        return null
    }

    private fun isPortOpen(port: Int): Boolean {
        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress("127.0.0.1", port), 300)
                true
            }
        } catch (error: Exception) {
            false
        }
    }
}
