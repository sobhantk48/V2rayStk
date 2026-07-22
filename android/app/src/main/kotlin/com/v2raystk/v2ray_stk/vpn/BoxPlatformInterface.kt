package com.v2raystk.v2ray_stk.vpn

import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import libbox.InterfaceUpdateListener
import libbox.NetworkInterfaceIterator
import libbox.PlatformInterface
import libbox.StringIterator
import libbox.TunOptions
import libbox.WIFIState
import java.net.InetSocketAddress

/**
 * Bridge between Android VpnService and sing-box libbox PlatformInterface.
 * Signatures must match libbox.aar exactly (package: libbox).
 */
class BoxPlatformInterface(
    private val service: V2rayVpnService,
) : PlatformInterface {

    companion object {
        private const val TAG = "BoxPlatformInterface"
    }

    private var tunFd: ParcelFileDescriptor? = null

    override fun openTun(options: TunOptions): Int {
        // Close previous tun if any
        try {
            tunFd?.close()
        } catch (_: Exception) {
        }
        tunFd = null

        val builder = service.Builder()
        builder.setSession("V2ray Stk")
        builder.setMtu(options.mtu.coerceAtLeast(1280))

        // IPv4 addresses
        addAddresses(builder, options.inet4Address)
        // IPv6 addresses
        addAddresses(builder, options.inet6Address)

        // Routes
        if (options.autoRoute) {
            addRoutes(builder, options.inet4RouteAddress, ipv6 = false, fallbackDefault = true)
            addRoutes(builder, options.inet6RouteAddress, ipv6 = true, fallbackDefault = false)

            // Exclude routes if available
            // (some configs only use include ranges)
            try {
                addRoutes(builder, options.inet4RouteRange, ipv6 = false, fallbackDefault = false)
            } catch (_: Exception) {
            }
            try {
                addRoutes(builder, options.inet6RouteRange, ipv6 = true, fallbackDefault = false)
            } catch (_: Exception) {
            }
        }

        // DNS
        try {
            val dns = options.dnsServerAddress
            if (!dns.isNullOrBlank()) {
                builder.addDnsServer(dns)
            }
        } catch (e: Exception) {
            Log.w(TAG, "dnsServerAddress: ${e.message}")
            builder.addDnsServer("1.1.1.1")
        }

        // Per-app proxy include/exclude
        try {
            applyPackages(builder, options.includePackage, include = true)
            applyPackages(builder, options.excludePackage, include = false)
        } catch (e: Exception) {
            Log.w(TAG, "package filter: ${e.message}")
        }

        // Always allow our own package
        try {
            builder.addDisallowedApplication(service.packageName)
        } catch (_: Exception) {
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val pfd = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null")

        tunFd = pfd
        val fd = pfd.fd
        Log.i(TAG, "openTun ok, fd=$fd mtu=${options.mtu}")
        return fd
    }

    private fun addAddresses(builder: VpnService.Builder, iterator: libbox.RoutePrefixIterator?) {
        if (iterator == null) return
        while (iterator.hasNext()) {
            val prefix = iterator.next()
            val addr = prefix.address()
            val prefixLen = prefix.prefix()
            try {
                builder.addAddress(addr, prefixLen)
            } catch (e: Exception) {
                Log.w(TAG, "addAddress $addr/$prefixLen: ${e.message}")
            }
        }
    }

    private fun addRoutes(
        builder: VpnService.Builder,
        iterator: libbox.RoutePrefixIterator?,
        ipv6: Boolean,
        fallbackDefault: Boolean,
    ) {
        var count = 0
        if (iterator != null) {
            while (iterator.hasNext()) {
                val prefix = iterator.next()
                val addr = prefix.address()
                val prefixLen = prefix.prefix()
                try {
                    builder.addRoute(addr, prefixLen)
                    count++
                } catch (e: Exception) {
                    Log.w(TAG, "addRoute $addr/$prefixLen: ${e.message}")
                }
            }
        }
        if (count == 0 && fallbackDefault) {
            try {
                if (!ipv6) {
                    builder.addRoute("0.0.0.0", 0)
                }
            } catch (e: Exception) {
                Log.w(TAG, "default route: ${e.message}")
            }
        }
    }

    private fun applyPackages(
        builder: VpnService.Builder,
        iterator: StringIterator?,
        include: Boolean,
    ) {
        if (iterator == null) return
        while (iterator.hasNext()) {
            val pkg = iterator.next()
            if (pkg.isNullOrBlank()) continue
            try {
                if (include) {
                    builder.addAllowedApplication(pkg)
                } else {
                    builder.addDisallowedApplication(pkg)
                }
            } catch (e: PackageManager.NameNotFoundException) {
                Log.w(TAG, "package not found: $pkg")
            } catch (e: Exception) {
                Log.w(TAG, "package $pkg: ${e.message}")
            }
        }
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        try {
            service.protect(fd)
        } catch (e: Exception) {
            Log.w(TAG, "protect($fd): ${e.message}")
        }
    }

    override fun writeLog(message: String?) {
        Log.i(TAG, message ?: "")
    }

    override fun useProcFS(): Boolean {
        // On modern Android, Connectivity/Network APIs are preferred
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int,
    ): Int {
        // Optional; return -1 if unknown
        return -1
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        // Optional for first bring-up
        Log.d(TAG, "startDefaultInterfaceMonitor")
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        Log.d(TAG, "closeDefaultInterfaceMonitor")
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        return EmptyNetworkInterfaceIterator
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() {
        // no-op on Android app side
    }

    override fun readWIFIState(): WIFIState? = null

    override fun packageNameByUid(uid: Int): String {
        return try {
            val pkgs = service.packageManager.getPackagesForUid(uid)
            pkgs?.firstOrNull() ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    override fun uidByPackageName(packageName: String?): Int {
        if (packageName.isNullOrBlank()) return -1
        return try {
            service.packageManager.getApplicationInfo(packageName, 0).uid
        } catch (_: Exception) {
            -1
        }
    }

    override fun usePlatformDefaultInterfaceMonitor(): Boolean = false

    override fun usePlatformInterfaceGetter(): Boolean = false

    fun closeTun() {
        try {
            tunFd?.close()
        } catch (_: Exception) {
        }
        tunFd = null
    }
}

/**
 * Minimal empty iterator so getInterfaces() compiles & is safe.
 * Can be replaced later with real NetworkInterface listing.
 */
private object EmptyNetworkInterfaceIterator : NetworkInterfaceIterator {
    override fun hasNext(): Boolean = false
    override fun next(): libbox.NetworkInterface? = null
}
