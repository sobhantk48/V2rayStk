#!/usr/bin/env python3
"""ماندگار کردن لاگ‌های structured روی دیسک (NDJSON چرخشی)."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
K = os.path.join(ROOT, "android", "app", "src", "main", "kotlin", "com", "example", "v2ray_stk")

LOG_STORE = os.path.join(K, "vpn", "LogStore.kt")
SERVICE = os.path.join(K, "vpn", "V2rayVpnService.kt")
ACTIVITY = os.path.join(K, "MainActivity.kt")

LOG_STORE_SRC = r'''package com.example.v2ray_stk.vpn

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File
import java.util.concurrent.LinkedBlockingQueue

/**
 * حلقهٔ لاگ درون‌حافظه‌ای + ماندگاری روی دیسک.
 *
 *  - snapshot()    برای وقتی صفحهٔ لاگ باز می‌شود
 *  - setListener() برای پوش زندهٔ هر خط به EventChannel
 *  - init(context) یک بار در onCreate سرویس و در configureFlutterEngine صدا زده
 *                  می‌شود؛ لاگ سشن‌های قبلی را برمی‌گرداند و خطوط تازه را در
 *                  پس‌زمینه روی دیسک می‌نویسد.
 *
 * قالب فایل NDJSON است: هر خط یک JSON object با کلیدهای
 * id / time / level / tag / message
 *
 *   files/logs/core.ndjson     فایل جاری
 *   files/logs/core.ndjson.1   نسخهٔ چرخش‌یافته (فقط یکی نگه داشته می‌شود)
 *
 * نوشتن روی thread هستهٔ sing-box انجام نمی‌شود؛ صف می‌شود و یک thread
 * daemon با اولویت پایین آن را batch می‌نویسد.
 */
object LogStore {

    private const val MAX_LINES = 3000

    /** سقف حجم فایل جاری، بعد از آن چرخش انجام می‌شود */
    private const val MAX_FILE_BYTES = 512L * 1024L

    /** سقف صف نوشتن؛ اگر دیسک عقب بیفتد خط تازه دور ریخته می‌شود */
    private const val MAX_QUEUE = 8000

    private const val DIR_NAME = "logs"
    private const val FILE_NAME = "core.ndjson"
    private const val ROTATED_NAME = "core.ndjson.1"
    private const val TAG = "LogStore"

    private val lock = Any()
    private val lines = ArrayDeque<Map<String, Any>>()
    private var seq = 0L

    @Volatile
    private var listener: ((Map<String, Any>) -> Unit)? = null

    // ------------------------------------------------------------------
    // persistence
    // ------------------------------------------------------------------

    /** قفل تمام عملیات فایل: نوشتن، چرخش، پاک کردن، بازخوانی */
    private val fileLock = Any()

    private val initLock = Any()

    @Volatile
    private var logDir: File? = null

    @Volatile
    private var initialized = false

    private val writeQueue = LinkedBlockingQueue<Map<String, Any>>()

    private var writerThread: Thread? = null

    /**
     * idempotent است؛ چند بار صدا زدنش بی‌خطر است.
     * هم از V2rayVpnService.onCreate و هم از MainActivity فراخوانی می‌شود.
     */
    fun init(context: Context) {
        synchronized(initLock) {
            if (initialized) return
            val dir = File(context.filesDir, DIR_NAME)
            if (!dir.isDirectory) {
                runCatching { dir.mkdirs() }
            }
            logDir = dir
            initialized = true
            startWriter()
        }
        restore()
        add("──── session start ────", "info", "app")
    }

    fun setListener(l: ((Map<String, Any>) -> Unit)?) {
        listener = l
    }

    fun add(message: String?, levelHint: String? = null, tag: String = "core") {
        val raw = message ?: return
        if (raw.isBlank()) return

        for (part in raw.split('\n')) {
            val text = part.trim()
            if (text.isEmpty()) continue

            var entry: Map<String, Any>
            synchronized(lock) {
                seq += 1
                entry = mapOf(
                    "id" to seq,
                    "time" to System.currentTimeMillis(),
                    "level" to (levelHint ?: detectLevel(text)),
                    "tag" to tag,
                    "message" to text
                )
                lines.addLast(entry)
                while (lines.size > MAX_LINES) lines.removeFirst()
            }
            if (initialized && writeQueue.size < MAX_QUEUE) {
                runCatching { writeQueue.offer(entry) }
            }
            runCatching { listener?.invoke(entry) }
        }
    }

    fun snapshot(): List<Map<String, Any>> = synchronized(lock) { lines.toList() }

    fun clear() {
        synchronized(lock) { lines.clear() }
        writeQueue.clear()
        val dir = logDir ?: return
        synchronized(fileLock) {
            runCatching { File(dir, FILE_NAME).delete() }
            runCatching { File(dir, ROTATED_NAME).delete() }
        }
    }

    // ------------------------------------------------------------------
    // writer
    // ------------------------------------------------------------------

    /** فقط داخل initLock صدا زده می‌شود */
    private fun startWriter() {
        if (writerThread != null) return
        val thread = Thread({
            val batch = ArrayList<Map<String, Any>>(64)
            while (true) {
                try {
                    batch.add(writeQueue.take())
                } catch (_: InterruptedException) {
                    break
                }
                writeQueue.drainTo(batch, 256)
                appendToDisk(batch)
                batch.clear()
            }
        }, "log-store-writer")
        thread.isDaemon = true
        runCatching { thread.priority = Thread.MIN_PRIORITY }
        writerThread = thread
        runCatching { thread.start() }
    }

    private fun appendToDisk(batch: List<Map<String, Any>>) {
        if (batch.isEmpty()) return
        val dir = logDir ?: return
        synchronized(fileLock) {
            try {
                val file = File(dir, FILE_NAME)
                if (file.length() >= MAX_FILE_BYTES) rotateLocked(dir)

                val buffer = StringBuilder()
                for (entry in batch) {
                    val json = toJson(entry)
                    if (json.isEmpty()) continue
                    buffer.append(json).append('\n')
                }
                if (buffer.isNotEmpty()) file.appendText(buffer.toString())
            } catch (error: Throwable) {
                Log.w(TAG, "نوشتن لاگ روی دیسک ناموفق: " + error.message)
            }
        }
    }

    /** فقط داخل fileLock صدا زده می‌شود */
    private fun rotateLocked(dir: File) {
        val current = File(dir, FILE_NAME)
        val rotated = File(dir, ROTATED_NAME)
        runCatching { if (rotated.exists()) rotated.delete() }
        val moved = runCatching { current.renameTo(rotated) }.getOrDefault(false)
        if (!moved) runCatching { current.delete() }
    }

    // ------------------------------------------------------------------
    // restore
    // ------------------------------------------------------------------

    private fun restore() {
        val dir = logDir ?: return
        val restored = ArrayList<Map<String, Any>>()

        synchronized(fileLock) {
            for (name in listOf(ROTATED_NAME, FILE_NAME)) {
                val file = File(dir, name)
                if (!file.isFile) continue
                try {
                    file.forEachLine { rawLine ->
                        val text = rawLine.trim()
                        if (text.isNotEmpty()) {
                            parseEntry(text)?.let { restored.add(it) }
                        }
                    }
                } catch (error: Throwable) {
                    Log.w(TAG, "بازخوانی " + name + " ناموفق: " + error.message)
                }
            }
        }

        if (restored.isEmpty()) return

        synchronized(lock) {
            // خطوط بازیابی‌شده باید قبل از خطوط زندهٔ همین سشن بیایند
            val live = lines.toList()
            lines.clear()

            var maxId = seq
            for (entry in restored) {
                lines.addLast(entry)
                val id = entry["id"] as? Long ?: 0L
                if (id > maxId) maxId = id
            }
            for (entry in live) lines.addLast(entry)
            while (lines.size > MAX_LINES) lines.removeFirst()

            // id تازه باید بالاتر از هرچه روی دیسک بوده شروع شود
            seq = maxId
        }
    }

    private fun toJson(entry: Map<String, Any>): String =
        runCatching { JSONObject(entry).toString() }.getOrDefault("")

    private fun parseEntry(line: String): Map<String, Any>? {
        return try {
            val json = JSONObject(line)
            val message = json.optString("message", "")
            if (message.isBlank()) return null

            val level = json.optString("level", "info")
            val tag = json.optString("tag", "core")
            mapOf(
                "id" to json.optLong("id", 0L),
                "time" to json.optLong("time", 0L),
                "level" to (if (level.isBlank()) "info" else level),
                "tag" to (if (tag.isBlank()) "core" else tag),
                "message" to message
            )
        } catch (_: Throwable) {
            null
        }
    }

    /** سطح لاگ را از متن خام sing-box حدس می‌زند */
    private fun detectLevel(text: String): String {
        val t = text.lowercase()
        return when {
            t.contains("panic") || t.contains("fatal") -> "fatal"
            t.contains("error") || t.contains(" err ") -> "error"
            t.contains("warn") -> "warn"
            t.contains("debug") -> "debug"
            t.contains("trace") -> "trace"
            else -> "info"
        }
    }
}
'''

ON_CREATE = """    override fun onCreate() {
        super.onCreate()
        // لاگ‌ها باید قبل از هر خط هسته روی دیسک آماده باشند
        runCatching { LogStore.init(applicationContext) }
    }

