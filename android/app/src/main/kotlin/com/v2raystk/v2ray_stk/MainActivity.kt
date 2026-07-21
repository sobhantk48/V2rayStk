package com.v2raystk.v2ray_stk

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.v2raystk.v2ray_stk.vpn.V2rayVpnService

class MainActivity : FlutterActivity() {

    companion object {
        private const val METHOD_CHANNEL = "com.v2raystk.v2ray_stk/vpn"
        private const val EVENT_CHANNEL = "com.v2raystk.v2ray_stk/vpn_events"
        private const val VPN_REQUEST_CODE = 1001
    }

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPrepareResult: MethodChannel.Result? = null

    private val statusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != V2rayVpnService.ACTION_STATUS) return
            val status = intent.getStringExtra(V2rayVpnService.EXTRA_STATUS) ?: "disconnected"
            val upload = intent.getLongExtra(V2rayVpnService.EXTRA_UPLOAD, 0L)
            val download = intent.getLongExtra(V2rayVpnService.EXTRA_DOWNLOAD, 0L)
            sendEvent(status, upload, download)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "prepare" -> prepareVpn(result)
                    "startVpn" -> {
                        val config = call.argument<String>("config") ?: ""
                        startVpnService(config, result)
                    }
                    "stopVpn" -> {
                        stopVpnService()
                        result.success(true)
                    }
                    "getStatus" -> {
                        val status = if (V2rayVpnService.isRunning) "connected" else "disconnected"
                        result.success(status)
                    }
                    "getStats" -> {
                        result.success(
                            mapOf(
                                "upload" to V2rayVpnService.uploadBytes,
                                "download" to V2rayVpnService.downloadBytes,
                                "status" to if (V2rayVpnService.isRunning) "connected" else "disconnected"
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    val status = if (V2rayVpnService.isRunning) "connected" else "disconnected"
                    sendEvent(status, V2rayVpnService.uploadBytes, V2rayVpnService.downloadBytes)
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(V2rayVpnService.ACTION_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(statusReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(statusReceiver, filter)
        }
    }

    override fun onStop() {
        try {
            unregisterReceiver(statusReceiver)
        } catch (_: Exception) {
        }
        super.onStop()
    }

    private fun prepareVpn(result: MethodChannel.Result) {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            pendingPrepareResult = result
            startActivityForResult(intent, VPN_REQUEST_CODE)
        } else {
            result.success(true)
        }
    }

    private fun startVpnService(config: String, result: MethodChannel.Result) {
        val prepareIntent = VpnService.prepare(this)
        if (prepareIntent != null) {
            result.error("VPN_PERMISSION", "VPN permission not granted. Call prepare() first.", null)
            return
        }

        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_CONNECT
            putExtra("config", config)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        result.success(true)
    }

    private fun stopVpnService() {
        val intent = Intent(this, V2rayVpnService::class.java).apply {
            action = V2rayVpnService.ACTION_DISCONNECT
        }
        startService(intent)
    }

    private fun sendEvent(status: String, upload: Long, download: Long) {
        eventSink?.success(
            mapOf(
                "status" to status,
                "upload" to upload,
                "download" to download
            )
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == VPN_REQUEST_CODE) {
            pendingPrepareResult?.success(resultCode == Activity.RESULT_OK)
            pendingPrepareResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
