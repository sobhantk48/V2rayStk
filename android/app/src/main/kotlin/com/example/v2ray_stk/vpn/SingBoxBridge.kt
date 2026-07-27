package com.example.v2ray_stk.vpn

import android.net.VpnService
import android.util.Log
import java.io.File
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Method
import java.lang.reflect.Proxy

/**
 * پل ارتباطی با هستهٔ واقعی sing-box (libbox.aar)
 *
 * ترتیب حیاتی راه‌اندازی:
 *   setup() -> newCommandServer().start() -> newService() -> setService() -> start()
 * اگر CommandServer بعد از newService ساخته شود، CommandClient هیچ‌وقت وصل نمی‌شود.
 */
object SingBoxBridge {

    private const val TAG = "SingBoxBridge"
    private const val CLS_LIBBOX = "io.nekohasekai.libbox.Libbox"
    private const val CLS_PLATFORM = "io.nekohasekai.libbox.PlatformInterface"
    private const val CLS_SERVER_HANDLER = "io.nekohasekai.libbox.CommandServerHandler"

    @Volatile private var boxService: Any? = null
    @Volatile private var commandServer: Any? = null
    @Volatile private var didSetup = false

    val isCoreAvailable: Boolean
        get() = clazz(CLS_LIBBOX) != null && clazz(CLS_PLATFORM) != null

    // ---------------------------------------------------------------- public

    fun start(vpnService: VpnService, tunFd: Int, config: String) {
        if (!isCoreAvailable) {
            LogStore.add("libbox در classpath نیست", "fatal", "app")
            return
        }
        stop()

        val libbox = clazz(CLS_LIBBOX)!!
        setupCore(libbox, vpnService)

        commandServer = startCommandServer(libbox)

        val platform = createPlatformInterface(vpnService, tunFd)
        val service = invokeNewService(libbox, config, platform)
            ?: throw IllegalStateException("newService برنگشت")

        commandServer?.let { srv ->
            runCatching {
                srv.javaClass.methods.first {
                    it.name == "setService" && it.parameterTypes.size == 1
                }.invoke(srv, service)
            }.onFailure { LogStore.add("setService ناموفق: ${it.message}", "warn", "app") }
        }

        callNoArg(service, "start")
        boxService = service

        LogStore.add("هسته sing-box اجرا شد (tun fd=$tunFd)", "info", "app")
        CommandClientBridge.start()
    }

    fun stop() {
        CommandClientBridge.stop()

        boxService?.let { s ->
            boxService = null
            runCatching { callNoArg(s, "close") }
                .onFailure { runCatching { callNoArg(s, "stop") } }
        }
        commandServer?.let { srv ->
            commandServer = null
            runCatching { callNoArg(srv, "close") }
        }
    }

    // ----------------------------------------------------------- core setup

    private fun setupCore(libbox: Class<*>, ctx: VpnService) {
        if (didSetup) return

        val base = ctx.filesDir.absolutePath
        val work = File(ctx.filesDir, "work").apply { mkdirs() }.absolutePath
        val temp = ctx.cacheDir.absolutePath

        val setup = libbox.methods.firstOrNull { it.name == "setup" }
        if (setup == null) {
            LogStore.add("متد setup در libbox نیست؛ رد شد", "warn", "app")
            didSetup = true
            return
        }

        try {
            val p = setup.parameterTypes
            when {
                p.size == 4 -> setup.invoke(null, base, work, temp, false)
                p.size == 3 -> setup.invoke(null, base, work, temp)
                p.size == 1 -> {
                    val opt = p[0].getDeclaredConstructor().newInstance()
                    setString(opt, "BasePath", base)
                    setString(opt, "WorkingPath", work)
                    setString(opt, "TempPath", temp)
                    setup.invoke(null, opt)
                }
                else -> setup.invoke(null)
            }
            LogStore.add("libbox setup انجام شد", "info", "app")
        } catch (t: Throwable) {
            LogStore.add("setup خطا داد: ${t.message}", "error", "app")
        }

        runCatching {
            libbox.methods.firstOrNull { it.name == "redirectStderr" }
                ?.invoke(null, File(ctx.filesDir, "stderr.log").absolutePath)
        }

        didSetup = true
    }

