package com.example.v2ray_stk


import com.example.v2ray_stk.vpn.StatsProvider
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
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity : FlutterActivity() {

    private val channelName = "com.v2ray.stk/vpn"
    private val eventChannelName = "com.v2ray.stk/vpn_status"
    private val vpnPrepareRequestCode = 0x0f2c

    // هدف پینگ: هندشیک TCP روی پورت 80 که از داخل تانل عبور می‌کند
    private val latencyHost = "www.gstatic.com"
    private val latencyPort = 80
    private val latencyTimeoutMs = 4000

    private var pendingConfig: String? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ثبت کانال لاگ
        LogChannel.register(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStatus" -> result.success(VpnState.status)

                    "connect" -> {
                    StatsProvider.reset()
                        prepareAndConnect(call.argument<String>("config") ?: "")
                        result.success(null)
                    }

                    "disconnect" -> {
                    StatsProvider.reset()
                        disconnect()
                        result.success(null)
                    }

                    "getStats" -> result.success(buildStatsMap())

                    "testLatency" -> measureLatency(result)

                    "getStats" -> result.success(StatsProvider.snapshot())
                    "testLatency" -> StatsProvider.testLatency { value ->
                        result.success(value)
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
    }

    // ------------------------------------------------------------------ stats

    /**
     * کلیدها عیناً همان چیزی هستند که VpnStats.fromMap در فلاتر انتظار دارد.
     * تا وقتی هسته اولین StatusMessage را نداده باشد (hasData == false)
     * مقادیر صفر برمی‌گردند و UI صفر نشان می‌دهد، نه مقدار قدیمی.
     */
    private fun buildStatsMap(): Map<String, Any?> {
        val live = CommandClientBridge.hasData
        return mapOf(
            "downloadBps" to if (live) CommandClientBridge.downlink else 0L,
            "uploadBps" to if (live) CommandClientBridge.uplink else 0L,
            "totalDownload" to CommandClientBridge.downlinkTotal,
            "totalUpload" to CommandClientBridge.uplinkTotal,
            "memory" to CommandClientBridge.memory,
            "goroutines" to CommandClientBridge.goroutines,
            "connectionsIn" to CommandClientBridge.connectionsIn,
            "connectionsOut" to CommandClientBridge.connectionsOut,
            "location" to null,
            "ping" to null
        )
    }

    // ---------------------------------------------------------------- latency

    private fun measureLatency(result: MethodChannel.Result) {
        Thread {
            val value = tcpHandshakeMillis()
            mainHandler.post { result.success(value) }
        }.apply { isDaemon = true }.start()
    }

    /** زمان هندشیک TCP بر حسب میلی‌ثانیه؛ در صورت خطا -1 */
    private fun tcpHandshakeMillis(): Int {
        var socket: Socket? = null
        return try {
            val started = System.nanoTime()
            socket = Socket()
            socket.connect(InetSocketAddress(latencyHost, latencyPort), latencyTimeoutMs)
            ((System.nanoTime() - started) / 1_000_000L).toInt()
        } catch (t: Throwable) {
            -1
        } finally {
            try {
                socket?.close()
            } catch (_: IOException) {
            }
        }
    }

    // ------------------------------------------------------------------- vpn

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
    }

    private fun disconnect() {
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

    private fun statsSnapshot(): Map<String, Any> {
        return runCatching {
            mapOf(
            "uplink" to CommandClientBridge.uplink,
            "downlink" to CommandClientBridge.downlink,
            "uplinkTotal" to CommandClientBridge.uplinkTotal,
            "downlinkTotal" to CommandClientBridge.downlinkTotal,
            "connectionsIn" to CommandClientBridge.connectionsIn,
            "connectionsOut" to CommandClientBridge.connectionsOut,
            "memory" to CommandClientBridge.memory,
            "goroutines" to CommandClientBridge.goroutines
        )
        }.getOrElse { emptyMap() }
    }

    private fun measureLatency(host: String, port: Int, timeoutMs: Int): Int {
        if (host.isBlank()) return -1
        return try {
            val socket = Socket()
            val t0 = System.nanoTime()
            socket.connect(InetSocketAddress(host, port), timeoutMs)
            val elapsed = ((System.nanoTime() - t0) / 1000000L).toInt()
            runCatching { socket.close() }
            elapsed
        } catch (e: Throwable) {
            -1
        }
    }
}
