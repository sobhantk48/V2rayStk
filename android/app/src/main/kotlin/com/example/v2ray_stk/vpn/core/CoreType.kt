package com.example.v2ray_stk.vpn.core

/**
 * نوع هسته‌ی VPN.
 * هر مقدار به یک AAR/کتابخانه‌ی بومی نگاشت می‌شود.
 */
enum class CoreType(val id: String, val displayName: String) {
    SING_BOX("sing_box", "sing-box"),
    XRAY("xray", "Xray");

    companion object {
        fun fromId(id: String?): CoreType =
            entries.firstOrNull { it.id == id } ?: SING_BOX
    }
}
