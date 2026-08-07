import re

file_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

with open(file_path, "r") as f:
    content = f.read()

# ۱. درست کردن مشکل tun.fd و تبدیل به tun.detachFd() که امن‌تره و عدد اینتیجر می‌ده
content = content.replace("tun.fd", "tun.detachFd()")

# ۲. اگه آکولادی قبل از establishTun جا مونده یا سینتکسش خراب شده، یه چک بکنیم
# (خیلی وقت‌ها ارور without a body به خاطر جا افتادن = یا آکولاد بازه)
content = re.sub(r'private fun establishTun\(\): ParcelFileDescriptor\?\s*(?![\=\{])', 
                 'private fun establishTun(): ParcelFileDescriptor? {', content)

with open(file_path, "w") as f:
    f.write(content)

print("فایل V2rayVpnService.kt با موفقیت پچ شد! 🚀")
