package com.v2raystk.v2ray_stk.vpn

import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import libbox.InterfaceUpdateListener
import libbox.Libbox
import libbox.NetworkInterface
import libbox.NetworkInterfaceIterator
import libbox.PlatformInterface
import libbox.RoutePrefixIterator
import libbox.StringIterator
import libbox.TunOptions
import libbox.WIFIState

/**
 * Bridge between Android VpnService and sing-box libbox PlatformInterface.
 *
 * Must match libbox.aar public API exactly (package: libbox).
 * Verified via javap:
 *  - openTun(TunOptions): Int
 *  - RoutePrefix.address()/prefix()
 *  - RoutePrefixIterator / StringIterator / NetworkInterfaceIterator: hasNext()/next()
 */
class BoxPlatformInterface(
    private val service: V2rayVpnService,
) : PlatformInterface {

    companion object {
        private const val TAG = "BoxPlatformInterface"
    }

    private var tunFd: ParcelFileDescriptor? = null

    @Throws(Exception::class)
    override fun openTun(options: TunOptions): Int {
        try {
            tunFd?.close()
        } catch (_: Exception) {
        }
        tunFd = null

        val builder = service.Builder()
        builder.setSession("V2ray Stk")

        val mtu = try {
            options.mtu
        } catch (_: Exception) {
            9000
        }
        builder.setMtu(if (mtu > 0) mtu else 9000)

        // Addresses
        addAddresses(builder, safeRouteIterator { options.inet4Address })
        addAddresses(builder, safeRouteIterator { options.inet6Address })

        // Routes
        val autoRoute = try {
            options.autoRoute
        } catch (_: Exception) {
            true
        }

        if (autoRoute) {
            val v4Routes = safeRouteIterator { options.inet4RouteAddress }
            val v6Routes = safeRouteIterator { options.inet6RouteAddress }
            val v4Count = addRoutes(builder, v4Routes)
            addRoutes(builder, v6Routes)

            // Fallback default IPv4 route if none provided
            if (v4Count == 0) {
                try {
                    builder.addRoute("0.0.0.0", 0)
                } catch (e: Exception) {
                    Log.w(TAG, "default v4 route: ${e.message}")
                }
            }

            // Optional extra ranges (best-effort)
            try {
                addRoutes(builder, safeRouteIterator { options.inet4RouteRange })
            } catch (e: Exception) {
                Log.w(TAG, "inet4RouteRange: ${e.message}")
            }
            try {
                addRoutes(builder, safeRouteIterator { options.inet6RouteRange })
            } catch (e: Exception) {
                Log.w(TAG, "inet6RouteRange: ${e.message}")
            }
        }

        // DNS
        try {
            val dns = options.dnsServerAddress
            if (!dns.isNullOrBlank()) {
                builder.addDnsServer(dns)
            } else {
                builder.addDnsServer("1.1.1.1")
            }
        } catch (e: Exception) {
            Log.w(TAG, "dnsServerAddress: ${e.message}")
            try {
                builder.addDnsServer("1.1.1.1")
            } catch (_: Exception) {
            }
        }

        // Per-app include / exclude
        try {
            applyPackages(builder, safeStringIterator { options.includePackage }, include = true)
        } catch (e: Exception) {
            Log.w(TAG, "includePackage: ${e.message}")
        }
        try {
            applyPackages(builder, safeStringIterator { options.excludePackage }, include = false)
        } catch (e: Exception) {
            Log.w(TAG, "excludePackage: ${e.message}")
        }

        // Never capture our own app traffic
        try {
            builder.addDisallowedApplication(service.packageName)
        } catch (_: Exception) {
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                builder.setMetered(false)
            } catch (_: Exception) {
            }
        }

        // Optional HTTP proxy (Android Q+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                if (options.isHTTPProxyEnabled) {
                    val host = options.httpProxyServer
                    val port = options.httpProxyServerPort
                    if (!host.isNullOrBlank() && port > 0) {
                        builder.setHttpProxy(
                            android.net.ProxyInfo.buildDirectProxy(host, port)
                        )
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "httpProxy: ${e.message}")
            }
        }

        val pfd = builder.establish()
            ?: throw IllegalStateException("VpnService.Builder.establish() returned null (VPN permission missing?)")

        tunFd = pfd
        val fd = pfd.fd
        Log.i(TAG, "openTun ok fd=$fd mtu=$mtu")
        return fd
    }

    private fun safeRouteIterator(block: () -> RoutePrefixIterator?): RoutePrefixIterator? {
        return try {
            block()
        } catch (e: Exception) {
            Log.w(TAG, "route iterator: ${e.message}")
            null
        }
    }

    private fun safeStringIterator(block: () -> StringIterator?): StringIterator? {
        return try {
            block()
        } catch (e: Exception) {
            Log.w(TAG, "string iterator: ${e.message}")
            null
        }
    }

    private fun addAddresses(builder: VpnService.Builder, iterator: RoutePrefixIterator?) {
        if (iterator == null) return
        while (iterator.hasNext()) {
            val prefix = iterator.next() ?: continue
            val addr = try {
                prefix.address()
            } catch (_: Exception) {
                null
            }
            val prefixLen = try {
                prefix.prefix()
            } catch (_: Exception) {
                -1
            }
            if (addr.isNullOrBlank() || prefixLen < 0) continue
            try {
                builder.addAddress(addr, prefixLen)
            } catch (e: Exception) {
                Log.w(TAG, "addAddress $addr/$prefixLen: ${e.message}")
            }
        }
    }

    private fun addRoutes(builder: VpnService.Builder, iterator: RoutePrefixIterator?): Int {
        if (iterator == null) return 0
        var count = 0
        while (iterator.hasNext()) {
            val prefix = iterator.next() ?: continue
            val addr = try {
                prefix.address()
            } catch (_: Exception) {
                null
            }
            val prefixLen = try {
                prefix.prefix()
            } catch (_: Exception) {
                -1
            }
            if (addr.isNullOrBlank() || prefixLen < 0) continue
            try {
                builder.addRoute(addr, prefixLen)
                count++
            } catch (e: Exception) {
                Log.w(TAG, "addRoute $addr/$prefixLen: ${e.message}")
            }
        }
        return count
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
            } catch (_: PackageManager.NameNotFoundException) {
                Log.w(TAG, "package not found: $pkg")
            } catch (e: Exception) {
                Log.w(TAG, "package $pkg: ${e.message}")
            }
        }
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    @Throws(Exception::class)
    override fun autoDetectInterfaceControl(fd: Int) {
        try {
            service.protect(fd)
        } catch (e: Exception) {
            Log.w(TAG, "protect($fd): ${e.message}")
            throw e
        }
    }

    override fun writeLog(message: String?) {
        Log.i(TAG, message ?: "")
    }

    override fun useProcFS(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
    }

    @Throws(Exception::class)
    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int,
    ): Int {
        // Optional on first integration
        return -1
    }

    @Throws(Exception::class)
    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        Log.d(TAG, "startDefaultInterfaceMonitor")
    }

    @Throws(Exception::class)
    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        Log.d(TAG, "closeDefaultInterfaceMonitor")
    }

    @Throws(Exception::class)
    override fun getInterfaces(): NetworkInterfaceIterator {
        return EmptyNetworkInterfaceIterator
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() {
        // no-op
    }

    override fun readWIFIState(): WIFIState {
        return try {
            Libbox.newWIFIState("", "")
        } catch (_: Exception) {
            // Fallback: if native fails, still satisfy non-null return shape
            Libbox.newWIFIState("", "")
        }
    }

    @Throws(Exception::class)
    override fun packageNameByUid(uid: Int): String {
        return try {
            val pkgs = service.packageManager.getPackagesForUid(uid)
            pkgs?.firstOrNull() ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    @Throws(Exception::class)
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
 * Empty iterator compatible with:
 *   interface NetworkInterfaceIterator { boolean hasNext(); NetworkInterface next(); }
 */
private object EmptyNetworkInterfaceIterator : NetworkInterfaceIterator {
    override fun hasNext(): Boolean = false

    override fun next(): NetworkInterface {
        throw NoSuchElementException("empty NetworkInterfaceIterator")
    }
}
