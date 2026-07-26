package com.example.v2ray_stk.vpn.core

import android.util.Log
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.PlatformInterface

/**
 * پیاده‌سازی هسته‌ی sing-box روی libbox.
 *
 * نکته: فایل‌دیسکریپتور TUN به‌طور مستقیم به libbox پاس نمی‌شود؛
 * libbox خودش از طریق [PlatformInterface.openTun] آن را درخواست می‌کند.
 * پس fd را فقط نگه می‌داریم و در دسترس سرویس قرار می‌دهیم.
 */
class SingBoxCore(
    private val platformInterface: PlatformInterface,
) : VpnCore {

    override val type: CoreType = CoreType.SING_BOX

    private var boxService: BoxService? = null

    /** آخرین fd ای که سرویس VPN تحویل داده است. */
    @Volatile
    var pendingTunFd: Int = -1
        private set

    override val isRunning: Boolean
        get() = boxService != null

    override fun start(configJson: String, tunFd: Int) {
        if (boxService != null) {
            Log.w(TAG, "core already running, ignoring start()")
            return
        }

        pendingTunFd = tunFd

        try {
            Libbox.checkConfig(configJson)

            val service = Libbox.newService(configJson, platformInterface)
            service.start()
            boxService = service

            Log.i(TAG, "sing-box started (version=${Libbox.version()}, fd=$tunFd)")
        } catch (e: Exception) {
            pendingTunFd = -1
            boxService = null
            throw VpnCoreException("راه‌اندازی هسته‌ی sing-box شکست خورد", e)
        }
    }

    override fun stop() {
        boxService?.let { service ->
            try {
                service.close()
            } catch (e: Exception) {
                Log.e(TAG, "error while closing box service", e)
            }
        }
        boxService = null
        pendingTunFd = -1
        Log.i(TAG, "sing-box stopped")
    }

    /**
     * تست تأخیر. فعلاً پیاده‌سازی واقعی urltest به libbox وصل نشده،
     * پس -1 برمی‌گرداند تا [CoreSelector] این هسته را از رتبه‌بندی خارج کند.
     */
    override fun testLatency(configJson: String): Long {
        return try {
            Libbox.checkConfig(configJson)
            -1L
        } catch (e: Exception) {
            Log.w(TAG, "testLatency: invalid config", e)
            -1L
        }
    }

    fun pause() = boxService?.pause()

    fun wake() = boxService?.wake()

    fun resetNetwork() = boxService?.resetNetwork()

    fun needWIFIState(): Boolean = boxService?.needWIFIState() ?: false

    private companion object {
        const val TAG = "SingBoxCore"
    }
}
