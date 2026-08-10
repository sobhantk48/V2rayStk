#!/bin/bash
echo "===== 1) Dart: vpn_platform_service ====="
grep -n "killSwitch\|alwaysOn\|'connect'\|invokeMethod" lib/core/platform/vpn_platform_service.dart

echo; echo "===== 2) Dart: vpn_controller (_readVpnFlags) ====="
grep -n "killSwitch\|alwaysOn\|_readVpnFlags" lib/features/vpn/application/vpn_controller.dart

echo; echo "===== 3) Kotlin: MainActivity (دریافت از channel) ====="
grep -n "killSwitch\|alwaysOn\|EXTRA_KILL\|putExtra" android/app/src/main/kotlin/com/example/v2ray_stk/MainActivity.kt

echo; echo "===== 4) Kotlin: V2rayVpnService ====="
grep -n "EXTRA_KILL\|EXTRA_ALWAYS\|setBlocking\|onStartCommand\|intent ==\|intent?" android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt

echo; echo "===== 5) Manifest: سرویس VPN ====="
grep -n -A6 "V2rayVpnService" android/app/src/main/AndroidManifest.xml
