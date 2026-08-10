#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import pathlib, re, subprocess, sys

report = []

# ---------- 1) DART ----------
d = pathlib.Path("lib/features/vpn/application/vpn_controller.dart")
if d.exists():
    s = d.read_text(encoding="utf-8"); o = s
    # اگر _isTorEnabled تعریف شده ولی استفاده نشده -> جایگزین tor کن
    if "_isTorEnabled" in s and "await _isTorEnabled()" not in s.split("Future<bool> _isTorEnabled")[0]:
        s = s.replace("torEnabled: tor,", "torEnabled: await _isTorEnabled(),")
        s = s.replace("torEnabled: tor)", "torEnabled: await _isTorEnabled())")
    if s != o:
        d.write_text(s, encoding="utf-8"); report.append("DART: torEnabled -> _isTorEnabled()")
    else:
        report.append("DART: تغییری لازم نبود")

# ---------- 2) KOTLIN ----------
k = pathlib.Path("android/app/src/main/kotlin/com/example/v2ray_stk/MainActivity.kt")
if not k.exists():
    sys.exit("!! MainActivity.kt پیدا نشد")
s = k.read_text(encoding="utf-8"); o = s

# call-site: prepareAndConnect(...) تک آرگومانی -> دو آرگومانی
s = re.sub(
    r'prepareAndConnect\(\s*call\.argument<String>\("config"\)\s*\?:\s*""\s*\)',
    'prepareAndConnect(\n                            call.argument<String>("config") ?: "",\n                            pendingTorEnabled,\n                        )',
    s)

# داخل startVpnService از پارامتر استفاده شود نه فیلد
s = re.sub(
    r'(fun startVpnService\(config: String, torEnabled: Boolean\)[\s\S]{0,400}?putExtra\(V2rayVpnService\.EXTRA_TOR_ENABLED,\s*)pendingTorEnabled(\s*\))',
    r'\1torEnabled\2', s)

if s != o:
    k.write_text(s, encoding="utf-8"); report.append("KOTLIN: call-site + putExtra اصلاح شد")
else:
    report.append("KOTLIN: تغییری اعمال نشد (بررسی دستی لازم)")

print("="*58)
for r in report: print(" •", r)
print("="*58)
print("\n>>> MainActivity 45..75:")
subprocess.run(["sed","-n","45,75p",str(k)])
print("\n>>> MainActivity 145..190:")
subprocess.run(["sed","-n","145,190p",str(k)])
print("\n>>> Dart connect calls:")
subprocess.run(["grep","-n","-A3","_service.connect(",str(d)])
