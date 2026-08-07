import re
import os

file_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. درست کردن سینتکس خراب تابع establishTun
content = content.replace(
    "private fun establishTun()\n    TorDaemon.start(this): ParcelFileDescriptor? {",
    "private fun establishTun(): ParcelFileDescriptor? {\n        TorDaemon.start(this)"
)
content = content.replace(
    "private fun establishTun() TorDaemon.start(this): ParcelFileDescriptor? {",
    "private fun establishTun(): ParcelFileDescriptor? {\n        TorDaemon.start(this)"
)

# 2. حل مشکل tun!!.fd و استفاده از detachFd() برای سینگ‌باکس
# اولی که تو لاگ هست رو به همون فرمت استرینگ امن تغییر میدیم
content = content.replace("tun!!.fd", "tun.detachFd()")

# برای احتیاط اگر tun.fd خالی هم مونده بود:
content = content.replace("tun.fd", "tun.detachFd()")

# 3. جابجایی TorDaemon از خط 111 (اگر اشتباهی اونجا افتاده)
content = content.replace("val tun = establishTun()\nTorDaemon.start(this)", "val tun = establishTun()")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ فایل V2rayVpnService.kt با موفقیت جراحی شد! حالا پوش کن تو گیت‌هاب اکشنز.")
