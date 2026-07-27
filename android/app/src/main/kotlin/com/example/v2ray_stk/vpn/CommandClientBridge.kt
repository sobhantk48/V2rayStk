package com.example.v2ray_stk.vpn

import android.util.Log
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Method
import java.lang.reflect.Proxy

/**
 * اتصال به CommandServer هستهٔ sing-box برای:
 *  - آمار زندهٔ ترافیک (uplink/downlink و مجموع)
 *  - استریم لاگ هسته
 *
 * کاملاً reflection-محور تا با هر نسخه‌ای از libbox.aar کامپایل شود.
 */
object CommandClientBridge {

    private const val TAG = "CommandClient"
    private const val CLS_LIBBOX = "io.nekohasekai.libbox.Libbox"
    private const val CLS_HANDLER = "io.nekohasekai.libbox.CommandClientHandler"
    private const val CLS_OPTIONS = "io.nekohasekai.libbox.CommandClientOptions"

    @Volatile var uplink: Long = 0L; private set
    @Volatile var downlink: Long = 0L; private set
    @Volatile var uplinkTotal: Long = 0L; private set
    @Volatile var downlinkTotal: Long = 0L; private set
    @Volatile var memory: Long = 0L; private set
    @Volatile var goroutines: Long = 0L; private set
    @Volatile var connectionsIn: Long = 0L; private set
    @Volatile var connectionsOut: Long = 0L; private set

    /** true یعنی حداقل یک StatusMessage از هسته گرفته‌ایم */
    @Volatile var hasData: Boolean = false; private set

    private var statusClient: Any? = null
    private var logClient: Any? = null

    // ------------------------------------------------------------------ public

    fun start() {
        resetCounters()
        statusClient = openClient(commandConst("CommandStatus", 1), isLog = false)
        logClient = openClient(commandConst("CommandLog", 0), isLog = true)
    }

    fun stop() {
        closeClient(statusClient); statusClient = null
        closeClient(logClient); logClient = null
        resetCounters()
    }

    private fun resetCounters() {
        uplink = 0; downlink = 0
        uplinkTotal = 0; downlinkTotal = 0
        memory = 0; goroutines = 0
        connectionsIn = 0; connectionsOut = 0
        hasData = false
    }

    // ------------------------------------------------------------------ client

    private fun openClient(command: Int, isLog: Boolean): Any? {
        val libbox = clazz(CLS_LIBBOX) ?: return null
        val handlerIface = clazz(CLS_HANDLER) ?: return null

        val options = buildOptions(command) ?: return null

        val handler = Proxy.newProxyInstance(
            handlerIface.classLoader,
            arrayOf(handlerIface),
            InvocationHandler { _, m, args -> handleCallback(isLog, m, args) }
        )

        val factory = libbox.methods.firstOrNull {
            it.name == "newCommandClient" && it.parameterTypes.size == 2
        } ?: run {
            LogStore.add("newCommandClient در این نسخه libbox نیست", "warn", "app")
            return null
        }

        val client = runCatching { factory.invoke(null, handler, options) }
            .onFailure { LogStore.add("ساخت CommandClient خطا داد: ${it.message}", "error", "app") }
            .getOrNull() ?: return null

        // connect ممکن است بلاک شود؛ روی ترد جدا و با چند بار تلاش
        Thread {
            var ok = false
            repeat(10) { attempt ->
                if (ok) return@repeat
                try {
                    callNoArg(client, "connect")
                    ok = true
                } catch (t: Throwable) {
                    Thread.sleep(300)
                    if (attempt == 9) {
                        LogStore.add(
                            "اتصال CommandClient (cmd=$command) ناموفق: ${t.message}",
                            "warn", "app"
                        )
                    }
                }
            }
        }.apply { isDaemon = true }.start()

        return client
    }

    private fun buildOptions(command: Int): Any? {
        val cls = clazz(CLS_OPTIONS) ?: return null
        val opt = runCatching { cls.getDeclaredConstructor().newInstance() }.getOrNull()
            ?: return null
        setter(opt, "setCommand", Int::class.javaPrimitiveType!!, command)
        // بازهٔ به‌روزرسانی آمار: ۱ ثانیه (نانوثانیه)
        setter(opt, "setStatusInterval", Long::class.javaPrimitiveType!!, 1_000_000_000L)
        return opt
    }

