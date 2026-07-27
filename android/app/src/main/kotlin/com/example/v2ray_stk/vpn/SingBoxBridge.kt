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
 * چرا reflection؟
 * امضای متدهای PlatformInterface در نسخه‌های مختلف libbox تغییر می‌کند.
 * با Proxy داینامیک، هر متدی که هسته صدا بزند در runtime پاسخ می‌گیرد،
 * پس این فایل با هر نسخه‌ای از AAR کامپایل می‌شود.
 */
object SingBoxBridge {

    private const val TAG = "SingBoxBridge"
    private const val CLS_LIBBOX = "io.nekohasekai.libbox.Libbox"
    private const val CLS_PLATFORM = "io.nekohasekai.libbox.PlatformInterface"

    @Volatile
    private var boxService: Any? = null

    @Volatile
    private var didSetup = false

    /** اگر AAR داخل apk باشد true می‌شود (بدون هاردکد) */
    val isCoreAvailable: Boolean
        get() = clazz(CLS_LIBBOX) != null && clazz(CLS_PLATFORM) != null

    // ---------------------------------------------------------------- public

    fun start(vpnService: VpnService, tunFd: Int, config: String) {
        if (!isCoreAvailable) {
            Log.e(TAG, "libbox در classpath نیست")
            return
        }
        stop()

        val libbox = clazz(CLS_LIBBOX)!!
        setupCore(libbox, vpnService)

        val platform = createPlatformInterface(vpnService, tunFd)
        val service = invokeNewService(libbox, config, platform)
            ?: throw IllegalStateException("newService برنگشت")

        callNoArg(service, "start")
        boxService = service
        Log.i(TAG, "هسته sing-box اجرا شد (fd=$tunFd)")
    }

    fun stop() {
        val s = boxService ?: return
        boxService = null
        runCatching { callNoArg(s, "close") }
            .onFailure { runCatching { callNoArg(s, "stop") } }
        Log.i(TAG, "هسته sing-box متوقف شد")
    }

    // ----------------------------------------------------------- core setup

    private fun setupCore(libbox: Class<*>, ctx: VpnService) {
        if (didSetup) return

        val base = ctx.filesDir.absolutePath
        val work = File(ctx.filesDir, "work").apply { mkdirs() }.absolutePath
        val temp = ctx.cacheDir.absolutePath

        val setup = libbox.methods.firstOrNull { it.name == "setup" }
            ?: run {
                Log.w(TAG, "متد setup پیدا نشد؛ رد شد")
                didSetup = true
                return
            }

        val p = setup.parameterTypes
        try {
            when {
                // setup(basePath, workingPath, tempPath, isTVOS)
                p.size == 4 -> setup.invoke(null, base, work, temp, false)
                // setup(basePath, workingPath, tempPath)
                p.size == 3 -> setup.invoke(null, base, work, temp)
                // setup(SetupOptions)
                p.size == 1 -> {
                    val opt = p[0].getDeclaredConstructor().newInstance()
                    setString(opt, "BasePath", base)
                    setString(opt, "WorkingPath", work)
                    setString(opt, "TempPath", temp)
                    setup.invoke(null, opt)
                }
                else -> setup.invoke(null)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "setup خطا داد: ${t.message}")
        }

        // لاگ‌های هسته را به فایل هدایت کن (اختیاری)
        runCatching {
            libbox.methods.firstOrNull { it.name == "redirectStderr" }
                ?.invoke(null, File(ctx.filesDir, "stderr.log").absolutePath)
        }

        didSetup = true
    }

    private fun invokeNewService(libbox: Class<*>, config: String, platform: Any): Any? {
        val candidates = libbox.methods.filter { it.name == "newService" }
        // اول نسخهٔ دوپارامتری (config, platformInterface)
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
        val handler = InvocationHandler { _, method: Method, args: Array<out Any?>? ->
            handlePlatformCall(vpn, tunFd, method, args)
        }
        return Proxy.newProxyInstance(iface.classLoader, arrayOf(iface), handler)
    }

    private fun handlePlatformCall(
        vpn: VpnService,
        tunFd: Int,
        method: Method,
        args: Array<out Any?>?
    ): Any? {
        val name = method.name
        return when (name) {
            // ---- TUN: ما خودمان در V2rayVpnService ساختیم، فقط fd را می‌دهیم
            "openTun" -> tunFd

            // ---- protect کردن سوکت‌های خروجی هسته (حیاتی برای جلوگیری از loop)
            "autoDetectInterfaceControl" -> {
                val fd = (args?.getOrNull(0) as? Number)?.toInt() ?: -1
                if (fd > 0) vpn.protect(fd)
                null
            }
            "usePlatformAutoDetectInterfaceControl" -> true

            // ---- مانیتور اینترفیس را به خود هسته بسپار
            "usePlatformDefaultInterfaceMonitor" -> false
            "usePlatformInterfaceGetter" -> false
            "startDefaultInterfaceMonitor", "closeDefaultInterfaceMonitor" -> null

            // ---- تشخیص مالک کانکشن (برای split tunneling پیشرفته؛ فعلاً خاموش)
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
                Log.d(TAG, args?.getOrNull(0)?.toString() ?: "")
                null
            }

            // ---- متدهای Object
            "toString" -> "V2rayStkPlatformInterface"
            "hashCode" -> System.identityHashCode(this)
            "equals" -> args?.getOrNull(0) === this

            else -> defaultFor(method)
        }
    }

    /** برای هر متد ناشناختهٔ نسخه‌های جدید libbox، مقدار بی‌خطر برگردان */
    private fun defaultFor(method: Method): Any? {
        Log.d(TAG, "متد ناشناخته PlatformInterface: ${method.name}")
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
        try {
            Class.forName(name)
        } catch (t: Throwable) {
            null
        }

    private fun newInstanceOrNull(name: String): Any? =
        runCatching { clazz(name)?.getDeclaredConstructor()?.newInstance() }.getOrNull()

    private fun callNoArg(target: Any, method: String) {
        target.javaClass.methods.first { it.name == method && it.parameterTypes.isEmpty() }
            .invoke(target)
    }

    /** gomobile برای فیلدهای struct، setter می‌سازد: setBasePath(...) */
    private fun setString(target: Any, field: String, value: String) {
        runCatching {
            target.javaClass.methods
                .first { it.name == "set$field" && it.parameterTypes.size == 1 }
                .invoke(target, value)
        }
    }
}
