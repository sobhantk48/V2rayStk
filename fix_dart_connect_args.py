#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
تکمیل زنجیره: ارسال killSwitch و alwaysOnVpn از Dart به Native
- lib/core/platform/vpn_platform_service.dart
- lib/features/vpn/application/vpn_controller.dart
"""
import re, sys, shutil, pathlib, datetime

ROOT = pathlib.Path(__file__).resolve().parent
SVC = ROOT / "lib/core/platform/vpn_platform_service.dart"
CTL = ROOT / "lib/features/vpn/application/vpn_controller.dart"
STAMP = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")

def die(m):
    print("❌ " + m); sys.exit(1)

def backup(p):
    b = p.with_suffix(p.suffix + f".bak-{STAMP}")
    shutil.copy2(p, b); print(f"   ↳ بکاپ: {b.name}")

for p in (SVC, CTL):
    if not p.exists():
        die(f"فایل پیدا نشد: {p}")

# ---------- 0) کشف نام فیلدها در AdminSettings ----------
cand = list(ROOT.glob("lib/**/admin_settings*.dart"))
fields = {"killSwitch": None, "alwaysOnVpn": None}
blob = ""
for c in cand:
    blob += c.read_text(encoding="utf-8")
def find_field(*names):
    for n in names:
        if re.search(r"\b" + re.escape(n) + r"\b", blob):
            return n
    return None
ks = find_field("killSwitch", "killswitch", "isKillSwitch", "killSwitchEnabled")
ao = find_field("alwaysOnVpn", "alwaysOn", "alwaysOnVPN", "alwaysOnVpnEnabled")
if not ks or not ao:
    print("⚠️  فیلدهای AdminSettings پیدا نشد. فایل‌های بررسی‌شده:")
    for c in cand: print("   -", c.relative_to(ROOT))
    die("نام فیلد killSwitch/alwaysOnVpn در AdminSettings مشخص نشد.")
print(f"✅ فیلدهای AdminSettings: {ks} / {ao}")

# ---------- 1) vpn_platform_service.dart ----------
s = SVC.read_text(encoding="utf-8")
orig_s = s

new_connect = '''Future<void> connect(
    String config, {
    bool torEnabled = false,
    bool killSwitch = false,
    bool alwaysOnVpn = false,
  }) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
        'torEnabled': torEnabled,
        'killSwitch': killSwitch,
        'alwaysOnVpn': alwaysOnVpn,
      },
    );
  }'''

pat = re.compile(
    r"Future<void>\s+connect\s*\([^)]*\)\s*async\s*\{.*?\n\s{2}\}",
    re.S,
)
if "'alwaysOnVpn'" in s:
    print("ℹ️  vpn_platform_service.dart از قبل به‌روز است.")
else:
    m = pat.search(s)
    if not m:
        die("متد connect در vpn_platform_service.dart پیدا نشد.")
    s = s[:m.start()] + new_connect + s[m.end():]
    backup(SVC); SVC.write_text(s, encoding="utf-8")
    print("✅ vpn_platform_service.dart به‌روزرسانی شد.")

# ---------- 2) vpn_controller.dart ----------
c = CTL.read_text(encoding="utf-8")
if "alwaysOnVpn:" in c:
    print("ℹ️  vpn_controller.dart از قبل به‌روز است.")
else:
    # 2-a) جایگزینی همه فراخوانی‌های _service.connect(...)
    call_pat = re.compile(
        r"await\s+_service\.connect\(\s*await\s+_buildConfigJson\(profile\)\s*,\s*"
        r"torEnabled:\s*await\s+_isTorEnabled\(\)\s*,?\s*\);",
        re.S,
    )
    replacement = (
        "final AdminSettings settings = await _readSettings();\n"
        "      await _service.connect(\n"
        "        await _buildConfigJson(profile),\n"
        "        torEnabled: settings.torEnabled,\n"
        f"        killSwitch: settings.{ks},\n"
        f"        alwaysOnVpn: settings.{ao},\n"
        "      );"
    )
    c, n = call_pat.subn(replacement, c)
    if n == 0:
        die("هیچ فراخوانی _service.connect مطابق الگو پیدا نشد (ساختار فایل تغییر کرده).")
    print(f"✅ {n} فراخوانی connect در کنترلر به‌روزرسانی شد.")

    # 2-b) تبدیل _isTorEnabled به _readSettings
    tor_pat = re.compile(
        r"Future<bool>\s+_isTorEnabled\(\)\s*async\s*\{.*?\n\s{2}\}",
        re.S,
    )
    new_reader = '''Future<AdminSettings> _readSettings() async {
    try {
      return await _reader.read();
    } catch (_) {
      return const AdminSettings();
    }
  }'''
    if tor_pat.search(c):
        c = tor_pat.sub(new_reader, c, count=1)
        print("✅ _isTorEnabled → _readSettings تبدیل شد.")
    else:
        print("⚠️  _isTorEnabled پیدا نشد؛ _readSettings را دستی بررسی کن.")

    backup(CTL); CTL.write_text(c, encoding="utf-8")
    print("✅ vpn_controller.dart به‌روزرسانی شد.")

print("\n🎯 تمام. حالا اجرا کن:\n   flutter analyze")
