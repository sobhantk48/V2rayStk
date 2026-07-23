package com.v2ray.stk.core

import android.content.Context
import android.content.Intent
import android.net.VpnService

class V2rayVpnService : VpnService() {

    override fun onCreate() {
        super.onCreate()
        status = STATUS_CONNECTING
    }

    override fun onDestroy() {
        status = STATUS_DISCONNECTED
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        status = STATUS_CONNECTED
        return START_STICKY
    }

    companion object {
        const val STATUS_DISCONNECTED = "disconnected"
        const val STATUS_CONNECTING = "connecting"
        const val STATUS_CONNECTED = "connected"

        @JvmStatic
        var status: String = STATUS_DISCONNECTED

        fun start(context: Context) {
            val intent = Intent(context, V2rayVpnService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, V2rayVpnService::class.java)
            context.stopService(intent)
            status = STATUS_DISCONNECTED
        }
    }
}
