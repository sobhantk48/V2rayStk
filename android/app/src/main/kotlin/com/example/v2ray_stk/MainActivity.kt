package com.example.v2ray_stk

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // باید دقیقاً برابر AppConstants.vpnChannelName در سمت دارت باشد
    private val channelName = "com.v2ray.stk/vpn"

    // وضعیت موقت تا زمانی که VpnService واقعی با libbox پیاده‌سازی شود
    private var currentStatus = "disconnected"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(currentStatus)
                "connect" -> {
                    // TODO فاز بعد: startService(VpnService) + libbox
                    currentStatus = "connected"
                    result.success(null)
                }
                "disconnect" -> {
                    // TODO فاز بعد: stopService(VpnService)
                    currentStatus = "disconnected"
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
