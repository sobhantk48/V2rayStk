import re

file_path = 'lib/features/vpn/application/vpn_controller.dart'

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # الگوی پیدا کردن تابع قدیمی همراه با اون براکت‌ها و ریترن‌های اضافه
    pattern = re.compile(
        r'Future<Profile>\s*_resolveActiveProfile\(\)\s*async\s*\{.*?(?:throw\s+const\s+SingBoxConfigException\([^;]+;\s*\n?\s*\}\s*\n?\s*return\s+profiles\.firstWhere\([\s\S]*?;\s*\n?\s*\}|throw\s+const\s+SingBoxConfigException\([^;]+;\s*\n?\s*\})',
        re.DOTALL
    )

    # نسخه تمیز و جدید تابع
    new_function = """Future<Profile> _resolveActiveProfile() async {
    final List<Profile> profiles = await ref.read(profilesProvider.future);
    final adminReader = ref.read(adminSettingsReaderProvider);
    final adminSettings = await adminReader.read();

    if (profiles.isNotEmpty) {
      final active = profiles.where((p) => p.isActive).toList();
      return active.isNotEmpty ? active.first : profiles.first;
    }

    // اگر هیچ پروفایلی نبود ولی تور فعال بود، یک پروفایل مجازی تور می‌سازیم
    if (adminSettings.torEnabled) {
      return Profile(
        id: 'tor_standalone_auto',
        name: 'Tor Direct Network',
        type: ProfileType.socks,
        server: '127.0.0.1',
        port: 9050,
        isActive: true,
        rawConfig: 'socks5://127.0.0.1:9050',
        createdAt: DateTime.now(),
      );
    }

    throw const SingBoxConfigException('هیچ کانفیگی برای اتصال انتخاب نشده است. لطفاً یک کانفیگ اضافه کنید یا در پنل ادمین مسیریابی Tor را روشن کنید.');
  }"""

    if pattern.search(content):
        fixed_content = pattern.sub(new_function, content)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print("✅ تابع _resolveActiveProfile به طور کامل اصلاح و تمیز شد!")
    else:
        print("⚠️ تابع قدیمی پیدا نشد. شاید قبلاً تغییرات دیگه‌ای داده بودی.")

except Exception as e:
    print(f"❌ خطا در اجرای اسکریپت: {e}")
