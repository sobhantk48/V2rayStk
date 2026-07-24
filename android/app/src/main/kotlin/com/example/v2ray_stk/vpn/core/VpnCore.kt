package com.example.v2ray_stk.vpn.core

/**
 * قرارداد مشترک هر هسته‌ی VPN.
 * هر هسته (sing-box، Xray) این interface را پیاده‌سازی می‌کند تا
 * سرویس بالادست بدون آگاهی از جزئیات AAR با آن کار کند.
 */
interface VpnCore {

    /** نوع این هسته. */
    val type: CoreType

    /** آیا هسته هم‌اکنون تونل فعال دارد. */
    val isRunning: Boolean

    /**
     * راه‌اندازی تونل با کانفیگ داده‌شده.
     * @param configJson کانفیگ نهایی به‌صورت JSON (سازگار با همان هسته).
     * @param tunFd فایل‌دیسکریپتور tun که VpnService.Builder ساخته است.
     * @throws VpnCoreException در صورت شکست راه‌اندازی.
     */
    fun start(configJson: String, tunFd: Int)

    /** توقف تونل و آزادسازی منابع بومی. */
    fun stop()

    /**
     * تست تأخیر بدون گرفتن tun اصلی.
     * برای «انتخاب بهترین هسته» قبل از اتصال استفاده می‌شود.
     * @return تأخیر بر حسب میلی‌ثانیه، یا مقدار منفی در صورت شکست.
     */
    fun testLatency(configJson: String): Long
}

/** خطای عمومی هسته‌ها. */
class VpnCoreException(message: String, cause: Throwable? = null) :
    Exception(message, cause)
