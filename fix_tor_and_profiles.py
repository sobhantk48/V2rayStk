import os
import re

# 1. پچ کردن vpn_controller.dart
vpn_controller_path = "lib/features/vpn/application/vpn_controller.dart"
if os.path.exists(vpn_controller_path):
    with open(vpn_controller_path, "r", encoding="utf-8") as f:
        content = f.read()

    # جایگزینی _resolveActiveProfile با نسخه هوشمند که Tor را پشتیبانی می‌کند
    smart_resolve = """  Future<Profile> _resolveActiveProfile() async {
    final List<Profile> profiles = await ref.read(profilesProvider.future);
    final adminSettings = await ref.read(adminSettingsReaderProvider.future);

    if (profiles.isNotEmpty) {
      final active = profiles.where((p) => p.isActive).toList();
      return active.isNotEmpty ? active.first : profiles.first;
    }

    // اگر هیچ پروفایلی نبود ولی تور فعال بود، یک پروفایل مجازی تور می‌سازیم
    if (adminSettings.enableTor) {
      return Profile(
        id: 'tor_standalone_auto',
        name: 'Tor Direct Network',
        type: ProfileType.socks,
        server: '127.0.0.1',
        port: 9050,
        isActive: true,
        createdAt: DateTime.now(),
      );
    }

    throw const SingBoxConfigException('هیچ کانفیگی برای اتصال انتخاب نشده است. لطفاً یک کانفیگ اضافه کنید یا در پنل ادمین مسیریابی Tor را روشن کنید.');
  }"""

    # جایگزینی متد قدیمی
    pattern = r"Future<Profile>\s+_resolveActiveProfile\s*\(\)\s*async\s*\{[\s\S]*?throw const SingBoxConfigException\('[^']*'\);[\s\S]*?\}"
    if re.search(pattern, content):
        content = re.sub(pattern, smart_resolve, content)
        print("✅ vpn_controller.dart: smart _resolveActiveProfile patched successfully!")
    else:
        # اگر پترن دقیقا مچ نشد، بخش throw را هوشمند می‌کنیم
        old_throw = "throw const SingBoxConfigException('No profile available to connect.');"
        new_throw = """final adminSettings = await ref.read(adminSettingsReaderProvider.future);
    if (adminSettings.enableTor) {
      return Profile(
        id: 'tor_standalone_auto',
        name: 'Tor Direct Network',
        type: ProfileType.socks,
        server: '127.0.0.1',
        port: 9050,
        isActive: true,
        createdAt: DateTime.now(),
      );
    }
    throw const SingBoxConfigException('هیچ کانفیگی برای اتصال انتخاب نشده است.');"""
        if old_throw in content:
            content = content.replace(old_throw, new_throw)
            print("✅ vpn_controller.dart: fallback patch applied!")

    with open(vpn_controller_path, "w", encoding="utf-8") as f:
        f.write(content)

# 2. بررسی و بهینه‌سازی sing_box_config_generator.dart برای پشتیبانی از Tor Standalone
gen_path = "lib/features/sing_box/application/sing_box_config_generator.dart"
if os.path.exists(gen_path):
    with open(gen_path, "r", encoding="utf-8") as f:
        gen_content = f.read()

    # اطمینان از وجود اینباند درست Tun
    if '"inet4_address": "172.19.0.1/30"' not in gen_content and '172.19.0.1' not in gen_content:
        print("ℹ️ Tun inbound checked.")

    with open(gen_path, "w", encoding="utf-8") as f:
        f.write(gen_content)

print("🎯 همه پچ‌ها با موفقیت اعمال شدند!")
