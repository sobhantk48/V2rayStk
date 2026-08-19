package com.example.v2ray_stk.vpn

import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL

/**
 * تولیدکننده‌ی ping و location. مقادیر را در VpnStatsStore می‌نویسد
 * تا snapshot() آن‌ها را به Flutter بدهد.
 *
 * وابستگی جدیدی اضافه نمی‌کند: فقط Thread و java.net.
 */
object StatsProvider {

    private const val PING_URL = "http://cp.cloudflare.com/generate_204"
    private const val GEO_URL =
        "http://ip-api.com/json/?fields=status,country,countryCode,city"

    /** پورت‌های رایج inbound محلی sing-box. اولی که جواب بدهد استفاده می‌شود. */
    private val candidatePorts = intArrayOf(2080, 2081, 1080, 10809, 7890)

    private const val PING_INTERVAL_MS = 5_000L
    private const val GEO_INTERVAL_MS = 120_000L

    @Volatile private var worker: Thread? = null
    @Volatile private var running = false
    @Volatile private var cachedProxy: Proxy? = null
    @Volatile private var lastPing = -1L
    @Volatile private var lastLoc: String? = null

    /** آخرین پینگ اندازه‌گیری‌شده بر حسب میلی‌ثانیه؛ -1 یعنی نامعتبر. */
    fun lastPingMs(): Long = lastPing

    /** آخرین موقعیت جغرافیایی سرور؛ null یعنی نامشخص. */
    fun lastLocation(): String? = lastLoc

    /** پاک‌سازی مقادیر هنگام اتصال/قطع تا مقدار قدیمی نمایش داده نشود. */
    fun reset() {
        lastPing = -1L
        lastLoc = null
        cachedProxy = null
        VpnStatsStore.updatePing(-1L)
        VpnStatsStore.updateLocation(null)
    }

    fun start() {
        if (running) return
        running = true
        cachedProxy = null
        worker = Thread {
            var lastGeo = 0L
            while (running) {
                val ping = measurePing()
                lastPing = ping
                VpnStatsStore.updatePing(ping)

                val now = System.currentTimeMillis()
                if (ping >= 0L && now - lastGeo >= GEO_INTERVAL_MS) {
                    lastGeo = now
                    fetchLocation()?.let {
                        lastLoc = it
                        VpnStatsStore.updateLocation(it)
                    }
                }

                try {
                    Thread.sleep(PING_INTERVAL_MS)
                } catch (_: InterruptedException) {
                    return@Thread
                }
            }
        }.apply {
            isDaemon = true
            name = "stk-stats"
            start()
        }
    }

    fun stop() {
        running = false
        worker?.interrupt()
        worker = null
        cachedProxy = null
    }

    /** میلی‌ثانیه، یا -1 در صورت شکست. */
    private fun measurePing(): Long {
        val proxy = resolveProxy()
        val started = System.currentTimeMillis()
        return try {
            val conn = openConnection(PING_URL, proxy).apply {
                requestMethod = "HEAD"
                connectTimeout = 5_000
                readTimeout = 5_000
                useCaches = false
                setRequestProperty("Connection", "close")
            }
            val code = conn.responseCode
            conn.disconnect()
            if (code in 200..399) System.currentTimeMillis() - started else -1L
        } catch (_: Exception) {
            cachedProxy = null  // دفعه‌ی بعد پورت‌ها را دوباره کشف کن
            -1L
        }
    }

    /** مثل: Germany, Frankfurt */
    private fun fetchLocation(): String? {
        val proxy = resolveProxy()
        return try {
            val conn = openConnection(GEO_URL, proxy).apply {
                requestMethod = "GET"
                connectTimeout = 6_000
                readTimeout = 6_000
                useCaches = false
            }
            if (conn.responseCode != 200) {
                conn.disconnect()
                return null
            }
            val body = InputStreamReader(conn.inputStream).use { it.readText() }
            conn.disconnect()
            if (!body.contains("\"status\":\"success\"")) return null

            val country = extract(body, "country")
            val city = extract(body, "city")
            val code = extract(body, "countryCode")
            when {
                !country.isNullOrBlank() && !city.isNullOrBlank() -> "$country, $city"
                !country.isNullOrBlank() -> country
                !code.isNullOrBlank() -> code
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    /** پارس ساده بدون وابستگی به کتابخانه‌ی JSON. */
    private fun extract(json: String, key: String): String? {
        val marker = "\"$key\":\""
        val start = json.indexOf(marker)
        if (start < 0) return null
        val from = start + marker.length
        val end = json.indexOf('"', from)
        if (end <= from) return null
        return json.substring(from, end)
    }

    private fun openConnection(url: String, proxy: Proxy?): HttpURLConnection {
        val target = URL(url)
        val conn = if (proxy == null) {
            target.openConnection()
        } else {
            target.openConnection(proxy)
        }
        return conn as HttpURLConnection
    }

    /**
     * تلاش برای یافتن inbound محلی هسته. اگر پیدا نشد null برمی‌گرداند
     * و ترافیک از مسیر پیش‌فرض (خود TUN) می‌رود.
     */
    private fun resolveProxy(): Proxy? {
        cachedProxy?.let { return it }
        for (port in candidatePorts) {
            try {
                java.net.Socket().use { socket ->
                    socket.connect(InetSocketAddress("127.0.0.1", port), 300)
                }
                val proxy = Proxy(Proxy.Type.SOCKS, InetSocketAddress("127.0.0.1", port))
                cachedProxy = proxy
                return proxy
            } catch (_: Exception) {
                // پورت بعدی
            }
        }
        return null
    }
}
