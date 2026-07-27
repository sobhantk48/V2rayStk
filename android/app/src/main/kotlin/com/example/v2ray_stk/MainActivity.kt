package com.example.v2ray_stk

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.SystemClock
import androidx.annotation.NonNull
import com.example.v2ray_stk.vpn.CommandClientBridge
import com.example.v2ray_stk.vpn.LogStore
import com.example.v2ray_stk.vpn.SingBoxBridge
import com.example.v2ray_stk.vpn.LogChannel
import com.example.v2ray_stk.vpn.V2rayVpnService
import com.example.v2ray_stk.vpn.VpnState
import com.example.v2ray_stk.vpn.VpnStatus
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.net.InetSocketAddress
import java.net.Socket

class MainActivity : FlutterActivity() {

    private val channelName = "com.v2ray.stk/vpn"
    private val eventChannelName = "com.v2ray.stk/vpn_status"
    private val logChannelName = "com.v2ray.stk/logs"
    private val vpnPrepareRequestCode = 0x0f2c

    private var pendingConfig: String? = null
    private var eventSink: EventChannel.EventSink? = null
    private var logSink: EventChannel.EventSink? = null

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
                    "getLogs" -> result.success(LogStore.snapshot())
                    "clearLogs" -> {
                        LogStore.clear()
                        result.success(null)
                    }
                    "testLatency" -> {
                        val host = call.argument<String>("host") ?: ""
                        val port = call.argument<Int>("port") ?: 443
                        val timeout = call.argument<Int>("timeoutMs") ?: 3000
                        measureLatency(host, port, timeout, result)
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

        // استریم زندهٔ لاگ‌ها به صفحهٔ Log Viewer
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, logChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    logSink = events
                    LogStore.setListener { entry ->
                        runOnUiThread { logSink?.success(entry) }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    LogStore.setListener(null)
                    logSink = null
                }
            })
    }

    /**
     * آمار تونل. اگر CommandClient به هسته وصل شده باشد مقادیر واقعی
     * (uplink/downlink زنده) برمی‌گردد، در غیر این صورت شمارندهٔ محلی.
     */
    private fun buildStats(): Map<String, Any> {
        val t = VpnState.traffic
        val live = CommandClientBridge.hasData
        return mapOf(
            "status" to VpnState.status,
            "coreAvailable" to SingBoxBridge.isCoreAvailable,
            "liveStats" to live,
            "uploadTotal" to if (live) CommandClientBridge.uplinkTotal else t.uploadTotal,
            "downloadTotal" to if (live) CommandClientBridge.downlinkTotal else t.downloadTotal,
            "uploadSpeed" to if (live) CommandClientBridge.uplink else t.uploadSpeed,
            "downloadSpeed" to if (live) CommandClientBridge.downlink else t.downloadSpeed,
            "memory" to CommandClientBridge.memory,
            "goroutines" to CommandClientBridge.goroutines,
            "connectionsIn" to CommandClientBridge.connectionsIn,
            "connectionsOut" to CommandClientBridge.connectionsOut,
            "connectedSeconds" to VpnState.connectedSeconds()
        )
    }

    private fun measureLatency(host: String, port: Int, timeoutMs: Int, result: MethodChannel.Result) {
        if (host.isBlank()) {
            result.success(-1)
            return
        }
        Thread {
            val latency = try {
                val start = SystemClock.elapsedRealtime()
                Socket().use { socket ->
                    socket.connect(InetSocketAddress(host, port), timeoutMs)
                }
                (SystemClock.elapsedRealtime() - start).toInt()
            } catch (e: Exception) {
                -1
            }
            runOnUiThread { result.success(latency) }
        }.start()
    }

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
                LogStore.add("کاربر اجازهٔ VPN را نداد", "warn", "app")
                VpnState.update(VpnStatus.DISCONNECTED)
            }
            pendingConfig = null
        }
    }
}
