package com.v2raystk.app

import android.content.Context
import java.io.File

class TorManager(private val context: Context) {
    private var process: Process? = null
    fun start(): Int {
        if (process?.isAlive == true) return 9050
        val binary = File(context.applicationInfo.nativeLibraryDir, "libtor.so")
        require(binary.exists()) { "Tor binary is not packaged for this ABI" }
        val data = File(context.filesDir, "tor").apply { mkdirs() }
        process = ProcessBuilder(binary.absolutePath, "--SocksPort", "9050", "--DataDirectory", data.absolutePath)
            .redirectErrorStream(true).start()
        return 9050
    }
    fun stop() { process?.destroy(); process = null }
}
