import os

file_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/TorDaemon.kt"

with open(file_path, "r") as f:
    content = f.read()

# اضافه کردن ایمپورت‌های لازم برای سوکت
if "java.net.Socket" not in content:
    content = content.replace("import java.io.File", "import java.io.File\nimport java.net.Socket\nimport java.net.InetSocketAddress")

# پیدا کردن تابع start و اضافه کردن منطق صبر کردن
if "✅ Tor daemon process started successfully!" in content and "waitForPort" not in content:
    patch = """
            Log.i(TAG, "⏳ Waiting for Tor SOCKS port to open...")
            if (waitForPort(9050, 30)) {
                Log.i(TAG, "✅ Tor daemon process started successfully and port 9050 is ready!")
            } else {
                Log.e(TAG, "❌ Tor failed to open port 9050 in time!")
            }
"""
    content = content.replace("Log.i(TAG, \"✅ Tor daemon process started successfully!\")", patch)

# اضافه کردن تابع waitForPort به آخر کلاس
if "private fun waitForPort" not in content:
    wait_func = """

    private fun waitForPort(port: Int, maxRetries: Int): Boolean {
        for (i in 1..maxRetries) {
            try {
                val socket = Socket()
                socket.connect(InetSocketAddress("127.0.0.1", port), 1000)
                socket.close()
                return true
            } catch (e: Exception) {
                Thread.sleep(1000)
            }
        }
        return false
    }
}
"""
    # جایگزین کردن آخرین آکولاد کلاس با تابع جدید
    content = content.rsplit('}', 1)[0] + wait_func

with open(file_path, "w") as f:
    f.write(content)

print("✅ TorDaemon.kt patched successfully to wait for port 9050!")
