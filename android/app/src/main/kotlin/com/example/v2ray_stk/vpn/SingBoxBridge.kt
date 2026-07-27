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
            protectFd = { fd -> runCatching { vpnService.protect(fd) }.getOrDefault(false) },
        )

        val version = runCatching { Libbox.version() }.getOrDefault("?")
        LogStore.add("libbox version = $version", levelHint = "info", tag = "core")

        runCatching { Libbox.checkConfig(config) }
            .onFailure {
                LogStore.add("checkConfig خطا: ${it.message}", levelHint = "error", tag = "core")
            }

        val service = Libbox.newService(config, platform)
        service.start()
        boxService = service

        Log.d(TAG, "sing-box started")
        LogStore.add("sing-box راه‌اندازی شد", levelHint = "info", tag = "core")
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
        LogStore.add("Libbox.setup انجام شد (base=$basePathValue)", levelHint = "info", tag = "core")
    }
}
