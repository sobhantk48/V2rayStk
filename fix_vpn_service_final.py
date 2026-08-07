path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. اضافه کردن متغیر torDaemon به کلاس V2rayVpnService
if "private var torDaemon: TorDaemon?" not in content:
    content = content.replace(
        "class V2rayVpnService : VpnService() {",
        "class V2rayVpnService : VpnService() {\n    private var torDaemon: TorDaemon? = null"
    )

# 2. اصلاح TorDaemon.start(this)
content = content.replace(
    "TorDaemon.start(this)",
    "torDaemon = TorDaemon(this@V2rayVpnService)\n            torDaemon?.start()"
)

# 3. اصلاح TorDaemon.stop()
content = content.replace(
    "TorDaemon.stop()",
    "torDaemon?.stop()"
)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("V2rayVpnService.kt successfully patched!")
