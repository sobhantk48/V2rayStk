#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""وصل کردن فلگ torEnabled از AdminSettings به MethodChannel — idempotent"""
import pathlib, sys

rep = []

# ==================== vpn_platform_service.dart ====================
p = pathlib.Path("lib/core/platform/vpn_platform_service.dart")
if not p.exists():
    sys.exit("!! vpn_platform_service.dart پیدا نشد. از ریشه پروژه اجرا کن.")
s = p.read_text(encoding="utf-8"); o = s

if "torEnabled" not in s:
    old = """  Future<void> connect(String config) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
      },
    );
  }"""
    new = """  Future<void> connect(String config, {bool torEnabled = false}) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
        'torEnabled': torEnabled,
      },
    );
  }"""
    if old not in s:
        sys.exit("!! الگوی connect در vpn_platform_service.dart پیدا نشد")
    s = s.replace(old, new, 1)
    rep.append("PlatformService: کلید torEnabled به invokeMethod اضافه شد")

# به‌روزرسانی کامنت راهنما
if "کلید `torEnabled` هم‌نام" not in s:
    s = s.replace(
        "  /// MainActivity.kt یکسان بماند.",
        "  /// MainActivity.kt یکسان بماند.\n"
        "  /// کلید `torEnabled` هم‌نام با call.argument<Boolean>(\"torEnabled\") است\n"
        "  /// و مشخص می‌کند دیمون Tor در سرویس نیتیو اجرا شود یا نه.", 1)

if s != o:
    p.write_text(s, encoding="utf-8")

# ======================= vpn_controller.dart =======================
p = pathlib.Path("lib/features/vpn/application/vpn_controller.dart")
if not p.exists():
    sys.exit("!! vpn_controller.dart پیدا نشد")
s = p.read_text(encoding="utf-8"); o = s

# 1) هر دو محل فراخوانی connect
old_call = "await _service.connect(await _buildConfigJson(profile));"
new_call = ("await _service.connect(\n"
            "        await _buildConfigJson(profile),\n"
            "        torEnabled: await _isTorEnabled(),\n"
            "      );")
n = s.count(old_call)
if n:
    s = s.replace(old_call, new_call)
    rep.append(f"Controller: {n} محل فراخوانی connect به‌روزرسانی شد")

# 2) افزودن helper (فقط یک‌بار)
if "Future<bool> _isTorEnabled()" not in s:
    anchor = "  /// پروفایل فعال، یا در نبود آن اولین پروفایل موجود."
    helper = """  /// فلگ Tor را از تنظیمات ادمین می‌خواند تا به سرویس نیتیو برسد.
  /// اگر خواندن شکست بخورد false برمی‌گردد تا پورت ۹۰۵۰ بی‌دلیل اشغال نشود.
  Future<bool> _isTorEnabled() async {
    try {
      final AdminSettings settings = await _reader.read();
      return settings.torEnabled;
    } catch (_) {
      return false;
    }
  }

"""
    if anchor not in s:
        sys.exit("!! نقطه درج helper پیدا نشد")
    s = s.replace(anchor, helper + anchor, 1)
    rep.append("Controller: متد _isTorEnabled اضافه شد")

if s != o:
    p.write_text(s, encoding="utf-8")

print("=" * 55)
for r in rep or ["! تغییری لازم نبود (قبلاً پچ شده)"]:
    print(" ✔" if rep else " ", r)
print("=" * 55)
