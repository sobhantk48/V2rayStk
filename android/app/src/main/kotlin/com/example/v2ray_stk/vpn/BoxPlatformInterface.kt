package com.example.v2ray_stk.vpn

import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState

/**
 * پیاده‌سازی حداقلی PlatformInterface برای libbox.
 * TUN را خودمان با VpnService.Builder می‌سازیم و fd را به هسته می‌دهیم،
 * پس نیازی به مدیریت مسیر/آدرس از سمت libbox نیست.
 */
class BoxPlatformInterface(
    private val tunFdProvider: () -> Int,
    private val protectFd: (Int) -> Boolean,
) : PlatformInterface {

    companion object {
        private const val TAG = "libbox"
    }

    override fun openTun(options: TunOptions?): Int {
        val fd = tunFdProvider()
        if (fd <= 0) throw IllegalStateException("tun fd is not ready")
        Log.d(TAG, "openTun -> fd=$fd")
        return fd
    }

    override fun writeLog(message: String?) {
        Log.d(TAG, message ?: "")
    }

    override fun useProcFS(): Boolean = false

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int,
    ): Int = throw UnsupportedOperationException("findConnectionOwner")

    override fun packageNameByUid(uid: Int): String =
        throw UnsupportedOperationException("packageNameByUid")

    override fun uidByPackageName(packageName: String?): Int =
        throw UnsupportedOperationException("uidByPackageName")

    override fun usePlatformDefaultInterfaceMonitor(): Boolean = false

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {}

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {}

    override fun usePlatformInterfaceGetter(): Boolean = false

    override fun getInterfaces(): NetworkInterfaceIterator =
        throw UnsupportedOperationException("getInterfaces")

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() {}

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        protectFd(fd)
    }

    override fun sendNotification(notification: Notification?) {}
}
