package com.example.v2ray_stk.log

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * پل ارتباطی خواندن logcat و ارسال آن به Flutter.
 *
 * قرارداد کانال:
 *  - dump(onlyVpn: Boolean?) -> String   (خطوط با \n جدا شده)
 *  - clear()                 -> Boolean
 */
object LogChannel {

    private const val CHANNEL = "com.v2ray.stk/native_log"
    private const val MAX_LINES = 2000

    /** فقط لاگ‌های مرتبط با هسته و VPN */
    private val VPN_KEYWORDS = listOf(
        "V2rayVpnService",
        "SingBox",
        "SingBoxBridge",
        "libbox",
        "VpnCore",
        "CoreSelector",
        "v2ray_stk",
        "tun",
    )

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dump" -> {
                        val onlyVpn = when (val arg = call.argument<Any?>("onlyVpn")) {
                            is Boolean -> arg
                            is String -> arg.toBoolean()
                            else -> false
                        }
                        try {
                            // خروجی به صورت یک رشته‌ی یکپارچه برگردانده می‌شود
                            result.success(dump(onlyVpn))
                        } catch (error: Throwable) {
                            result.error("LOG_DUMP_FAILED", error.message, null)
                        }
                    }

                    "clear" -> {
                        try {
                            clear()
                            result.success(true)
                        } catch (error: Throwable) {
                            result.error("LOG_CLEAR_FAILED", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun dump(onlyVpn: Boolean): String {
        val lines = readLogcat()
        val filtered = if (onlyVpn) {
            lines.filter { line -> VPN_KEYWORDS.any { line.contains(it, ignoreCase = true) } }
        } else {
            lines
        }

        val trimmed = if (filtered.size > MAX_LINES) {
            filtered.subList(filtered.size - MAX_LINES, filtered.size)
        } else {
            filtered
        }

        return if (trimmed.isEmpty()) "" else trimmed.joinToString("\n")
    }

    private fun readLogcat(): List<String> {
        val output = mutableListOf<String>()
        var process: Process? = null

        try {
            process = ProcessBuilder("logcat", "-d", "-v", "time")
                .redirectErrorStream(true)
                .start()

            BufferedReader(InputStreamReader(process.inputStream)).use { reader ->
                while (true) {
                    val line = reader.readLine() ?: break
                    if (line.isNotBlank()) {
                        output.add(line)
                    }
                }
            }

            process.waitFor()
        } finally {
            process?.destroy()
        }

        return output
    }

    private fun clear() {
        var process: Process? = null
        try {
            process = ProcessBuilder("logcat", "-c").start()
            process.waitFor()
        } finally {
            process?.destroy()
        }
    }
}
