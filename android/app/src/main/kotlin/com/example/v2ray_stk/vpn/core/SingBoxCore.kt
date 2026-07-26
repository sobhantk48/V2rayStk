package com.example.v2ray_stk.vpn.core

import android.util.Log
import libbox.BoxService
import libbox.Libbox
import libbox.PlatformInterface

/**
 * پیاده‌سازی هسته‌ی sing-box بر پایه‌ی libbox.aar
 *
 * این کلاس مستقل از VpnService است و فقط چرخه‌ی حیات BoxService را مدیریت می‌کند.
 * ارتباط با سیستم‌عامل (ساخت TUN و ...) از طریق PlatformInterface تزریق می‌شود
 * که توسط V2rayVpnService پیاده‌سازی شده است.
 */
class SingBoxCore(
    private val platformInterface: PlatformInterface,
) : VpnCore {

    override val type: CoreType = CoreType.SING_BOX

    private var boxService: BoxService? = null

    override fun start(config: String) {
        if (boxService != null) {
            Log.w(TAG, "core already running, ignoring start()")
            return
        }
        // اعتبارسنجی کانفیگ قبل از اجرا؛ اگر خراب باشد Exception پرتاب می‌شود.
        Libbox.checkConfig(config)

        val service = Libbox.newService(config, platformInterface)
        service.start()
        boxService = service
        Log.i(TAG, "sing-box started (version=${Libbox.version()})")
    }

    override fun stop() {
        boxService?.let {
            try {
                it.close()
            } catch (e: Exception) {
                Log.e(TAG, "error while closing box service", e)
            }
        }
        boxService = null
        Log.i(TAG, "sing-box stopped")
    }

    override fun isRunning(): Boolean = boxService != null

    /** برای مدیریت وضعیت شبکه هنگام sleep/wake دستگاه. */
    fun pause() = boxService?.pause()

    fun wake() = boxService?.wake()

    fun resetNetwork() = boxService?.resetNetwork()

    fun needWIFIState(): Boolean = boxService?.needWIFIState() ?: false

    companion object {
        private const val TAG = "SingBoxCore"
    }
}
