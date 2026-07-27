package com.example.v2ray_stk.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.Inet6Address
import java.net.NetworkInterface as JavaNetworkInterface
import io.nekohasekai.libbox.NetworkInterface as BoxNetworkInterface

/**
 * PlatformInterface برای libbox.
 *
 * چرا monitor و interfaceGetter باید true باشند:
 * اگر false باشند، هسته sing-box سراغ netlink می‌رود که روی اندروید
 * (SELinux) بلاک است، اینترفیس پیش‌فرض شناسایی نمی‌شود، سوکت خروجی bind
 * نمی‌شود و نتیجه‌اش صفر بایت ترافیک است.
 */
class BoxPlatformInterface(
    context: Context,
    private val tunFdProvider: () -> Int,
    private val protectFd: (Int) -> Boolean,
) : PlatformInterface {

    private companion object {
        const val TAG = "libbox"

        // معادل net.Flags در Go
        const val FLAG_UP = 1
        const val FLAG_BROADCAST = 2
        const val FLAG_LOOPBACK = 4
        const val FLAG_POINT_TO_POINT = 8
        const val FLAG_MULTICAST = 16
    }

    private val connectivity: ConnectivityManager? =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    @Volatile
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // ------------------------------------------------------------------ TUN --

    override fun openTun(options: TunOptions?): Int {
        val fd = tunFdProvider()
        if (fd <= 0) throw IllegalStateException("tun fd is not ready")
        LogStore.append("libbox", "openTun -> fd=$fd")
        return fd
    }

    override fun writeLog(message: String?) {
        val msg = message ?: return
        Log.d(TAG, msg)
        LogStore.append("core", msg)
    }

    // ------------------------------------------------ Default Interface Monitor

    override fun usePlatformDefaultInterfaceMonitor(): Boolean = true

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        if (listener == null) return
        val cm = connectivity
        if (cm == null) {
            LogStore.append("libbox", "ConnectivityManager در دسترس نیست")
            return
        }

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                push(network)
            }

            override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) {
                push(network)
            }

            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities,
            ) {
                push(network)
            }

            override fun onLost(network: Network) {
                runCatching { listener.updateDefaultInterface("", -1) }
                    .onFailure {
                        LogStore.append("libbox", "updateDefaultInterface(lost) خطا: ${it.message}")
                    }
            }

            private fun push(network: Network) {
                val name = runCatching { cm.getLinkProperties(network)?.interfaceName }
                    .getOrNull() ?: return
                val index = interfaceIndexOf(name)
                if (index <= 0) return
                LogStore.append("libbox", "defaultInterface = $name (index=$index)")
                runCatching { listener.updateDefaultInterface(name, index) }
                    .onFailure {
                        LogStore.append("libbox", "updateDefaultInterface خطا: ${it.message}")
                    }
            }
        }

        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        runCatching { cm.registerNetworkCallback(request, callback) }
            .onSuccess {
                networkCallback = callback
                LogStore.append("libbox", "interface monitor شروع شد")
                pushCurrentNetwork(cm, listener)
            }
            .onFailure {
                LogStore.append("libbox", "registerNetworkCallback خطا: ${it.message}")
            }
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        val callback = networkCallback ?: return
        runCatching { connectivity?.unregisterNetworkCallback(callback) }
        networkCallback = null
        LogStore.append("libbox", "interface monitor متوقف شد")
    }

    private fun pushCurrentNetwork(cm: ConnectivityManager, listener: InterfaceUpdateListener) {
        val active = runCatching { cm.activeNetwork }.getOrNull() ?: return
        val name = runCatching { cm.getLinkProperties(active)?.interfaceName }.getOrNull() ?: return
        val index = interfaceIndexOf(name)
        if (index <= 0) return
        LogStore.append("libbox", "defaultInterface(initial) = $name (index=$index)")
        runCatching { listener.updateDefaultInterface(name, index) }
    }

    private fun interfaceIndexOf(name: String): Int =
        runCatching { JavaNetworkInterface.getByName(name)?.index ?: -1 }.getOrDefault(-1)

    // ------------------------------------------------------- Interface Getter --

    override fun usePlatformInterfaceGetter(): Boolean = true

    override fun getInterfaces(): NetworkInterfaceIterator {
        val result = mutableListOf<BoxNetworkInterface>()
        val all = runCatching { JavaNetworkInterface.getNetworkInterfaces() }.getOrNull()

        while (all != null && all.hasMoreElements()) {
            val ni = all.nextElement() ?: continue
            val boxIf = BoxNetworkInterface()
            boxIf.setName(ni.name)
            boxIf.setIndex(ni.index)
            boxIf.setMTU(runCatching { ni.mtu }.getOrDefault(1500))
            boxIf.setFlags(flagsOf(ni))
            boxIf.setAddresses(SimpleStringIterator(addressesOf(ni)))
            result.add(boxIf)
        }

        LogStore.append("libbox", "getInterfaces -> ${result.size} اینترفیس")
        return SimpleInterfaceIterator(result)
    }

    private fun flagsOf(ni: JavaNetworkInterface): Int {
        var flags = 0
        runCatching {
            if (ni.isUp) flags = flags or FLAG_UP
            if (ni.supportsMulticast()) flags = flags or FLAG_MULTICAST
            if (ni.isLoopback) flags = flags or FLAG_LOOPBACK
            if (ni.isPointToPoint) flags = flags or FLAG_POINT_TO_POINT
            if (!ni.isLoopback && !ni.isPointToPoint) flags = flags or FLAG_BROADCAST
        }
        return flags
    }

    private fun addressesOf(ni: JavaNetworkInterface): List<String> {
        val addresses = mutableListOf<String>()
        runCatching {
            for (ia in ni.interfaceAddresses) {
                val addr = ia.address ?: continue
                val host = addr.hostAddress ?: continue
                val clean = if (addr is Inet6Address) host.substringBefore('%') else host
                addresses.add("$clean/${ia.networkPrefixLength}")
            }
        }
        return addresses
    }

    // ---------------------------------------------------- Socket Protection ---

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        if (!protectFd(fd)) {
            LogStore.append("libbox", "protect(fd=$fd) ناموفق")
        }
    }

    // --------------------------------------------------------------- Misc ----

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

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() {}

    override fun sendNotification(notification: Notification?) {}

    // ----------------------------------------------------------- Iterators ---

    private class SimpleInterfaceIterator(
        private val items: List<BoxNetworkInterface>,
    ) : NetworkInterfaceIterator {
        private var index = 0
        override fun hasNext(): Boolean = index < items.size
        override fun next(): BoxNetworkInterface = items[index++]
    }

    private class SimpleStringIterator(
        private val items: List<String>,
    ) : StringIterator {
        private var index = 0
        override fun hasNext(): Boolean = index < items.size
        override fun len(): Int = items.size
        override fun next(): String = items[index++]
    }
}
