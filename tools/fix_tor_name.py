import os

file_path = 'lib/features/vpn/application/vpn_controller.dart'

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # جایگزینی کلمه‌ی اشتباه با درست
    if "adminSettings.enableTor" in content:
        fixed_content = content.replace("adminSettings.enableTor", "adminSettings.torEnabled")
        
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print("✅ متغیر enableTor با موفقیت به torEnabled تغییر یافت.")
    else:
        print("⚠️ عبارت adminSettings.enableTor پیدا نشد! شاید قبلاً درستش کردی؟")

except Exception as e:
    print(f"❌ یه خطایی پیش اومد: {e}")
