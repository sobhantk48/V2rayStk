package com.example.v2ray_stk.vpn

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Structured core-log bridge to Flutter.
 *
 * Channels:
 *   EventChannel  "com.v2ray.stk/logs"       live stream; each event is a single
 *                                            Map with keys id/time/level/tag/message
 *   MethodChannel "com.v2ray.stk/log_store"  getLogs -> List<Map>, clearLogs -> Boolean
 *
 * Raw logcat is NOT handled here; see com.example.v2ray_stk.log.LogChannel
 * on channel "com.v2ray.stk/native_log".
 *
 * Two protections:
 *
 *  1) Batching. The core can emit hundreds of lines per second. Instead of one
 *     Handler.post per line (which floods the main-thread queue and causes
 *     jank or ANR), lines accumulate in a queue and a single runnable drains
 *     them. Each entry is still delivered via its own success() call so the
 *     Dart contract (one event == one Map) stays unchanged.
 *
 *  2) Stale-cancel guard. When the FlutterEngine is rebuilt (app killed while
 *     the VPN service keeps running) the old channel's onCancel may arrive
 *     AFTER the new channel's onListen. Each StreamHandler captures its own
 *     generation number; a cancel whose generation is no longer the active one
 *     is ignored, so it cannot tear down the fresh listener.
 */
object LogChannel {
    private const val EVENT_CHANNEL = "com.v2ray.stk/logs"
    private const val METHOD_CHANNEL = "com.v2ray.stk/log_store"

    /** Flush interval. Below this the UI does not feel any more "live". */
    private const val FLUSH_DELAY_MS = 80L

    /** Queue cap. If the UI falls behind, the oldest entries are dropped. */
    private const val MAX_PENDING = 2000

    private val mainHandler = Handler(Looper.getMainLooper())

    private val queueLock = Any()
    private val pending = ArrayDeque<Map<String, Any>>()
    private var flushScheduled = false

    /** Incremented per registerEventChannel; captured by each StreamHandler. */
    private val generationLock = Any()
    private var generationCounter = 0L

    @Volatile
    private var activeGeneration = 0L

    @Volatile
    private var eventChannel: EventChannel? = null

    @Volatile
    private var methodChannel: MethodChannel? = null

    @Volatile
    private var sink: EventChannel.EventSink? = null

    private val flushRunnable = Runnable { flush() }

    fun register(engine: FlutterEngine) {
        // A previous engine may have been destroyed without cancelling. Drop the
        // stale handlers so two channels never fight over this singleton.
        detachChannels()
        registerEventChannel(engine)
        registerMethodChannel(engine)
    }

    private fun registerEventChannel(engine: FlutterEngine) {
        val generation = nextGeneration()
        val channel = EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        channel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (events == null) return
                clearQueue()
                sink = events
                activeGeneration = generation
                // Live tail only. The initial buffer is fetched through getLogs,
                // otherwise Flutter would show duplicated entries.
                LogStore.setListener { entry -> enqueue(entry) }
            }

            override fun onCancel(arguments: Any?) {
                // Ignore a late cancel from an engine that is already replaced.
                if (activeGeneration != generation) return
                LogStore.setListener(null)
                sink = null
                clearQueue()
            }
        })
        eventChannel = channel
    }

    private fun registerMethodChannel(engine: FlutterEngine) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLogs" -> {
                    try {
                        result.success(LogStore.snapshot())
                    } catch (error: Throwable) {
                        result.error("LOG_SNAPSHOT_FAILED", error.message, null)
                    }
                }

                "clearLogs" -> {
                    try {
                        LogStore.clear()
                        clearQueue()
                        result.success(true)
                    } catch (error: Throwable) {
                        result.error("LOG_CLEAR_FAILED", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
        methodChannel = channel
    }

    private fun nextGeneration(): Long = synchronized(generationLock) {
        generationCounter += 1
        generationCounter
    }

    /**
     * Called from the core thread. Does no real work: enqueue and make sure a
     * flush is scheduled.
     */
    private fun enqueue(entry: Map<String, Any>) {
        if (sink == null) return

        val needsSchedule: Boolean
        synchronized(queueLock) {
            pending.addLast(entry)
            while (pending.size > MAX_PENDING) pending.removeFirst()
            needsSchedule = !flushScheduled
            if (needsSchedule) flushScheduled = true
        }

        if (needsSchedule) {
            mainHandler.postDelayed(flushRunnable, FLUSH_DELAY_MS)
        }
    }

    /** Runs on the main thread; EventSink is only safe from there. */
    private fun flush() {
        val batch: List<Map<String, Any>>
        synchronized(queueLock) {
            flushScheduled = false
            if (pending.isEmpty()) return
            batch = pending.toList()
            pending.clear()
        }

        val target = sink ?: return
        for (entry in batch) {
            try {
                target.success(entry)
            } catch (_: Throwable) {
                // Engine is tearing down; the rest of the batch is pointless.
                return
            }
        }
    }

    private fun clearQueue() {
        mainHandler.removeCallbacks(flushRunnable)
        synchronized(queueLock) {
            pending.clear()
            flushScheduled = false
        }
    }

    private fun detachChannels() {
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
    }

    /**
     * Explicit teardown. Do NOT wire this into Activity lifecycle callbacks:
     * cleanUpFlutterEngine of an old Activity can run after the new Activity
     * already registered, and an unconditional dispose would kill the fresh
     * live log. register() already detaches stale handlers.
     */
    fun dispose() {
        LogStore.setListener(null)
        sink = null
        activeGeneration = 0L
        clearQueue()
        detachChannels()
    }
}
