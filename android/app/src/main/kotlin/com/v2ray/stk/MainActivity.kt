package com.v2ray.stk

import com.v2ray.stk.bridge.VpnPlatformChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VpnPlatformChannel(this).register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
