import re

path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Fix TorDaemon variable declaration
# Replace any incorrect torDaemon declaration with explicit type
content = re.sub(
    r'var\s+torDaemon\s*=\s*TorDaemon\(.*?\)',
    r'var torDaemon: TorDaemon? = null',
    content
)
content = re.sub(
    r'private\s+var\s+torDaemon\s*[:=].*?\n',
    r'private var torDaemon: TorDaemon? = null\n',
    content
)

# 2. Fix the initialization and start call
# Look for where Tor is started and replace it with proper safe calls
start_patch = """
        // Start Tor
        if (torDaemon == null) {
            torDaemon = TorDaemon(this)
        }
        torDaemon?.start()
"""
# Replace common faulty calls
content = re.sub(r'torDaemon\.start\(\)', r'torDaemon?.start()', content)
content = re.sub(r'torDaemon\?\.\?\.\.start\(\)', r'torDaemon?.start()', content)

# 3. Fix the stop call (and the type inference issue near it)
content = re.sub(r'torDaemon\.stop\(\)', r'torDaemon?.stop()', content)
content = re.sub(r'torDaemon\?\.\?\.\.stop\(\)', r'torDaemon?.stop()', content)

# Write back
with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("V2rayVpnService.kt patched for TorDaemon calls!")
