import os

file_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Force stop the service properly to kill the notification
new_stop_logic = """    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy: Cleaning up VpnService...")
        runCatching { SingBoxBridge.stop() }
        runCatching { torDaemon?.stop() }
        // Force the foreground service to stop
        stopForeground(true)
        stopSelf()
        Log.d(TAG, "onDestroy: VpnService killed.")
    }
"""

# Replace the existing stopVpn logic and ensure it calls stopSelf()
if "override fun onDestroy()" not in content:
    content = content.replace("override fun onStartCommand", new_stop_logic + "\n    override fun onStartCommand")

# 2. Add extra logging in the connect flow to see exactly WHERE it fails
# Find where it starts and add logs
debug_logs = """
                Log.d(TAG, "Attempting to start SingBoxBridge with config size: ${config.length}")
                SingBoxBridge.start(this@V2rayVpnService, fd, config)
                Log.d(TAG, "SingBoxBridge started successfully!")
"""
content = content.replace("SingBoxBridge.start(this@V2rayVpnService, fd, config)", debug_logs)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Cleanup logic and extra debug logs added!")
