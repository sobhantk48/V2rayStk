import re
path = "android/app/src/main/AndroidManifest.xml"
with open(path, "r") as f:
    data = f.read()

if 'extractNativeLibs' not in data:
    # اضافه کردن extractNativeLibs به تگ application
    data = re.sub(r'(<application\b)', r'\1 android:extractNativeLibs="true"', data)
    with open(path, "w") as f:
        f.write(data)
    print("✅ AndroidManifest.xml با موفقیت ویرایش شد!")
else:
    print("⚡ این تنظیم قبلا اضافه شده بود.")
