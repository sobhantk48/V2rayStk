package com.example.v2ray_stk.vpn

import android.content.Context
import android.net.VpnService
import android.util.Log
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import java.io.File

object SingBoxBridge {

    private const val TAG = "SingBoxBridge"

    const val isCoreAvailable: Boolean = true

    @Volatile
    private var boxService: BoxService? = null

    @Volatile
    private var currentTunFd: Int = -1

    @Volatile
    private var setupDone: Boolean = false

    @Synchronized
    fun start(vpnService: VpnService, tunFd: Int, config: String) {
        stopInternal()
        currentTunFd = tunFd

        val context = vpnService.applicationContext
        ensureSetup(context)

        val platform = BoxPlatformInterface(
            context = context,
            tunFdProvider = { currentTunFd },
            protectFd = { fd ->
                val ok = runCatching { vpnService.protect(fd) }.getOrDefault(false)
                ok
            },
        )

        LogStore.append("core", "libbox version = ${runCatching { Libbox.version() }.getOrDefault("?")}")

        runCatching { Libbox.checkConfig(config) }
            .onFailure { LogStore.append("core", "checkConfig خطا: ${it.message}") }

        val service = Libbox.newService(config, platform)
        service.start()
        boxService = service

        Log.d(TAG, "sing-box started")
        LogStore.append("core", "sing-box راه‌اندازی شد")
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

    private fun ensureSetup(context: Context) {
        if (setupDone) return

        val basePathValue = context.filesDir.absolutePath
        val workingPathValue = File(context.filesDir, "sing-box").apply { mkdirs() }.absolutePath
        val tempPathValue = context.cacheDir.absolutePath

        val options = SetupOptions()
        options.setBasePath(basePathValue)
        options.setWorkingPath(workingPathValue)
        options.setTempPath(tempPathValue)
        options.setFixAndroidStack(true)

        Libbox.setup(options)
        setupDone = true
        LogStore.append("core", "Libbox.setup انجام شد (base=$basePathValue)")
    }
}
