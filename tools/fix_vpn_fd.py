import os

file_path = 'android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt'

with open(file_path, 'r') as f:
    content = f.read()

fixed_content = content.replace("tun!!.fd", "tun!!.detachFd()")

with open(file_path, 'w') as f:
    f.write(fixed_content)

print("فایل V2rayVpnService با موفقیت اصلاح شد.")
