#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AppLockGate را داخل builder اپ می‌نشاند و هلپر Haptics می‌سازد. idempotent است."""
import re, shutil, sys
from pathlib import Path

ROOT = Path.cwd()
if not (ROOT / "pubspec.yaml").exists():
    sys.exit("✗ اینجا ریشه پروژه فلاتر نیست.")

changed = []

# ---------------------------------------------------- 1) هلپر Haptics
hap = ROOT / "lib/core/platform/haptics.dart"
hap.parent.mkdir(parents=True, exist_ok=True)
hap.write_text('''import 'package:flutter/services.dart';

/// هلپر مرکزی بازخورد لمسی. با توجه به تنظیم کاربر لرزش می‌دهد.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }
}
''', encoding="utf-8")
changed.append(f"{hap} (ساخته/به‌روزرسانی شد)")

# ---------------------------------------------------- 2) app.dart: نشاندن AppLockGate
app = ROOT / "lib/app/app.dart"
src = app.read_text(encoding="utf-8")
orig = src

# 2a) import ها
imports_needed = [
    "import 'package:flutter/services.dart';",
    "import '../features/security/presentation/app_lock_gate.dart';",
    "import '../core/platform/haptics.dart';",
    "import '../features/settings/application/app_settings.dart';",
]
# پیدا کردن آخرین خط import برای درج پس از آن
lines = src.splitlines()
last_import = max(i for i, l in enumerate(lines) if l.strip().startswith("import "))
for imp in imports_needed:
    if imp not in src:
        lines.insert(last_import + 1, imp)
        last_import += 1
src = "\n".join(lines)

# 2b) هماهنگ‌سازی Haptics.enabled با تنظیمات (داخل build)
if "Haptics.enabled" not in src:
    # بعد از اولین خط build که ref در آن هست، یک watch اضافه می‌کنیم
    m = re.search(r"(Widget\s+build\s*\([^)]*\)\s*\{)", src)
    if m:
        inject = ("\n    final hapticOn = "
                  "ref.watch(appSettingsProvider).hapticEnabled;\n"
                  "    Haptics.enabled = hapticOn;\n")
        src = src[:m.end()] + inject + src[m.end():]

# 2c) پیچیدن builder دور AppLockGate
# حالت رایج: builder: (context, child) { return Directionality(...); }
# ما child نهایی که return می‌شود را داخل AppLockGate می‌پیچیم.
if "AppLockGate(" not in src:
    # الگوی return Directionality( ... child: child ... )
    # ساده‌ترین راه امن: هر «return Directionality(» داخل builder را
    # به return AppLockGate(child: Directionality( ... )) تبدیل کنیم.
    # برای اطمینان، فقط اگر دقیقا یک builder داریم عمل می‌کنیم.
    def wrap_directionality(text):
        idx = text.find("return Directionality(")
        if idx == -1:
            return text, False
        # پیدا کردن پرانتز متناظر بستن Directionality(...)
        start = text.find("(", idx)
        depth = 0
        i = start
        while i < len(text):
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        # i اکنون اندیس ) پایانی Directionality است
        inner = text[idx + len("return "):i + 1]  # Directionality(...)
        replacement = ("return AppLockGate(\n          child: "
                       + inner + ",\n        )")
        return text[:idx] + replacement + text[i + 1:], True

    src, ok = wrap_directionality(src)
    if not ok:
        print("⚠ الگوی 'return Directionality(' در builder پیدا نشد؛ "
              "app.dart را دستی چک کن (AppLockGate درج نشد).")

if src != orig:
    shutil.copy2(app, app.with_suffix(".dart.bak"))
    app.write_text(src, encoding="utf-8")
    changed.append(f"{app} (AppLockGate + Haptics.enabled)")
else:
    print("• app.dart از قبل هماهنگ بود.")

# ---------------------------------------------------- 3) settings: لرزش روی سوییچ‌ها
st = ROOT / "lib/features/settings/presentation/settings_screen.dart"
s = st.read_text(encoding="utf-8")
so = s
if "import '../../../core/platform/haptics.dart';" not in s:
    l = s.splitlines()
    li = max(i for i, x in enumerate(l) if x.strip().startswith("import "))
    l.insert(li + 1, "import '../../../core/platform/haptics.dart';")
    s = "\n".join(l)
# روی هر onChanged سوییچ setHaptic/setBiometricLock یک Haptics.selection اضافه کن
s = re.sub(r"(setHaptic\s*\(\s*v\s*\)\s*;?)", r"Haptics.enabled = v; Haptics.selection(); \1", s) \
    if "Haptics.selection(); setHaptic" not in s else s
s = re.sub(r"(setBiometricLock\s*\(\s*v\s*\)\s*;?)", r"Haptics.selection(); \1", s) \
    if "Haptics.selection(); setBiometricLock" not in s else s
if s != so:
    shutil.copy2(st, st.with_suffix(".dart.bak"))
    st.write_text(s, encoding="utf-8")
    changed.append(f"{st} (لرزش روی سوییچ‌ها)")

# ---------------------------------------------------- خروجی
print("\n=== تغییرات ===")
print("\n".join("  ✓ " + c for c in changed) if changed else "  (تغییری نبود)")
print("\nنسخه پشتیبان‌ها با .bak ذخیره شدند.")
