package com.v2raystk.app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "v2ray_stk/vpn").setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> if (call.argument<Boolean>("enabled") == true) requestVpn(result) else { stopService(Intent(this, V2rayVpnService::class.java)); result.success(null) }
                "setTor" -> { V2rayVpnService.torEnabled = call.argument<Boolean>("enabled") == true; result.success(null) }
                "stats" -> result.success(V2rayVpnService.stats())
                else -> result.notImplemented()
            }
        }
    }
    private fun requestVpn(result: MethodChannel.Result) { val permission = VpnService.prepare(this); if (permission == null) { startVpn(); result.success(null) } else { pending = result; startActivityForResult(permission, 42) } }
    @Deprecated("Deprecated in Android") override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) { super.onActivityResult(requestCode, resultCode, data); if (requestCode == 42) { if (resultCode == Activity.RESULT_OK) { startVpn(); pending?.success(null) } else pending?.error("VPN_DENIED", "VPN permission denied", null); pending = null } }
    private fun startVpn() { ContextCompat.startForegroundService(this, Intent(this, V2rayVpnService::class.java)) }
}
