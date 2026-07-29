package com.example.v2ray_stk

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.example.v2ray_stk.log.LogChannel
import com.example.v2ray_stk.vpn.CommandClientBridge
import com.example.v2ray_stk.vpn.V2rayVpnService
import com.example.v2ray_stk.vpn.VpnState
import com.example.v2ray_stk.vpn.VpnStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Socket
import java.net.URL
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val channelName = "com.v2ray.stk/vpn"
    private val eventChannelName = "com.v2ray.stk/vpn_status"
    private val vpnPrepareRequestCode = 0x0f2c

    private var pendingConfig: String? = null
    private var eventSink: EventChannel.EventSink? = null

    private val io = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())

    /** آخرین پینگ موفق؛ -1 یعنی نامعتبر / تایم‌اوت */
    @Volatile private var lastPing: Long = -1L

    /** تلاش‌های اتصال Bridge به هسته */
    private var bridgeRetry = 0
    private val bridgeTicker = object : Runnable {
        override fun run() {
            if (!isConnected()) { bridgeRetry = 0; return }
            if (CommandClientBridge.hasData) return
            if (bridgeRetry >= 20) return
            bridgeRetry++
            runCatching { CommandClientBridge.stop() }
            runCatching { CommandClientBridge.start() }
            main.postDelayed(this, 1500L)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        LogChannel.register(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(VpnState.status)

                    "connect" -> {
                        prepareAndConnect(call.argument<String>("config") ?: "")
                        result.success(null)
                    }

                    "disconnect" -> {
                        disconnect()
                        result.success(null)
                    }

                    "getStats" -> result.success(buildStats())

                    "testLatency" -> {
                        val host = call.argument<String>("host")
                        val port = call.argument<Int>("port") ?: 443
                        val url = call.argument<String>("url")
                            ?: "https://www.gstatic.com/generate_204"
                        val timeout = call.argument<Int>("timeout") ?: 5000
                        io.execute {
                            val ms = if (host.isNullOrBlank()) measureHttp(url, timeout)
                            else measureTcp(host, port, timeout)
                            lastPing = ms
                            main.post { result.success(ms) }
                        }
                    }

                    "resetStats" -> {
                        lastPing = -1L
                        runCatching { CommandClientBridge.stop() }
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    VpnState.setListener { status ->
                        runOnUiThread { eventSink?.success(status) }
                    }
                    events?.success(VpnState.status)
                }

                override fun onCancel(arguments: Any?) {
                    VpnState.setListener(null)
                    eventSink = null
                }
            })

        // اگر اکتیویتی بعد از برقراری تونل باز شد، Bridge را دوباره بچسبان
        if (isConnected()) startBridgeWatch()
    }

    // ---------- Stats ----------

    private fun buildStats(): Map<String, Any> {
        val connected = isConnected()
        val has = connected && CommandClientBridge.hasData
        return mapOf(
            "connected" to connected,
            "hasData" to has,
            "ping" to if (connected) lastPing else -1L,
            "downloadBps" to if (has) CommandClientBridge.downlink else 0L,
            "uploadBps" to if (has) CommandClientBridge.uplink else 0L,
            "totalDownload" to if (has) CommandClientBridge.downlinkTotal else 0L,
            "totalUpload" to if (has) CommandClientBridge.uplinkTotal else 0L,
            "memory" to if (has) CommandClientBridge.memory else 0L,
            "goroutines" to if (has) CommandClientBridge.goroutines else 0L,
            "connectionsIn" to if (has) CommandClientBridge.connectionsIn else 0L,
            "connectionsOut" to if (has) CommandClientBridge.connectionsOut else 0L
        )
    }

    private fun measureTcp(host: String, port: Int, timeout: Int): Long {
        return try {
            val started = System.nanoTime()
            Socket().use { s ->
                s.connect(InetSocketAddress(host, port), timeout)
            }
            (System.nanoTime() - started) / 1_000_000L
        } catch (_: Throwable) {
            -1L
        }
    }

    private fun measureHttp(url: String, timeout: Int): Long {
        var conn: HttpURLConnection? = null
        return try {
            val started = System.nanoTime()
            conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = timeout
                readTimeout = timeout
                requestMethod = "GET"
                instanceFollowRedirects = false
                useCaches = false
                setRequestProperty("Connection", "close")
            }
            val code = conn.responseCode
            conn.inputStream?.close()
            if (code in 200..399) (System.nanoTime() - started) / 1_000_000L else -1L
        } catch (_: Throwable) {
            -1L
        } finally {
            runCatching { conn?.disconnect() }
        }
    }

    private fun isConnected(): Boolean =
        VpnState.status.toString().lowercase().let { it == "connected" || it == "vpnstatus.connected" }

    private fun startBridgeWatch() {
        bridgeRetry = 0
        main.removeCallbacks(bridgeTicker)
        main.post(bridgeTicker)
    }

    private fun stopBridge() {
        main.removeCallbacks(bridgeTicker)
        lastPing = -1L
        runCatching { CommandClientBridge.stop() }
    }

    // ---------- VPN ----------

    private fun prepareAndConnect(config: String) {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            pendingConfig = config
            startActivityForResult(prepareIntent, vpnPrepareRequestCode)
        } else {
            startVpnService(config)
        }
    }

    private fun startVpnService(config: String) {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra(V2rayVpnService.EXTRA_CONFIG, config)
        }
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent) else startService(intent)
        // Bridge را با تاخیر وصل کن؛ هسته چند صد میلی‌ثانیه بعد آماده می‌شود
        main.postDelayed({ startBridgeWatch() }, 1200L)
    }

    private fun disconnect() {
        stopBridge()
        startService(Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_DISCONNECT
        })
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == vpnPrepareRequestCode) {
            if (resultCode == Activity.RESULT_OK) {
                startVpnService(pendingConfig ?: "")
            } else {
                VpnState.update(VpnStatus.DISCONNECTED)
            }
            pendingConfig = null
        }
    }

    override fun onDestroy() {
        main.removeCallbacks(bridgeTicker)
        super.onDestroy()
    }
}
