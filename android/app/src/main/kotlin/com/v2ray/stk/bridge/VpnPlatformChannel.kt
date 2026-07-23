package com.v2ray.stk.bridge

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import com.v2ray.stk.core.V2rayVpnService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class VpnPlatformChannel(
    private val activity: Activity
) : MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel

    fun register(binaryMessenger: BinaryMessenger) {
        channel = MethodChannel(binaryMessenger, "com.v2ray.stk/vpn")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val prepareIntent = VpnService.prepare(activity)
                if (prepareIntent != null) {
                    activity.startActivityForResult(prepareIntent, VPN_REQUEST_CODE)
                    result.success(null)
                    return
                }

                V2rayVpnService.start(activity)
                result.success(null)
            }

            "disconnect" -> {
                V2rayVpnService.stop(activity)
                result.success(null)
            }

            "getStatus" -> {
                result.success(V2rayVpnService.status)
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        private const val VPN_REQUEST_CODE = 1101
    }
}
