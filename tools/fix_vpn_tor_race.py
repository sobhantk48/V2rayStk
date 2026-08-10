import os

file_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add Socket and Thread imports if not exist
if "import java.net.Socket" not in content:
    content = content.replace("import android.util.Log", "import android.util.Log\nimport java.net.Socket\nimport kotlin.concurrent.thread")

# 2. Replace startVpn implementation
old_start_vpn = """        SingBoxBridge.start(this, fd, config)
        VpnState.update(VpnStatus.CONNECTED)

        startBridgeWatch()"""

new_start_vpn = """        // Wait for Tor port in background before starting Sing-box
        thread {
            Log.d(TAG, "Waiting for Tor port 9050 to be ready...")
            val torReady = waitForPort(9050, 15000) // 15 seconds timeout
            if (!torReady) {
                Log.e(TAG, "⚠️ Tor port 9050 not ready in time! Sing-box might fail to connect to Tor.")
            } else {
                Log.i(TAG, "✅ Tor port 9050 is open. Starting SingBoxBridge...")
            }

            Handler(Looper.getMainLooper()).post {
                try {
                    SingBoxBridge.start(this@V2rayVpnService, fd, config)
                    VpnState.update(VpnStatus.CONNECTED)
                    startBridgeWatch()
                } catch (e: Throwable) {
                    Log.e(TAG, "startVpn (SingBoxBridge) failed", e)
                    VpnState.update(VpnStatus.DISCONNECTED)
                    stopVpn()
                }
            }
        }"""

if "SingBoxBridge.start(this, fd, config)" in content:
    content = content.replace(old_start_vpn, new_start_vpn)

# 3. Add waitForPort function
wait_for_port_func = """
    private fun waitForPort(port: Int, timeoutMs: Long): Boolean {
        val startTime = System.currentTimeMillis()
        while (System.currentTimeMillis() - startTime < timeoutMs) {
            try {
                Socket("127.0.0.1", port).use {
                    return true
                }
            } catch (e: Exception) {
                Thread.sleep(500)
            }
        }
        return false
    }
"""
if "private fun waitForPort" not in content:
    # Insert it before the last closing brace
    content = content[:content.rfind('}')] + wait_for_port_func + "\n}\n"

# 4. Fix stopVpn for safe cleanup
old_stop_vpn = """        SingBoxBridge.stop()
        torDaemon?.stop()"""

new_stop_vpn = """        runCatching { SingBoxBridge.stop() }.onFailure { Log.e(TAG, "Error stopping SingBoxBridge", it) }
        runCatching { torDaemon?.stop() }.onFailure { Log.e(TAG, "Error stopping TorDaemon", it) }"""

if old_stop_vpn in content:
    content = content.replace(old_stop_vpn, new_stop_vpn)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("✅ V2rayVpnService.kt patched successfully! Race condition fixed.")
