import os
import shutil

vpn_service_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"
tor_daemon_path = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/TorDaemon.kt"

# 1. Fix V2rayVpnService.kt (Already closed issue)
with open(vpn_service_path, "r", encoding="utf-8") as f:
    vpn_code = f.read()

# Replace the double detachFd() with a single call
old_vpn_snippet = """
            tunInterface = tun
            Log.d(
                TAG,
                "tun established fd=${tun.detachFd()} mtu=$TUN_MTU addr=$TUN_ADDRESS/$TUN_PREFIX",
            )

            SingBoxBridge.start(this, tun.detachFd(), config)
"""

new_vpn_snippet = """
            tunInterface = tun
            val fd = tun.detachFd()
            Log.d(
                TAG,
                "tun established fd=$fd mtu=$TUN_MTU addr=$TUN_ADDRESS/$TUN_PREFIX",
            )

            SingBoxBridge.start(this, fd, config)
"""
if old_vpn_snippet.strip() in vpn_code:
    vpn_code = vpn_code.replace(old_vpn_snippet.strip(), new_vpn_snippet.strip())
    with open(vpn_service_path, "w", encoding="utf-8") as f:
        f.write(vpn_code)
    print("✅ V2rayVpnService.kt patched successfully.")
else:
    print("⚠️ Could not find the exact snippet in V2rayVpnService.kt. Maybe already patched?")


# 2. Fix TorDaemon.kt to use nativeLibraryDir
with open(tor_daemon_path, "r", encoding="utf-8") as f:
    tor_code = f.read()

old_tor_snippet = """
            val torBinary = File(context.filesDir, "tor")
            if (!torBinary.exists()) {
                context.assets.open("flutter_assets/assets/bin/arm64-v8a/tor").use { input ->
                    torBinary.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }
            torBinary.setExecutable(true)
"""

new_tor_snippet = """
            // In Android 10+, executing from filesDir is blocked by SELinux.
            // We must execute it from nativeLibraryDir where it's extracted as libtor.so
            val nativeLibraryDir = context.applicationInfo.nativeLibraryDir
            val torBinary = File(nativeLibraryDir, "libtor.so")
            
            if (!torBinary.exists() || !torBinary.canExecute()) {
                Log.e(TAG, "Tor binary not found or not executable at: ${torBinary.absolutePath}")
                return
            }
"""

if "val torBinary = File(context.filesDir, \"tor\")" in tor_code:
    # Basic replace to keep it simple
    tor_code = tor_code.replace(old_tor_snippet.strip(), new_tor_snippet.strip())
    with open(tor_daemon_path, "w", encoding="utf-8") as f:
        f.write(tor_code)
    print("✅ TorDaemon.kt patched successfully.")


# 3. Move Tor binary to jniLibs as libtor.so
asset_tor_path = "assets/bin/arm64-v8a/tor"
jni_libs_dir = "android/app/src/main/jniLibs/arm64-v8a"
os.makedirs(jni_libs_dir, exist_ok=True)

if os.path.exists(asset_tor_path):
    shutil.copy(asset_tor_path, os.path.join(jni_libs_dir, "libtor.so"))
    print("✅ Copied Tor binary to jniLibs/arm64-v8a/libtor.so")
else:
    print(f"⚠️ Could not find {asset_tor_path}. Make sure it exists.")

