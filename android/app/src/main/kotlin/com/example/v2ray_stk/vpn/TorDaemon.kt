package com.example.v2ray_stk.vpn

import android.content.Context
import android.util.Log
import java.io.File
import kotlin.concurrent.thread

class TorDaemon(private val context: Context) {
    private var torProcess: Process? = null
    private val TAG = "TorDaemon"

    fun start() {
        if (torProcess != null) {
            Log.d(TAG, "Tor daemon is already running.")
            return
        }

        thread {
            try {
                // Read binary from nativeLibraryDir to comply with Android W^X security
                val torBinary = File(context.applicationInfo.nativeLibraryDir, "libtor.so")
                
                if (!torBinary.exists()) {
                    Log.e(TAG, "❌ Tor binary (libtor.so) not found at ${torBinary.absolutePath}")
                    return@thread
                }

                val torrc = File(context.filesDir, "torrc")
                if (!torrc.exists()) {
                    torrc.writeText("""
                        SocksPort 9050
                        DataDirectory ${context.filesDir.absolutePath}/tordata
                        Log notice stdout
                    """.trimIndent())
                }

                val dataDir = File(context.filesDir, "tordata")
                if (!dataDir.exists()) dataDir.mkdirs()

                Log.d(TAG, "Starting Tor from native library dir: ${torBinary.absolutePath}")
                
                val pb = ProcessBuilder(torBinary.absolutePath, "-f", torrc.absolutePath)
                pb.directory(context.filesDir)
                pb.redirectErrorStream(true)
                torProcess = pb.start()

                Log.i(TAG, "✅ Tor daemon process started successfully!")

                // خوندن لاگ‌های Tor برای دیباگ بهتر
                torProcess?.inputStream?.bufferedReader()?.useLines { lines ->
                    lines.forEach { line ->
                        Log.d("TorLogs", line)
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to start Tor daemon", e)
            }
        }
    }

    fun stop() {
        try {
            torProcess?.destroy()
            torProcess = null
            Log.i(TAG, "🛑 Tor daemon stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping Tor daemon", e)
        }
    }
}
