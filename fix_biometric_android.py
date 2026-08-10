#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""اصلاح پیش‌نیازهای اندرویدی قفل بیومتریک (local_auth) - نسخه امن و idempotent"""
import re, shutil, sys
from pathlib import Path

ROOT = Path.cwd()
if not (ROOT / "pubspec.yaml").exists():
    sys.exit("✗ اینجا ریشه پروژه فلاتر نیست. اول cd کن به پوشه‌ای که pubspec.yaml داره.")

changed = []

# ---------------------------------------------------------- 1) MainActivity.kt
mains = list(ROOT.glob("android/app/src/main/kotlin/**/MainActivity.kt"))
if not mains:
    print("✗ MainActivity.kt پیدا نشد")
else:
    p = mains[0]
    src = p.read_text(encoding="utf-8")
    orig = src
    src = src.replace(
        "import io.flutter.embedding.android.FlutterActivity",
        "import io.flutter.embedding.android.FlutterFragmentActivity",
    )
    src = re.sub(r"class\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)",
                 "class MainActivity : FlutterFragmentActivity()", src)
    if src != orig:
        shutil.copy2(p, p.with_suffix(".kt.bak"))
        p.write_text(src, encoding="utf-8")
        changed.append(f"{p} → FlutterFragmentActivity")
    else:
        if "FlutterFragmentActivity" in src:
            print("• MainActivity از قبل FlutterFragmentActivity است ✓")
        else:
            print("⚠ الگوی class MainActivity مطابقت نکرد؛ دستی چک کن.")

# ------------------------------------------------------- 2) AndroidManifest.xml
mf = ROOT / "android/app/src/main/AndroidManifest.xml"
if not mf.exists():
    print("✗ AndroidManifest.xml پیدا نشد")
else:
    xml = mf.read_text(encoding="utf-8")
    orig = xml
    perms = ["android.permission.USE_BIOMETRIC", "android.permission.USE_FINGERPRINT"]
    to_add = [x for x in perms if x not in xml]
    if to_add:
        block = "\n".join(
            f'    <uses-permission android:name="{x}" />' for x in to_add)
        m = re.search(r"<manifest\b[^>]*>", xml)
        if m:
            xml = xml[:m.end()] + "\n" + block + xml[m.end():]
    if xml != orig:
        shutil.copy2(mf, mf.with_suffix(".xml.bak"))
        mf.write_text(xml, encoding="utf-8")
        changed.append(f"{mf} → مجوزهای {', '.join(x.split('.')[-1] for x in to_add)}")
    else:
        print("• مجوزهای بیومتریک از قبل در منیفست هستند ✓")

    # گزارش وضعیت منیفست
    print("\n— گزارش منیفست —")
    for key in ["USE_BIOMETRIC", "USE_FINGERPRINT", "android:name=\".MainActivity\"",
                "com.example.v2ray_stk.MainActivity"]:
        print(f"  {'✓' if key in mf.read_text(encoding='utf-8') else '✗'} {key}")

# --------------------------------------------------------- 3) خروجی نهایی
print("\n=== تغییرات اعمال‌شده ===")
print("\n".join("  ✓ " + c for c in changed) if changed else "  (هیچ تغییری لازم نبود)")
print("\nنسخه پشتیبان‌ها با پسوند .bak ذخیره شدند.")
