import re

file_path = 'android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt'

with open(file_path, 'r') as f:
    content = f.read()

# 1. رفع مشکل nullability در tun.fd (جایگزینی tun.fd با tun.detachFd() یا استفاده از !!.fd)
# وقتی tun رو چک کردیم که null نیست، برای محکم کاری:
content = content.replace('tun.fd', 'tun!!.fd')

# 2. بررسی و ترمیم سینتکس establishTun در صورت به هم ریختگی براکت‌ها
# اگر قبلا کدی با براکت اشتباه تزریق شده باشه اینو اصلاح میکنیم.
# یه راه امن اینه که مطمئن بشیم سینتکس تابع برقراره:
content = re.sub(
    r'private fun establishTun\(\): ParcelFileDescriptor\? \{(.*?)\} \n\s*\}', 
    r'private fun establishTun(): ParcelFileDescriptor? {\1}', 
    content, 
    flags=re.DOTALL
)

with open(file_path, 'w') as f:
    f.write(content)

print("V2rayVpnService.kt patched successfully!")