"""

INIT_LINE = "        runCatching { com.example.v2ray_stk.vpn.LogStore.init(applicationContext) }\n"


def read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def check(path):
    if not os.path.isfile(path):
        print("[x] پیدا نشد: " + path)
        sys.exit(1)


def patch_service():
    src = read(SERVICE)
    if "override fun onCreate()" in src:
        print("[=] V2rayVpnService: onCreate از قبل هست، رد شد")
        return
    anchor = "    override fun onStartCommand("
    if anchor not in src:
        print("[x] V2rayVpnService: onStartCommand پیدا نشد")
        sys.exit(1)
    src = src.replace(anchor, ON_CREATE + anchor, 1)
    write(SERVICE, src)
    print("[+] V2rayVpnService: onCreate + LogStore.init افزوده شد")


def patch_activity():
    src = read(ACTIVITY)
    if "LogStore.init(" in src:
        print("[=] MainActivity: LogStore.init از قبل هست، رد شد")
        return
    anchor = "        super.configureFlutterEngine(flutterEngine)\n"
    if anchor not in src:
        print("[x] MainActivity: super.configureFlutterEngine پیدا نشد")
        sys.exit(1)
    src = src.replace(anchor, anchor + INIT_LINE, 1)
    write(ACTIVITY, src)
    print("[+] MainActivity: LogStore.init افزوده شد")


def main():
    for path in (LOG_STORE, SERVICE, ACTIVITY):
        check(path)

    write(LOG_STORE, LOG_STORE_SRC)
    print("[+] LogStore.kt بازنویسی شد (NDJSON چرخشی + init/restore)")

    patch_service()
    patch_activity()
    print("\nتمام شد. حالا سورس را کامیت و پوش کن تا Actions بیلد بگیرد.")


if __name__ == "__main__":
    main()
