#!/usr/bin/env python3
import os, re, io

def read(p):
    with io.open(p, 'r', encoding='utf-8') as f:
        return f.read()

def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)
    print("WROTE:", p)

# 1) ابزار Haptics
haptics = '''import 'package:flutter/services.dart';

/// آینه‌ی سبک از تنظیم بازخورد لمسی + متدهای آماده.
/// [enabled] از داخل تنظیمات همگام می‌شود.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static Future<void> light() async {
    if (enabled) await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (enabled) await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    if (enabled) await HapticFeedback.heavyImpact();
  }

  static Future<void> selection() async {
    if (enabled) await HapticFeedback.selectionClick();
  }
}
'''
write('lib/core/haptics/haptics.dart', haptics)

# 2) app_settings.dart : همگام‌سازی Haptics.enabled
p = 'lib/features/settings/application/app_settings.dart'
s = read(p)

# import
imp = "import '../../../core/haptics/haptics.dart';"
if 'core/haptics/haptics.dart' not in s:
    m = list(re.finditer(r'^import .*;$', s, flags=re.M))
    if m:
        idx = m[-1].end()
        s = s[:idx] + "\n" + imp + s[idx:]
    else:
        s = imp + "\n" + s
    print("app_settings: import added")

# setHaptic body : افزودن Haptics.enabled = v;
if 'Haptics.enabled = v;' not in s:
    s2 = re.sub(
        r'(Future<void>\s+setHaptic\(bool v\)\s+async\s*\{\s*)',
        r'\1Haptics.enabled = v;\n    ',
        s, count=1)
    if s2 != s:
        s = s2
        print("app_settings: setHaptic patched")
    else:
        print("WARN: setHaptic anchor not found")

write(p, s)

# 3) settings_screen.dart : وصل کردن ویبره واقعی
p = 'lib/features/settings/presentation/settings_screen.dart'
s = read(p)

# import services + haptics
if "package:flutter/services.dart" not in s:
    m = list(re.finditer(r'^import .*;$', s, flags=re.M))
    idx = m[-1].end() if m else 0
    s = s[:idx] + "\nimport 'package:flutter/services.dart';" + s[idx:]
    print("settings_screen: services import added")
if 'core/haptics/haptics.dart' not in s:
    m = list(re.finditer(r'^import .*;$', s, flags=re.M))
    idx = m[-1].end() if m else 0
    s = s[:idx] + "\nimport '../../../core/haptics/haptics.dart';" + s[idx:]
    print("settings_screen: haptics import added")

# همگام‌سازی enabled در build بعد از watch شدن settings
if 'Haptics.enabled = settings.hapticEnabled;' not in s:
    s2 = re.sub(
        r'(final\s+settings\s*=\s*ref\.watch\(appSettingsProvider\);\s*)',
        r'\1Haptics.enabled = settings.hapticEnabled;\n    ',
        s, count=1)
    if s2 != s:
        s = s2
        print("settings_screen: enabled sync added")
    else:
        print("WARN: settings watch anchor not found (sync skipped)")

# ویبره روی کلید Haptic Feedback
old_haptic = ("onChanged: (bool v) =>\n"
              "                ref.read(appSettingsProvider.notifier).setHaptic(v),")
new_haptic = ("onChanged: (bool v) {\n"
              "              ref.read(appSettingsProvider.notifier).setHaptic(v);\n"
              "              if (v) HapticFeedback.mediumImpact();\n"
              "            },")
if old_haptic in s:
    s = s.replace(old_haptic, new_haptic, 1)
    print("settings_screen: haptic toggle wired")
else:
    print("WARN: haptic onChanged anchor not found")

# ویبره روی کلید بیومتریک هم (حس تعامل)
old_bio = ("onChanged: (bool v) =>\n"
           "                ref.read(appSettingsProvider.notifier).setBiometricLock(v),")
new_bio = ("onChanged: (bool v) {\n"
           "              ref.read(appSettingsProvider.notifier).setBiometricLock(v);\n"
           "              Haptics.selection();\n"
           "            },")
if old_bio in s:
    s = s.replace(old_bio, new_bio, 1)
    print("settings_screen: biometric toggle wired")

write(p, s)
print("DONE")
