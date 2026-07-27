package com.example.v2ray_stk.vpn

/**
 * حلقهٔ لاگ درون‌حافظه‌ای.
 * هم snapshot می‌دهد (برای وقتی صفحهٔ لاگ باز می‌شود)
 * هم هر خط جدید را زنده به EventChannel پوش می‌کند.
 */
object LogStore {

    private const val MAX_LINES = 3000

    private val lock = Any()
    private val lines = ArrayDeque<Map<String, Any>>()
    private var seq = 0L

    @Volatile
    private var listener: ((Map<String, Any>) -> Unit)? = null

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
            runCatching { listener?.invoke(entry) }
        }
    }

    fun snapshot(): List<Map<String, Any>> = synchronized(lock) { lines.toList() }

    fun clear() {
        synchronized(lock) { lines.clear() }
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
