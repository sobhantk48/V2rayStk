package com.example.v2ray_stk.log

import android.os.Process
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * Exposes the application's own logcat output to Flutter.
 * Since Android 4.1 an app can only read its own log entries, so no
 * READ_LOGS permission is required and no other app's data is exposed.
 */
object LogChannel {

    private const val CHANNEL = "com.v2ray.stk/logs"
    private const val MAX_LINES = 4000

    /** Tags we care about when the caller asks for a filtered dump. */
    private val INTERESTING = listOf(
        "SingBoxBridge",
        "V2rayVpnService",
        "SingBoxCore",
        "libbox",
        "Libbox",
        "sing-box",
        "GoLog",
        "flutter",
        "AndroidRuntime",
        "DEBUG",
        "System.err"
    )

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dump" -> {
                        val onlyVpn = call.argument<Boolean>("onlyVpn") ?: false
                        try {
                            result.success(dump(onlyVpn))
                        } catch (e: Throwable) {
                            result.error("DUMP_FAILED", e.message, null)
                        }
                    }
                    "clear" -> {
                        try {
                            clear()
                            result.success(null)
                        } catch (e: Throwable) {
                            result.error("CLEAR_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun dump(onlyVpn: Boolean): List<String> {
        val pid = Process.myPid().toString()
        val lines = ArrayList<String>()

        val cmd = arrayListOf("logcat", "-d", "-v", "threadtime", "-t", MAX_LINES.toString())
        val process = ProcessBuilder(cmd)
            .redirectErrorStream(true)
            .start()

        BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
            var line: String? = reader.readLine()
            while (line != null) {
                val text = line
                val mine = text.contains(" $pid ") || text.contains("($pid)")
                val relevant = INTERESTING.any { text.contains(it, ignoreCase = true) }
                if (if (onlyVpn) relevant else (mine || relevant)) {
                    lines.add(text)
                }
                line = reader.readLine()
            }
        }
        process.waitFor()

        if (lines.isEmpty()) {
            lines.add("(logcat returned no matching lines — pid=$pid)")
        }
        return if (lines.size > MAX_LINES) lines.takeLast(MAX_LINES) else lines
    }

    private fun clear() {
        ProcessBuilder(listOf("logcat", "-c")).start().waitFor()
    }
}
