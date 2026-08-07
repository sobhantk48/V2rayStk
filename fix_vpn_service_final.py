import os

file_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# ۱. اصلاح فاجعه‌ی سینتکس تابع establishTun
bad_signature = """    private fun establishTun()\n        TorDaemon.start(this): ParcelFileDescriptor? {"""
good_signature = """    private fun establishTun(): ParcelFileDescriptor? {"""
if bad_signature in content:
    content = content.replace(bad_signature, good_signature)
    print("✅ سینتکس establishTun با موفقیت تعمیر شد.")
else:
    print("⚠️ سینتکس establishTun پیدا نشد (شاید قبلاً درست شده).")

# ۲. تبدیل fd به detachFd() برای جلوگیری از کرش کردن JNI/Sing-box
if "tun!!.fd" in content:
    content = content.replace("tun!!.fd", "tun!!.detachFd()")
    print("✅ متغیر fd با موفقیت به detachFd() تغییر کرد.")

# ۳. مرتب‌سازی تو رفتگی (Indentation) فراخوانی TorDaemon
bad_start = """            val tun = establishTun()\n        TorDaemon.start(this)"""
good_start = """            val tun = establishTun()\n            TorDaemon.start(this)"""
content = content.replace(bad_start, good_start)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("🎉 فایل V2rayVpnService.kt کاملاً اصلاح شد!")