    private fun closeClient(client: Any?) {
        val c = client ?: return
        runCatching { callNoArg(c, "disconnect") }
            .onFailure { runCatching { callNoArg(c, "close") } }
    }

    // ---------------------------------------------------------------- callbacks

    private fun handleCallback(isLog: Boolean, method: Method, args: Array<out Any?>?): Any? {
        return when (method.name) {
            "connected" -> {
                LogStore.add(
                    if (isLog) "استریم لاگ هسته وصل شد" else "آمار زندهٔ هسته وصل شد",
                    "info", "app"
                )
                null
            }

            "disconnected" -> {
                val msg = args?.getOrNull(0)?.toString().orEmpty()
                if (msg.isNotBlank()) LogStore.add("CommandClient قطع شد: $msg", "warn", "app")
                if (!isLog) hasData = false
                null
            }

            "clearLog" -> null

            "writeLog" -> {
                LogStore.add(args?.getOrNull(0)?.toString(), null, "core")
                null
            }

            "writeLogs" -> {
                val list = args?.getOrNull(0)
                iterate(list) { LogStore.add(it?.toString(), null, "core") }
                null
            }

            "writeStatus" -> {
                args?.getOrNull(0)?.let { readStatus(it) }
                null
            }

            "toString" -> "V2rayStkCommandClientHandler"
            "hashCode" -> System.identityHashCode(this)
            "equals" -> args?.getOrNull(0) === this

            else -> defaultFor(method)
        }
    }

    private fun readStatus(status: Any) {
        uplink = longOf(status, "getUplink", "getUpload")
        downlink = longOf(status, "getDownlink", "getDownload")
        uplinkTotal = longOf(status, "getUplinkTotal", "getUploadTotal")
        downlinkTotal = longOf(status, "getDownlinkTotal", "getDownloadTotal")
        memory = longOf(status, "getMemory")
        goroutines = longOf(status, "getGoroutines")
        connectionsIn = longOf(status, "getConnectionsIn")
        connectionsOut = longOf(status, "getConnectionsOut")
        hasData = true
    }

    // ------------------------------------------------------------------ helpers

    private fun clazz(name: String): Class<*>? =
        try { Class.forName(name) } catch (t: Throwable) { null }

    private fun commandConst(field: String, fallback: Int): Int {
        val libbox = clazz(CLS_LIBBOX) ?: return fallback
        return runCatching {
            val f = libbox.getDeclaredField(field)
            f.isAccessible = true
            (f.get(null) as Number).toInt()
        }.getOrElse { fallback }
    }

    private fun callNoArg(target: Any, method: String) {
        target.javaClass.methods
            .first { it.name == method && it.parameterTypes.isEmpty() }
            .invoke(target)
    }

    private fun setter(target: Any, name: String, type: Class<*>, value: Any) {
        runCatching {
            target.javaClass.methods
                .first { it.name == name && it.parameterTypes.size == 1 }
                .invoke(target, value)
        }.onFailure {
            Log.d(TAG, "setter $name ناموفق: ${it.message} ($type)")
        }
    }

    private fun longOf(target: Any, vararg names: String): Long {
        for (n in names) {
            val v = runCatching {
                target.javaClass.methods.first { it.name == n && it.parameterTypes.isEmpty() }
                    .invoke(target)
            }.getOrNull()
            if (v is Number) return v.toLong()
        }
        return 0L
    }

    /** لیست‌های gomobile با size()/get(i) پیمایش می‌شوند */
    private fun iterate(list: Any?, block: (Any?) -> Unit) {
        val l = list ?: return
        if (l is Iterable<*>) { l.forEach(block); return }
        runCatching {
            val size = (l.javaClass.getMethod("size").invoke(l) as Number).toInt()
            val get = l.javaClass.getMethod("get", Int::class.javaPrimitiveType)
            for (i in 0 until size) block(get.invoke(l, i))
        }
    }

    private fun defaultFor(method: Method): Any? = when (method.returnType) {
        Void.TYPE -> null
        Boolean::class.javaPrimitiveType -> false
        Int::class.javaPrimitiveType -> 0
        Long::class.javaPrimitiveType -> 0L
        Double::class.javaPrimitiveType -> 0.0
        String::class.java -> ""
        else -> null
    }
}
