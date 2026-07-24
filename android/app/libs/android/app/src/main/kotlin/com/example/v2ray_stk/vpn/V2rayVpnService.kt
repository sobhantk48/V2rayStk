package com.example.v2ray_stk.vpn

import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import libbox.InterfaceUpdateListener
import libbox.Libbox
import libbox.NetworkInterfaceIterator
import libbox.PlatformInterface
import libbox.TunOptions
import libbox.WIFIState

/**
 * سرویس اصلی VPN مبتنی بر هسته‌ی sing-box (libbox).
 * این کلاس هم VpnService اندروید است و هم PlatformInterface را برای libbox پیاده‌سازی می‌کند.
 */
class V2rayVpnService : VpnService(), PlatformInterface {

    private var tunFd: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // منطق راه‌اندازی هسته در فاز بعد به اینجا اضافه می‌شود.
        return START_STICKY
    }

    override fun onDestroy() {
        closeTun()
        super.onDestroy()
    }

    // ---------------------------------------------------------------------
    // پیاده‌سازی PlatformInterface — بخش اصلی: ساخت TUN
    // ---------------------------------------------------------------------

    /**
     * ساخت اینترفیس TUN بر اساس تنظیماتی که هسته‌ی sing-box تحویل می‌دهد.
     * برمی‌گرداند: file descriptor عددی برای هسته.
     */
    override fun openTun(options: TunOptions): Int {
        val builder = Builder()
            .setSession("V2rayStk")
            .setMtu(options.mtu)

        // آدرس‌های IPv4
        val inet4 = options.inet4Address
        while (inet4.hasNext()) {
            val prefix = inet4.next()
            builder.addAddress(prefix.address(), prefix.prefix())
        }

        // آدرس‌های IPv6
        val inet6 = options.inet6Address
        while (inet6.hasNext()) {
            val prefix = inet6.next()
            builder.addAddress(prefix.address(), prefix.prefix())
        }

        // مسیرها (routes)
        if (options.autoRoute) {
            val route4 = options.inet4RouteAddress
            if (route4.hasNext()) {
                while (route4.hasNext()) {
                    val prefix = route4.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
            } else {
                builder.addRoute("0.0.0.0", 0)
            }

            val route6 = options.inet6RouteAddress
            if (route6.hasNext()) {
                while (route6.hasNext()) {
                    val prefix = route6.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
            } else {
                builder.addRoute("::", 0)
            }

            // مسیرهای مستثنا (فقط اندروید 13+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val exclude4 = options.inet4RouteExcludeAddress
                while (exclude4.hasNext()) {
                    val prefix = exclude4.next()
                    builder.excludeRoute(android.net.IpPrefix(
                        java.net.InetAddress.getByName(prefix.address()), prefix.prefix()))
                }
                val exclude6 = options.inet6RouteExcludeAddress
                while (exclude6.hasNext()) {
                    val prefix = exclude6.next()
                    builder.excludeRoute(android.net.IpPrefix(
                        java.net.InetAddress.getByName(prefix.address()), prefix.prefix()))
                }
            }
        }

        // فیلتر برنامه‌ها (include / exclude)
        val includePackages = options.includePackage
        while (includePackages.hasNext()) {
            runCatching { builder.addAllowedApplication(includePackages.next()) }
        }
        val excludePackages = options.excludePackage
        while (excludePackages.hasNext()) {
            runCatching { builder.addDisallowedApplication(excludePackages.next()) }
        }

        // پیکربندی HTTP Proxy (اندروید 10+)
        if (options.isHTTPProxyEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setHttpProxy(
                android.net.ProxyInfo.buildDirectProxy(
                    options.httpProxyServer,
                    options.httpProxyServerPort
                )
            )
        }

        val pfd = builder.establish()
            ?: throw IllegalStateException("openTun: establish() برمی‌گرداند null")
        tunFd = pfd
        return pfd.fd
    }

    // ---------------------------------------------------------------------
    // کنترل اینترفیس شبکه
    // ---------------------------------------------------------------------

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    // مانیتور اینترفیس پیش‌فرض را به خود sing-box واگذار می‌کنیم.
    override fun usePlatformDefaultInterfaceMonitor(): Boolean = false

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        // چون usePlatformDefaultInterfaceMonitor=false است، فراخوانی نمی‌شود.
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        // no-op
    }

    // شمارش اینترفیس‌ها را هم به sing-box واگذار می‌کنیم.
    override fun usePlatformInterfaceGetter(): Boolean = false

    override fun getInterfaces(): NetworkInterfaceIterator {
        throw UnsupportedOperationException("getInterfaces called but usePlatformInterfaceGetter=false")
    }

    // ---------------------------------------------------------------------
    // اطلاعات پردازه / بسته‌ها
    // ---------------------------------------------------------------------

    override fun findConnectionOwner(
        ipProto: Int,
        srcIp: String,
        srcPort: Int,
        destIp: String,
        destPort: Int
    ): Int {
        // پشتیبانی نمی‌شود؛ -1 یعنی نامشخص.
        return -1
    }

    override fun packageNameByUid(uid: Int): String {
        val packages = packageManager.getPackagesForUid(uid)
        if (packages.isNullOrEmpty()) {
            throw PackageManager.NameNotFoundException()
        }
        return packages[0]
    }

    override fun uidByPackageName(packageName: String): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageUid(
                packageName,
                PackageManager.PackageInfoFlags.of(0)
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageUid(packageName, 0)
        }
    }

    // ---------------------------------------------------------------------
    // سایر متدهای اجباری
    // ---------------------------------------------------------------------

    override fun useProcFS(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun underNetworkExtension(): Boolean = false

    override fun clearDNSCache() {
        // no-op
    }

    override fun readWIFIState(): WIFIState {
        // بدون اطلاعات وای‌فای؛ مقدار خالی برمی‌گردانیم.
        return WIFIState()
    }

    override fun writeLog(message: String) {
        android.util.Log.d("V2rayStk", message)
    }

    // ---------------------------------------------------------------------
    // کمکی
    // ---------------------------------------------------------------------

    private fun closeTun() {
        runCatching { tunFd?.close() }
        tunFd = null
    }
}
