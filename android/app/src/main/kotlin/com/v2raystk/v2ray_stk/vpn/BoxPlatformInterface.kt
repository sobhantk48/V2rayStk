package com.v2raystk.v2ray_stk.vpn

import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import io.flutter.Log
import libbox.InterfaceUpdateListener
import libbox.NetworkInterfaceIterator
import libbox.PlatformInterface
import libbox.StringIterator
import libbox.TunOptions
import libbox.WIFIState
import java.net.InetSocketAddress

/**
 * Bridge between sing-box/libbox and Android VpnService.
 * Libbox calls openTun(); we create the system TUN and return its fd.
 */
class BoxPlatformInterface(
    private val service: VpnService,
    private val onTunCreated: (ParcelFileDescriptor) -> Unit,
) : PlatformInterface {

    override fun openTun(options: TunOptions): Int {
        val builder = service.Builder()
            .setSession("V2ray Stk")
            .setMtu(options.mtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        // IPv4 addresses
        try {
            val inet4 = options.inet4Address
            while (inet4.hasNext()) {
                val prefix = inet4.next()
                builder.addAddress(prefix.address(), prefix.prefix())
            }
        } catch (e: Exception) {
            Log.w("BoxPlatform", "inet4Address: ${e.message}")
            builder.addAddress("10.0.0.2", 32)
        }

        // IPv6 addresses (optional)
        try {
            val inet6 = options.inet6Address
            while (inet6.hasNext()) {
                val prefix = inet6.next()
                builder.addAddress(prefix.address(), prefix.prefix())
            }
        } catch (e: Exception) {
            Log.w("BoxPlatform", "inet6Address: ${e.message}")
        }

        // Routes
        if (options.autoRoute) {
            try {
                val route4 = options.inet4RouteAddress
                var hasRoute = false
                while (route4.hasNext()) {
                    val prefix = route4.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                    hasRoute = true
                }
                if (!hasRoute) {
                    builder.addRoute("0.0.0.0", 0)
                }
            } catch (e: Exception) {
                builder.addRoute("0.0.0.0", 0)
            }

            try {
                val route6 = options.inet6RouteAddress
                while (route6.hasNext()) {
                    val prefix = route6.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
            } catch (_: Exception) {
            }
        } else {
            builder.addRoute("0.0.0.0", 0)
        }

        // DNS
        try {
            val dns = options.dnsServerAddress
            while (dns.hasNext()) {
                builder.addDnsServer(dns.next())
            }
        } catch (e: Exception) {
            builder.addDnsServer("1.1.1.1")
            builder.addDnsServer("8.8.8.8")
        }

        // Do not exclude ourselves: libbox uses protect() for outbound sockets.
        val pfd = builder.establish()
            ?: throw IllegalStateException("Failed to establish VPN interface")

        onTunCreated(pfd)
        Log.i("BoxPlatform", "TUN established fd=${pfd.fd}")
        return pfd.fd
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        try {
            service.protect(fd)
        } catch (e: Exception) {
            Log.e("BoxPlatform", "protect($fd) failed", e)
        }
    }

    override fun writeLog(message: String?) {
        if (!message.isNullOrBlank()) {
            Log.i("libbox", message)
        }
    }

    override fun useProcFS(): Boolean = false

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int,
    ): Int = -1

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
        // Optional: network callback can be added later
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {
    }

    override fun getInterfaces(): NetworkInterfaceIterator? = null

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() {
    }

    override fun readWIFIState(): WIFIState? = null

    override fun localDNSTransport(): libbox.LocalDNSTransport? = null

    // Some libbox versions expose these; safe no-op stubs if present in interface
    override fun systemCertificates(): StringIterator? = null

    override fun sendNotification(notification: libbox.Notification?) {
    }
}
