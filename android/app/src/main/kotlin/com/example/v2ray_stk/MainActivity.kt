package com.example.v2ray_stk

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.SystemClock
import androidx.annotation.NonNull
import com.example.v2ray_stk.vpn.SingBoxBridge
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
    private val vpnPrepareRequestCode = 0x0f2c

    private var pendingConfig: String? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
    }

    /**
     * آمار تونل. تا وقتی libbox اضافه نشده uploadTotal/downloadTotal صفر است
     * و coreAvailable=false به Flutter می‌گوید مقادیر ترافیک معتبر نیستند.
     */
    private fun buildStats(): Map<String, Any> {
        val t = VpnState.traffic
        return mapOf(
            "status" to VpnState.status,
            "coreAvailable" to SingBoxBridge.isCoreAvailable,
            "uploadTotal" to t.uploadTotal,
            "downloadTotal" to t.downloadTotal,
            "uploadSpeed" to t.uploadSpeed,
            "downloadSpeed" to t.downloadSpeed,
            "connectedSeconds" to VpnState.connectedSeconds()
        )
    }

    /**
     * پینگ واقعی با اندازه‌گیری زمان TCP handshake.
     * روی ترد جداگانه اجرا می‌شود تا UI بلاک نشود؛ خروجی میلی‌ثانیه، و -1 در صورت شکست.
     */
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
                VpnState.update(VpnStatus.DISCONNECTED)
            }
            pendingConfig = null
        }
    }
}
