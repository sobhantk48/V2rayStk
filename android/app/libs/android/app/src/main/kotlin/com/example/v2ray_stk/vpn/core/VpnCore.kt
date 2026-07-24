package com.example.v2ray_stk.vpn.core

/** قرارداد مشترک بین هسته‌ها (sing-box و Xray). در هر لحظه فقط یک هسته فعال است. */
interface VpnCore {
    val type: CoreType

    /** اجرای هسته با کانفیگ داده‌شده. در صورت خطا Exception پرتاب می‌شود. */
    fun start(config: String)

    /** توقف هسته و آزادسازی منابع. */
    fun stop()

    /** آیا هسته در حال اجراست؟ */
    fun isRunning(): Boolean
}
