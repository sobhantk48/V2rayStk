package com.example.v2ray_stk.vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.os.Build
import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.InetSocketAddress
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface
import java.net.NetworkInterface as JavaNetworkInterface

/**
 * پیاده‌سازی PlatformInterface برای libbox.
 *
 * نکته حیاتی: روی اندروید ۱۱+ گوگل استفاده از netlink socket را بسته است.
 * پس sing-box نباید خودش اینترفیس پیش‌فرض را پیدا کند؛ ما با
 * ConnectivityManager این کار را انجام می‌دهیم و به هسته اطلاع می‌دهیم.
 * در غیر این صورت newService با خطای
 * "netlink socket in Android is banned by Google" شکست می‌خورد.
 */
class BoxPlatformInterface(
    private val context: Context,
    private val tunFdProvider: () -> Int,
    private val protectFd: (Int) -> Boolean,
) : PlatformInterface {

    companion object {
        private const val TAG = "libbox"

        // معادل مقادیر net.Flags در Go
        private const val FLAG_UP = 1 shl 0
        private const val FLAG_BROADCAST = 1 shl 1
        private const val FLAG_LOOPBACK = 1 shl 2
        private const val FLAG_POINT_TO_POINT = 1 shl 3
        private const val FLAG_MULTICAST = 1 shl 4
        private const val FLAG_RUNNING = 1 shl 5
    }

    private val connectivity: ConnectivityManager by lazy {
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }

    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    // ---------------------------------------------------------------- TUN

    override fun openTun(options: TunOptions?): Int {
        val fd = tunFdProvider()
        if (fd <= 0) throw IllegalStateException("tun fd is not ready")
        Log.d(TAG, "openTun -> fd=$fd (mtu=${options?.mtu ?: -1})")
        return fd
    }

    // ---------------------------------------------------------------- Log

    override fun writeLog(message: String?) {
        Log.d(TAG, message ?: "")
    }

    // ------------------------------------------------ Default interface

    /** true = خودمان مانیتور می‌کنیم، هسته سراغ netlink نرود. */
    override fun usePlatformDefaultInterfaceMonitor(): Boolean = true

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        if (listener == null) return
        closeDefaultInterfaceMonitor(null)

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                pushDefaultInterface(listener, network)
            }

            override fun onLinkPropertiesChanged(
                network: Network,
                linkProperties: LinkProperties,
            ) {
                pushInterfaceName(listener, linkProperties.interfaceName)
            }

            override fun onLost(network: Network) {
                runCatching { listener.updateDefaultInterface("", -1) }
            }
        }

        runCatching {
            connectivity.registerDefaultNetworkCallback(callback)
            networkCallback = callback
        }.onFailure { Log.w(TAG, "registerDefaultNetworkCallback failed", it) }

        // وضعیت فعلی را فوراً بفرست تا هسته منتظر نماند
        runCatching {
            val active = connectivity.activeNetwork
            if (active != null) {
                pushDefaultInterface(listener, active)
            } else {
                listener.updateDefaultInterface("", -1)
            }
        }
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        networkCallback?.let { cb ->
            runCatching { connectivity.unregisterNetworkCallback(cb) }
        }
        networkCallback = null
    }

    private fun pushDefaultInterface(listener: InterfaceUpdateListener, network: Network) {
        val name = runCatching {
            connectivity.getLinkProperties(network)?.interfaceName
        }.getOrNull()
        pushInterfaceName(listener, name)
    }

    private fun pushInterfaceName(listener: InterfaceUpdateListener, name: String?) {
        if (name.isNullOrBlank()) return
        val index = runCatching {
            JavaNetworkInterface.getByName(name)?.index ?: -1
        }.getOrDefault(-1)
        Log.d(TAG, "defaultInterface -> $name (index=$index)")
        runCatching { listener.updateDefaultInterface(name, index) }
            .onFailure { Log.w(TAG, "updateDefaultInterface failed", it) }
    }

    // ------------------------------------------------ Interface getter

    /** true = لیست اینترفیس‌ها را ما می‌دهیم، نه netlink. */
    override fun usePlatformInterfaceGetter(): Boolean = true

    override fun getInterfaces(): NetworkInterfaceIterator {
        val result = mutableListOf<LibboxNetworkInterface>()
        runCatching {
            val ifaces = JavaNetworkInterface.getNetworkInterfaces() ?: return@runCatching
            for (iface in ifaces) {
                val item = LibboxNetworkInterface()
                item.name = iface.name
                item.index = runCatching { iface.index }.getOrDefault(-1)
                item.mtu = runCatching { iface.mtu }.getOrDefault(1500)
                item.flags = buildFlags(iface)

                val addresses = mutableListOf<String>()
                runCatching {
                    for (addr in iface.interfaceAddresses) {
                        val host = addr.address?.hostAddress ?: continue
                        val clean = host.substringBefore('%')
                        addresses.add("$clean/${addr.networkPrefixLength}")
                    }
                }
                item.addresses = StringArrayIterator(addresses)

                result.add(item)
            }
        }.onFailure { Log.w(TAG, "getInterfaces failed", it) }

        return InterfaceArrayIterator(result)
    }

    private fun buildFlags(iface: JavaNetworkInterface): Int {
        var flags = 0
        runCatching {
            if (iface.isUp) flags = flags or FLAG_UP or FLAG_RUNNING
            if (iface.isLoopback) flags = flags or FLAG_LOOPBACK
            if (iface.isPointToPoint) flags = flags or FLAG_POINT_TO_POINT
            if (iface.supportsMulticast()) flags = flags or FLAG_MULTICAST
            if (!iface.isLoopback && !iface.isPointToPoint) flags = flags or FLAG_BROADCAST
        }
        return flags
    }

    // ------------------------------------------------ Socket protection

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        protectFd(fd)
    }

    // ------------------------------------------------ Process matching

    override fun useProcFS(): Boolean = false

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int,
    ): Int {
        if (Build.VERSION.SDK_INT < 29) {
            throw UnsupportedOperationException("findConnectionOwner requires API 29+")
        }
        val uid = connectivity.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort),
        )
        if (uid == -1) throw IllegalStateException("connection owner not found")
        return uid
    }

    override fun packageNameByUid(uid: Int): String {
        val packages = context.packageManager.getPackagesForUid(uid)
        if (packages.isNullOrEmpty()) throw IllegalStateException("package not found for uid $uid")
        return packages[0]
    }

    override fun uidByPackageName(packageName: String?): Int {
        if (packageName.isNullOrBlank()) throw IllegalStateException("empty package name")
        return if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageUid(
                packageName,
                android.content.pm.PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageUid(packageName, 0)
        }
    }

    // ------------------------------------------------ Misc

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() {}

    override fun sendNotification(notification: Notification?) {}

    // ------------------------------------------------ Iterators

    private class StringArrayIterator(
        private val values: List<String>,
    ) : StringIterator {
        private var cursor = 0
        override fun hasNext(): Boolean = cursor < values.size
        override fun len(): Int = values.size
        override fun next(): String = values[cursor++]
    }

    private class InterfaceArrayIterator(
        private val values: List<LibboxNetworkInterface>,
    ) : NetworkInterfaceIterator {
        private var cursor = 0
        override fun hasNext(): Boolean = cursor < values.size
        override fun next(): LibboxNetworkInterface = values[cursor++]
    }
}
