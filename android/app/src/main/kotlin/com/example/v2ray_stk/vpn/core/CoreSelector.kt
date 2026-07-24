package com.example.v2ray_stk.vpn.core

/**
 * انتخاب‌گر هسته.
 * دو حالت دارد:
 *  1) MANUAL: کاربر هسته را انتخاب کرده است.
 *  2) AUTO: بر اساس تست تأخیر، هسته‌ی بهتر انتخاب می‌شود.
 *
 * نکته‌ی سیستم‌عاملی: در لحظه‌ی اتصال فقط یک هسته می‌تواند
 * tun را در اختیار بگیرد. این کلاس فقط «انتخاب» می‌کند،
 * اجرای همزمانِ دو تونل انجام نمی‌دهد.
 */
class CoreSelector(
    private val cores: Map<CoreType, VpnCore>
) {

    fun byType(type: CoreType): VpnCore =
        cores[type] ?: throw VpnCoreException("هسته‌ی $type ثبت نشده است")

    /**
     * انتخاب خودکار بر اساس کمترین تأخیر.
     * هر هسته به‌ترتیب و جداگانه تست می‌شود (نه همزمان با tun).
     * اگر هیچ هسته‌ای پاسخ ندهد، به sing-box برمی‌گردد.
     */
    fun selectBest(configByCore: Map<CoreType, String>): VpnCore {
        var best: VpnCore? = null
        var bestLatency = Long.MAX_VALUE

        for ((type, core) in cores) {
            val cfg = configByCore[type] ?: continue
            val latency = runCatching { core.testLatency(cfg) }.getOrDefault(-1L)
            if (latency in 0 until bestLatency) {
                bestLatency = latency
                best = core
            }
        }

        return best ?: byType(CoreType.SING_BOX)
    }
}