    private fun startCommandServer(libbox: Class<*>): Any? {
        val handlerIface = clazz(CLS_SERVER_HANDLER) ?: return null
        val factory = libbox.methods.firstOrNull { it.name == "newCommandServer" } ?: return null

        val handler = Proxy.newProxyInstance(
            handlerIface.classLoader,
            arrayOf(handlerIface),
            InvocationHandler { _, m, args -> handleServerCall(m, args) }
        )

        return runCatching {
            val srv = when (factory.parameterTypes.size) {
                2 -> factory.invoke(null, handler, 300)
                else -> factory.invoke(null, handler)
            }
            callNoArg(srv!!, "start")
            LogStore.add("CommandServer بالا آمد", "info", "app")
            srv
        }.onFailure {
            LogStore.add("CommandServer ناموفق: ${it.message}", "warn", "app")
        }.getOrNull()
    }

    private fun handleServerCall(method: Method, args: Array<out Any?>?): Any? = when (method.name) {
        "serviceReload" -> null
        "postServiceClose" -> null
        "getSystemProxyStatus" -> newInstanceOrNull("io.nekohasekai.libbox.SystemProxyStatus")
        "setSystemProxyEnabled" -> null
        "toString" -> "V2rayStkCommandServerHandler"
        "hashCode" -> System.identityHashCode(this)
        "equals" -> args?.getOrNull(0) === this
        else -> defaultFor(method)
    }

    private fun invokeNewService(libbox: Class<*>, config: String, platform: Any): Any? {
        val candidates = libbox.methods.filter { it.name == "newService" }
        candidates.firstOrNull { it.parameterTypes.size == 2 }?.let {
            return it.invoke(null, config, platform)
        }
        candidates.firstOrNull { it.parameterTypes.size == 1 }?.let {
            return it.invoke(null, config)
        }
        return null
    }

    // ------------------------------------------------ dynamic PlatformInterface

    private fun createPlatformInterface(vpn: VpnService, tunFd: Int): Any {
        val iface = clazz(CLS_PLATFORM)!!
        return Proxy.newProxyInstance(
            iface.classLoader,
            arrayOf(iface),
            InvocationHandler { _, m, args -> handlePlatformCall(vpn, tunFd, m, args) }
        )
    }

    private fun handlePlatformCall(
        vpn: VpnService,
        tunFd: Int,
        method: Method,
        args: Array<out Any?>?
    ): Any? = when (method.name) {

        "openTun" -> tunFd

        "autoDetectInterfaceControl" -> {
            val fd = (args?.getOrNull(0) as? Number)?.toInt() ?: -1
            if (fd > 0) vpn.protect(fd)
            null
        }
        "usePlatformAutoDetectInterfaceControl" -> true

        "usePlatformDefaultInterfaceMonitor" -> false
        "usePlatformInterfaceGetter" -> false
        "startDefaultInterfaceMonitor", "closeDefaultInterfaceMonitor" -> null

        "useProcFS" -> false
        "findConnectionOwner" -> throw UnsupportedOperationException("not supported")
        "packageNameByUid" -> throw UnsupportedOperationException("not supported")
        "uidByPackageName" -> throw UnsupportedOperationException("not supported")

        "underNetworkExtension" -> false
        "includeAllNetworks" -> false
        "clearDNSCache" -> null
        "localDNSTransport" -> null
        "systemCertificates" -> null
        "sendNotification" -> null

        "readWIFIState" -> newInstanceOrNull("io.nekohasekai.libbox.WIFIState")

        "writeLog" -> {
            LogStore.add(args?.getOrNull(0)?.toString(), null, "core")
            null
        }

        "toString" -> "V2rayStkPlatformInterface"
        "hashCode" -> System.identityHashCode(this)
        "equals" -> args?.getOrNull(0) === this

        else -> defaultFor(method)
    }

    private fun defaultFor(method: Method): Any? {
        Log.d(TAG, "متد ناشناخته: ${method.name}")
        return when (method.returnType) {
            Void.TYPE -> null
            Boolean::class.javaPrimitiveType -> false
            Int::class.javaPrimitiveType -> 0
            Long::class.javaPrimitiveType -> 0L
            Double::class.javaPrimitiveType -> 0.0
            String::class.java -> ""
            else -> null
        }
    }

    // --------------------------------------------------------------- helpers

    private fun clazz(name: String): Class<*>? =
        try { Class.forName(name) } catch (t: Throwable) { null }

    private fun newInstanceOrNull(name: String): Any? =
        runCatching { clazz(name)?.getDeclaredConstructor()?.newInstance() }.getOrNull()

    private fun callNoArg(target: Any, method: String) {
        target.javaClass.methods
            .first { it.name == method && it.parameterTypes.isEmpty() }
            .invoke(target)
    }

    private fun setString(target: Any, field: String, value: String) {
        runCatching {
            target.javaClass.methods
                .first { it.name == "set$field" && it.parameterTypes.size == 1 }
                .invoke(target, value)
        }
    }
}
