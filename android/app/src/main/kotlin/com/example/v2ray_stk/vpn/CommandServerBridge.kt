package com.example.v2ray_stk.vpn

import android.util.Log
import java.lang.reflect.Method
import java.lang.reflect.Proxy

/**
 * پل reflection-محور برای io.nekohasekai.libbox.CommandServer
 *
 * بدون این سرور، فایل <filesDir>/command.sock ساخته نمی‌شود و
 * CommandClient (آمار و لاگ زنده) هیچ‌وقت وصل نمی‌شود.
 *
 * امضای AAR فعلی: Libbox.newCommandServer(CommandServerHandler, int maxLines)
 * ترتیب صحیح: start() -> (بعد از ساخت هسته) setService(boxService)
 */
object CommandServerBridge {

    private const val TAG = "CommandServerBridge"

    private const val CLS_LIBBOX = "io.nekohasekai.libbox.Libbox"
    private const val CLS_SERVER = "io.nekohasekai.libbox.CommandServer"
    private const val CLS_SERVER_HANDLER = "io.nekohasekai.libbox.CommandServerHandler"
    private const val CLS_PROXY_STATUS = "io.nekohasekai.libbox.SystemProxyStatus"

    private const val MAX_LOG_LINES = 300

    @Volatile
    private var server: Any? = null

    @Volatile
    var isRunning: Boolean = false
        private set

    @Volatile
    var onServiceClose: (() -> Unit)? = null

    @Synchronized
    fun start(): Boolean {
        if (server != null) return true

        val handler = createHandler()
        if (handler == null) {
            LogStore.add(
                "CommandServerHandler در AAR پیدا نشد",
                levelHint = "warn",
                tag = "core",
            )
            return false
        }

        val instance = createServer(handler)
        if (instance == null) {
            LogStore.add(
                "ساخت CommandServer ناموفق بود",
                levelHint = "warn",
                tag = "core",
            )
            return false
        }

        return try {
            instance.javaClass.getMethod("start").invoke(instance)
            server = instance
            isRunning = true
            LogStore.add(
                "CommandServer فعال شد (command.sock آماده است)",
                levelHint = "info",
                tag = "core",
            )
            true
        } catch (t: Throwable) {
            Log.w(TAG, "CommandServer.start failed", t)
            LogStore.add(
                "خطای CommandServer.start: ${t.cause?.message ?: t.message}",
                levelHint = "error",
                tag = "core",
            )
            runCatching { instance.javaClass.getMethod("close").invoke(instance) }
            false
        }
    }

    /** باید بعد از Libbox.newService(...) صدا زده شود */
    fun attachService(boxService: Any) {
        val s = server ?: return
        val method = s.javaClass.methods.firstOrNull {
            it.name == "setService" && it.parameterTypes.size == 1
        }
        if (method == null) {
            Log.w(TAG, "setService not found on CommandServer")
            return
        }
        runCatching { method.invoke(s, boxService) }
            .onFailure { Log.w(TAG, "setService failed", it) }
    }

    fun resetLog() {
        val s = server ?: return
        runCatching { s.javaClass.getMethod("resetLog").invoke(s) }
    }

    @Synchronized
    fun stop() {
        val s = server
        server = null
        isRunning = false
        onServiceClose = null
        if (s == null) return
        runCatching { s.javaClass.getMethod("close").invoke(s) }
            .onFailure { Log.w(TAG, "CommandServer.close failed", it) }
    }

    // ---------- reflection helpers ----------

    private fun createServer(handler: Any): Any? {
        val libbox = runCatching { Class.forName(CLS_LIBBOX) }.getOrNull()
        val factory = libbox?.methods?.firstOrNull {
            it.name == "newCommandServer" &&
                it.parameterTypes.size == 2 &&
                it.parameterTypes[1] == Int::class.javaPrimitiveType
        }
        if (factory != null) {
            val created = runCatching { factory.invoke(null, handler, MAX_LOG_LINES) }
                .onFailure { Log.w(TAG, "newCommandServer failed", it) }
                .getOrNull()
            if (created != null) return created
        }

        // fallback: سازندهٔ مستقیم CommandServer(handler, maxLines)
        val serverClass = runCatching { Class.forName(CLS_SERVER) }.getOrNull() ?: return null
        val ctor = serverClass.constructors.firstOrNull {
            it.parameterTypes.size == 2 &&
                it.parameterTypes[1] == Int::class.javaPrimitiveType
        } ?: return null

        return runCatching { ctor.newInstance(handler, MAX_LOG_LINES) }
            .onFailure { Log.w(TAG, "CommandServer ctor failed", it) }
            .getOrNull()
    }

    private fun createHandler(): Any? {
        val handlerClass = runCatching { Class.forName(CLS_SERVER_HANDLER) }.getOrNull()
            ?: return null

        return Proxy.newProxyInstance(
            handlerClass.classLoader,
            arrayOf(handlerClass),
        ) { proxy, method, args ->
            handleCallback(proxy, method, args)
        }
    }

    private fun handleCallback(proxy: Any, method: Method, args: Array<out Any?>?): Any? {
        return when (method.name) {
            "getSystemProxyStatus" -> newSystemProxyStatus()

            "postServiceClose" -> {
                LogStore.add(
                    "درخواست بستن سرویس از سمت هسته",
                    levelHint = "info",
                    tag = "core",
                )
                runCatching { onServiceClose?.invoke() }
                null
            }

            "serviceReload" -> {
                LogStore.add("serviceReload درخواست شد", levelHint = "info", tag = "core")
                null
            }

            "setSystemProxyEnabled" -> null

            "toString" -> "CommandServerBridge.Handler"
            "hashCode" -> System.identityHashCode(proxy)
            "equals" -> proxy === args?.getOrNull(0)

            else -> defaultFor(method.returnType)
        }
    }

    private fun newSystemProxyStatus(): Any? {
        val cls = runCatching { Class.forName(CLS_PROXY_STATUS) }.getOrNull() ?: return null
        val instance = runCatching { cls.getDeclaredConstructor().newInstance() }.getOrNull()
            ?: return null
        runCatching {
            cls.methods.firstOrNull {
                it.name == "setAvailable" && it.parameterTypes.size == 1
            }?.invoke(instance, false)
        }
        runCatching {
            cls.methods.firstOrNull {
                it.name == "setEnabled" && it.parameterTypes.size == 1
            }?.invoke(instance, false)
        }
        return instance
    }

    private fun defaultFor(type: Class<*>): Any? = when (type) {
        Boolean::class.javaPrimitiveType -> false
        Int::class.javaPrimitiveType -> 0
        Long::class.javaPrimitiveType -> 0L
        Double::class.javaPrimitiveType -> 0.0
        Float::class.javaPrimitiveType -> 0f
        Short::class.javaPrimitiveType -> 0.toShort()
        Byte::class.javaPrimitiveType -> 0.toByte()
        Char::class.javaPrimitiveType -> ' '
        else -> null
    }
}
