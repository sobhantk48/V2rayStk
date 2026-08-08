import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/tor_bridges.dart';
import 'package:flutter/material.dart';

// این استیت وضعیت دکمه تور رو نگه میداره (روشن/خاموش)
final torToggleProvider = StateNotifierProvider<TorToggleNotifier, bool>((ref) {
  return TorToggleNotifier(ref);
});

class TorToggleNotifier extends StateNotifier<bool> {
  final Ref ref;

  TorToggleNotifier(this.ref) : super(false);

  void toggleTor(bool isOn) {
    state = isOn;
    
    if (isOn) {
      // 1. دریافت پروفایل‌های هاردکد شده
      final torProfiles = TorBridges.getAllProfiles();
      
      // 2. اینجا باید پروفایل‌ها رو به لیست UI اضافه کنی
      // مثلاً اگر یه پروایدر برای لیست پروفایل‌ها داری:
      // ref.read(profileListProvider.notifier).addProfiles(torProfiles);
      
      debugPrint("✅ Tor profiles loaded: ${torProfiles.length}");

      // 3. انتخاب بهترین پروفایل (مثلا Snowflake) و شروع اتصال
      final bestProfile = torProfiles.last; // همون snowflake
      _startTorTunnel(bestProfile['config']!, bestProfile['type']!);
      
    } else {
      // پاک کردن پروفایل‌های تور از لیست و قطع اتصال
      debugPrint("🚫 Tor disconnected and profiles hidden.");
      // ref.read(profileListProvider.notifier).removeTorProfiles();
      _stopTorTunnel();
    }
  }

  void _startTorTunnel(String bridgeLine, String bridgeType) {
    // اینجا متد چنل (MethodChannel) یا فراخوانی libbox رو قرار میدیم
    // باید به Kotlin بگی که فایل torrc رو با این Bridge بسازه
    debugPrint("🚀 Starting Tunnel with Bridge: $bridgeLine");
    
    /* مثال برای فراخوانی نیتیو:
    MethodChannel('com.example.v2ray_stk/vpn').invokeMethod('startTor', {
      'bridge': bridgeLine,
      'type': bridgeType,
    });
    */
  }

  void _stopTorTunnel() {
    // قطع کردن اتصال
    /*
    MethodChannel('com.example.v2ray_stk/vpn').invokeMethod('stopTor');
    */
  }
}
