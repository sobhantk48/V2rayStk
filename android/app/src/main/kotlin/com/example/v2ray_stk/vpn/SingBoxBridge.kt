package com.example.v2ray_stk.vpn

import android.content.Context
import android.net.VpnService
import android.util.Log
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.Libbox
import java.io.File

/**
 * پل ارتباطی واقعی با هسته sing-box (libbox.aar).
 */
object SingBoxBridge {
    private const val TAG = "SingBoxBridge"

    const val isCoreAvailable: Boolean = true

    @Volatile
    private var boxService: BoxService? = null

    @Volatile
    private var currentTunFd: Int = -1

    private var setupDone = false

    @Synchronized
    fun start(vpnService: VpnService, tunFd: Int, config: String) {
        stopInternal()
        currentTunFd = tunFd
        ensureSetup(vpnService.applicationContext)

        val platform = BoxPlatformInterface(
            context = vpnService.applicationContext,
            tunFdProvider = { currentTunFd },
            protectFd = { fd -> runCatching { vpnService.protect(fd) }.getOrDefault(false) },
        )

        Log.d(TAG, "creating service, config length=${config.length}")
        val service = try {
            Libbox.newService(config, platform)
        } catch (e: Throwable) {
            Log.e(TAG, "newService failed", e)
            throw e
        }

        Log.d(TAG, "service created, starting...")
        try {
            service.start()
        } catch (e: Throwable) {
            Log.e(TAG, "service.start failed", e)
            runCatching { service.close() }
            throw e
        }

        boxService = service
        Log.d(TAG, "sing-box started")
    }

    @Synchronized
    fun stop() {
        stopInternal()
    }

    private fun stopInternal() {
        boxService?.let { svc ->
            runCatching { svc.close() }
                .onFailure { Log.w(TAG, "close failed", it) }
        }
        boxService = null
        currentTunFd = -1
    }

    /**
     * Libbox.setup در نسخه‌های مختلف امضای متفاوتی دارد؛
     * هر دو حالت را امتحان می‌کنیم.
     */
    private fun ensureSetup(context: Context) {
        if (setupDone) return

        val basePath = context.filesDir.absolutePath
        val workingPath = File(context.filesDir, "sing-box").apply { mkdirs() }.absolutePath
        val tempPath = context.cacheDir.absolutePath
        val libboxClass = Libbox::class.java

        // حالت ۱: setup(basePath, workingPath, tempPath, isTVOS)
        try {
            libboxClass.getMethod(
                "setup",
                String::class.java,
                String::class.java,
                String::class.java,
                Boolean::class.javaPrimitiveType,
            ).invoke(null, basePath, workingPath, tempPath, false)
            setupDone = true
            Log.d(TAG, "Libbox.setup(legacy) ok")
            return
        } catch (_: NoSuchMethodException) {
            // نسخه جدید است
        }

        // حالت ۲: setup(SetupOptions)
        val optionsClass = Class.forName("io.nekohasekai.libbox.SetupOptions")
        val options = optionsClass.getDeclaredConstructor().newInstance()
        optionsClass.getMethod("setBasePath", String::class.java).invoke(options, basePath)
        optionsClass.getMethod("setWorkingPath", String::class.java).invoke(options, workingPath)
        optionsClass.getMethod("setTempPath", String::class.java).invoke(options, tempPath)
        runCatching {
            optionsClass
                .getMethod("setFixAndroidStack", Boolean::class.javaPrimitiveType)
                .invoke(options, true)
        }
        libboxClass.getMethod("setup", optionsClass).invoke(null, options)
        setupDone = true
        Log.d(TAG, "Libbox.setup(options) ok")
    }
}
