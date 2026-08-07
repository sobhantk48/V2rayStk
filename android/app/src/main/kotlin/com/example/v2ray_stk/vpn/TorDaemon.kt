package com.example.v2ray_stk.vpn

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import kotlin.concurrent.thread

object TorDaemon {
    private var torProcess: Process? = null
    private const val TAG = "TorDaemon"

    fun start(context: Context) {
        if (torProcess != null) {
            Log.i(TAG, "Tor is already running!")
            return
        }

        thread {
            try {
                val torBinary = File(context.filesDir, "tor")
                val torrc = File(context.filesDir, "torrc")
                val dataDir = File(context.filesDir, "tor_data")

                if (!dataDir.exists()) dataDir.mkdirs()

                // استخراج فایل از assets فلاتر به حافظه داخلی در صورت عدم وجود
                if (!torBinary.exists() || torBinary.length() == 0L) {
                    Log.i(TAG, "Extracting Tor binary...")
                    context.assets.open("flutter_assets/assets/bin/arm64-v8a/tor").use { input ->
                        FileOutputStream(torBinary).use { output ->
                            input.copyTo(output)
                        }
                    }
                    torBinary.setExecutable(true)
                }

                // ساخت کانفیگ اختصاصی برای Tor روی پورت 9050
                val torrcContent = """
                    SocksPort 9050
                    DataDirectory ${dataDir.absolutePath}
                    Log notice stdout
                """.trimIndent()
                torrc.writeText(torrcContent)

                // اجرای پروسه
                Log.i(TAG, "Starting Tor daemon...")
                val pb = ProcessBuilder(torBinary.absolutePath, "-f", torrc.absolutePath)
                pb.directory(context.filesDir)
                pb.redirectErrorStream(true)
                torProcess = pb.start()
                Log.i(TAG, "Tor daemon started successfully on port 9050 \uD83D\uDE80")

            } catch (e: Exception) {
                Log.e(TAG, "Failed to start Tor daemon \uD83D\uDE22", e)
            }
        }
    }

    fun stop() {
        try {
            torProcess?.destroy()
            torProcess = null
            Log.i(TAG, "Tor daemon stopped \uD83D\uDED1")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop Tor", e)
        }
    }
}
