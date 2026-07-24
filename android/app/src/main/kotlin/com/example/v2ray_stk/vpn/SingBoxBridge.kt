package com.example.v2ray_stk.vpn

import android.net.VpnService
import android.util.Log

/**
 * پل ارتباطی با هسته sing-box (libbox).
 * تا وقتی libbox.aar داخل android/app/libs/ قرار نگرفته،
 * isCoreAvailable = false می‌ماند تا tun ساخته نشود و اینترنت بلاک نشود.
 */
object SingBoxBridge {
    private const val TAG = "SingBoxBridge"

    const val isCoreAvailable: Boolean = false

    fun start(vpnService: VpnService, tunFd: Int, config: String) {
        Log.d(TAG, "start() placeholder fd=$tunFd len=${config.length}")
    }

    fun stop() {
        Log.d(TAG, "stop() placeholder")
    }
}
