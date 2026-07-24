package com.example.v2ray_stk.vpn

object VpnStatus {
    const val DISCONNECTED = "disconnected"
    const val CONNECTING = "connecting"
    const val CONNECTED = "connected"
}

/**
 * وضعیت مشترک بین Service و Activity (هم‌پروسه هستند).
 * Activity یک listener ست می‌کند تا تغییرات را به Flutter بفرستد.
 */
object VpnState {
    @Volatile
    var status: String = VpnStatus.DISCONNECTED
        private set

    private var listener: ((String) -> Unit)? = null

    fun setListener(l: ((String) -> Unit)?) {
        listener = l
    }

    fun update(newStatus: String) {
        status = newStatus
        listener?.invoke(newStatus)
    }
}
