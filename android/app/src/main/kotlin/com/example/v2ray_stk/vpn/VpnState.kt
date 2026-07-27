package com.example.v2ray_stk.vpn

object VpnStatus {
    const val DISCONNECTED = "disconnected"
    const val CONNECTING = "connecting"
    const val CONNECTED = "connected"
}

/**
 * آمار لحظه‌ای تونل.
 * منبع واقعی این مقادیر libbox است؛ تا وقتی هسته اضافه نشده،
 * uploadTotal/downloadTotal صفر می‌مانند (صفر واقعی، نه مقدار ساختگی).
 */
data class VpnTraffic(
    val uploadTotal: Long = 0L,
    val downloadTotal: Long = 0L,
    val uploadSpeed: Long = 0L,
    val downloadSpeed: Long = 0L,
)

/**
 * وضعیت مشترک بین Service و Activity (هم‌پروسه هستند).
 * Activity یک listener ست می‌کند تا تغییرات را به Flutter بفرستد.
 */
object VpnState {
    @Volatile
    var status: String = VpnStatus.DISCONNECTED
        private set

    @Volatile
    var traffic: VpnTraffic = VpnTraffic()
        private set

    /** زمان برقراری اتصال بر مبنای elapsedRealtime؛ 0 یعنی متصل نیست. */
    @Volatile
    var connectedAt: Long = 0L
        private set

    private var listener: ((String) -> Unit)? = null

    fun setListener(l: ((String) -> Unit)?) {
        listener = l
    }

    fun update(newStatus: String) {
        status = newStatus
        when (newStatus) {
            VpnStatus.CONNECTED -> {
                if (connectedAt == 0L) connectedAt = android.os.SystemClock.elapsedRealtime()
            }
            VpnStatus.DISCONNECTED -> {
                connectedAt = 0L
                traffic = VpnTraffic()
            }
        }
        listener?.invoke(newStatus)
    }

    /** قلاب مخصوص SingBoxBridge؛ وقتی libbox اضافه شد از حلقه‌ی آماری هسته صدا زده می‌شود. */
    fun updateTraffic(t: VpnTraffic) {
        traffic = t
    }

    /** مدت اتصال به ثانیه؛ اگر قطع باشد 0. */
    fun connectedSeconds(): Long {
        val start = connectedAt
        if (start == 0L) return 0L
        return (android.os.SystemClock.elapsedRealtime() - start) / 1000L
    }
}
