package com.example.v2ray_stk.vpn

import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference

/**
 * انبار آمار زنده. سرویس VPN مقادیر را می‌نویسد، MainActivity می‌خواند.
 * کلیدهای خروجی دقیقاً همان چیزی است که VpnStats.fromMap در Dart می‌خواند.
 */
object VpnStatsStore {

    private val downloadBps = AtomicLong(0L)
    private val uploadBps = AtomicLong(0L)
    private val totalDownload = AtomicLong(0L)
    private val totalUpload = AtomicLong(0L)
    private val pingMs = AtomicLong(-1L)
    private val location = AtomicReference<String?>(null)

    /** نرخ لحظه‌ای (بایت بر ثانیه) از هسته. */
    fun updateRates(downlink: Long, uplink: Long) {
        downloadBps.set(maxOf(0L, downlink))
        uploadBps.set(maxOf(0L, uplink))
    }

    /** مصرف تجمعی (بایت) از هسته. */
    fun updateTotals(downlinkTotal: Long, uplinkTotal: Long) {
        totalDownload.set(maxOf(0L, downlinkTotal))
        totalUpload.set(maxOf(0L, uplinkTotal))
    }

    fun updatePing(value: Long) {
        pingMs.set(value)
    }

    fun updateLocation(value: String?) {
        location.set(value)
    }

    /** با قطع اتصال صدا زده شود تا آمار قبلی روی UI نماند. */
    fun reset() {
        downloadBps.set(0L)
        uploadBps.set(0L)
        totalDownload.set(0L)
        totalUpload.set(0L)
        pingMs.set(-1L)
        location.set(null)
    }

    fun snapshot(): Map<String, Any?> {
        val ping = pingMs.get()
        return mapOf(
            "ping" to if (ping >= 0L) ping.toInt() else null,
            "downloadBps" to downloadBps.get(),
            "uploadBps" to uploadBps.get(),
            "totalDownload" to totalDownload.get(),
            "totalUpload" to totalUpload.get(),
            "location" to location.get(),
        )
    }
}
