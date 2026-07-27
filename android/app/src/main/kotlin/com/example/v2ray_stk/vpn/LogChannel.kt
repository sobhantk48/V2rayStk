package com.example.v2ray_stk.vpn

import android.os.Build
import android.os.Process
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

/**
 * خواندن لاگ‌های پروسه‌ی خود اپ از logcat و ارسال به Flutter.
 * روی اندروید ۴.۱+ هر اپ فقط لاگ خودش را می‌بیند، پس نیازی به root یا adb نیست.
 */
object LogChannel {

    private const val CHANNEL = "com.v2ray.stk/logs"

    private val interestingTags = listOf(
        "SingBoxBridge",
        "V2rayVpnService",
        "V2rayVpn",
        "BoxPlatformInterface",
        "libbox",
        "sing-box",
        "SingBoxCore",
        "MainActivity",
        "AndroidRuntime",
        "flutter",
        "v2ray_stk"
    )

    fun register(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "dump" -> result.success(dump())
                    "clear" -> {
                        clear()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun dump(): String {
        val builder = StringBuilder()

        // ۱) لاگ اصلی محدود به pid خودمان (اندروید ۷+)
        val pid = Process.myPid().toString()
        var main = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            exec(arrayOf("logcat", "-d", "-v", "time", "--pid", pid))
        } else {
            ""
        }

        // ۲) اگر --pid پشتیبانی نشد، کل بافر را می‌گیریم و با تگ فیلتر می‌کنیم
        if (main.isBlank()) {
            val all = exec(arrayOf("logcat", "-d", "-v", "time"))
            main = all.lineSequence()
                .filter { line -> interestingTags.any { line.contains(it, ignoreCase = true) } }
                .joinToString("\n")
        }

        if (main.isNotBlank()) {
            builder.append(main.trim())
        }

        // ۳) بافر crash برای گرفتن استک‌تریس کرش‌ها
        val crash = exec(arrayOf("logcat", "-d", "-b", "crash", "-v", "time"))
        if (crash.isNotBlank()) {
            builder.append("\n\n===== CRASH BUFFER =====\n")
            builder.append(crash.trim())
        }

        if (builder.isBlank()) {
            builder.append("لاگی یافت نشد. اگر خالی ماند، اپ را ری‌استارت کن و دوباره اتصال بزن.")
        }
        return builder.toString()
    }

    private fun clear() {
        exec(arrayOf("logcat", "-c"))
        exec(arrayOf("logcat", "-c", "-b", "crash"))
    }

    private fun exec(command: Array<String>): String {
        return try {
            val process = ProcessBuilder(*command)
                .redirectErrorStream(true)
                .start()
            val text = BufferedReader(InputStreamReader(process.inputStream)).use { it.readText() }
            process.waitFor()
            text
        } catch (t: Throwable) {
            ""
        }
    }
}
