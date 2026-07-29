package com.example.v2ray_stk

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
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
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private val channelName = "com.v2ray.stk/vpn"
    private val eventChannelName = "com.v2ray.stk/vpn_status"
    private val vpnPrepareRequestCode = 0x0f2c

    private var pendingConfig: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
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
                        val host = call.argument<String>("host") ?: "www.gstatic.com"
                        val port = call.argument<Int>("port") ?: 80
                        val timeout = call.argument<Int>("timeout") ?: 5000
                        measureLatencyAsync(host, port, timeout, result)
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

    // ---------------------------------------------------------------- stats

    private fun buildStats(): Map<String, Any> {
        val b = CommandClientBridge
        return mapOf(
            "uplink" to b.uplink,
            "downlink" to b.downlink,
            "uplinkTotal" to b.uplinkTotal,
            "downlinkTotal" to b.downlinkTotal,
            "memory" to b.memory,
            "goroutines" to b.goroutines,
            "connectionsIn" to b.connectionsIn,
            "connectionsOut" to b.connectionsOut,
            "hasData" to b.hasData,
            "status" to VpnState.status
        )
    }

    // -------------------------------------------------------------- latency

    private fun measureLatencyAsync(
        host: String,
        port: Int,
        timeout: Int,
        result: MethodChannel.Result
    ) {
        thread(isDaemon = true) {
            val value = measureLatency(host, port, timeout)
            runOnUiThread { result.success(value) }
        }
    }

    private fun measureLatency(host: String, port: Int, timeout: Int): Int {
        var socket: Socket? = null
        return try {
            val start = System.nanoTime()
            socket = Socket()
            socket.connect(InetSocketAddress(host, port), timeout)
            val elapsed = (System.nanoTime() - start) / 1_000_000L
            elapsed.toInt()
        } catch (e: IOException) {
            -1
        } catch (e: Throwable) {
            -1
        } finally {
            runCatching { socket?.close() }
        }
    }

    // -------------------------------------------------------------- connect

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
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
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
                pendingConfig?.let { startVpnService(it) }
            } else {
                VpnState.update(VpnStatus.DISCONNECTED)
            }
            pendingConfig = null
        }
    }
}
