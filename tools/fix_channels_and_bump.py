#!/usr/bin/env python3
"""بازگردانی نام کانال‌ها + بامپ نسخه + پاکسازی بک‌آپ‌ها"""
import re, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
report = []

# ---------- 1) MainActivity.kt ----------
mk = ROOT / "android/app/src/main/kotlin/com/example/v2ray_stk/MainActivity.kt"
src = mk.read_text(encoding="utf-8")
orig = src

src = src.replace('"com.example.v2ray_stk/vpn_status"', '"com.v2ray.stk/vpn_status"')
src = re.sub(r'"com\.example\.v2ray_stk/vpn"', '"com.v2ray.stk/vpn"', src)
src = src.replace("EventChanne.StreamHandler", "EventChannel.StreamHandler")

# اطمینان از ثبت کانال لاگِ vpn
if "vpn.LogChannel.register" not in src:
    src = src.replace(
        "        LogChannel.register(flutterEngine)",
        "        LogChannel.register(flutterEngine)\n"
        "        com.example.v2ray_stk.vpn.LogChannel.register(flutterEngine)",
        1,
    )
    report.append("ثبت vpn.LogChannel اضافه شد")

if src != orig:
    mk.write_text(src, encoding="utf-8")
    report.append("MainActivity.kt اصلاح شد")
else:
    report.append("MainActivity.kt نیازی به تغییر نداشت")

for m in re.finditer(r'private val (\w*[Cc]hannelName) = "([^"]+)"', src):
    report.append("  {} = {}".format(m.group(1), m.group(2)))

# ---------- 2) نسخه ----------
NEW_NAME, NEW_CODE = "1.0.7", 7
pj = ROOT / "pubspec.yaml"
pt = pj.read_text(encoding="utf-8")
pt2, n = re.subn(r'(?m)^version:\s*\S+\s*$',
                 "version: {}+{}".format(NEW_NAME, NEW_CODE), pt, count=1)
if n:
    pj.write_text(pt2, encoding="utf-8")
    report.append("pubspec.yaml -> {}+{}".format(NEW_NAME, NEW_CODE))
else:
    report.append("!! خط version در pubspec.yaml پیدا نشد")

bg = ROOT / "android/app/build.gradle"
bt = bg.read_text(encoding="utf-8")
bt2 = bt
bt2, a = re.subn(r'versionCode\s+\d+', "versionCode {}".format(NEW_CODE), bt2)
bt2, b = re.subn(r'versionName\s+"[^"]*"', 'versionName "{}"'.format(NEW_NAME), bt2)
if bt2 != bt:
    bg.write_text(bt2, encoding="utf-8")
    report.append("build.gradle -> code={} name={}".format(NEW_CODE, NEW_NAME))
else:
    report.append("build.gradle نسخه‌ی hardcode ندارد (از pubspec می‌خواند) - اوکی")

# ---------- 3) پاکسازی بک‌آپ‌ها ----------
trash = ROOT / ".trash_bak"
trash.mkdir(exist_ok=True)
moved = 0
for p in ROOT.rglob("*"):
    if not p.is_file() or ".trash_bak" in p.parts or ".git" in p.parts:
        continue
    if re.search(r'\.(bak\w*|bak\d*|removed)$', p.name):
        dst = trash / p.name
        i = 1
        while dst.exists():
            dst = trash / "{}.{}".format(p.name, i); i += 1
        shutil.move(str(p), str(dst)); moved += 1
report.append("{} فایل بک‌آپ به .trash_bak منتقل شد".format(moved))

gi = ROOT / ".gitignore"
gt = gi.read_text(encoding="utf-8") if gi.exists() else ""
add = [x for x in [".trash_bak/", "*.bak", "*.bak_*", "*.removed"] if x not in gt.split()]
if add:
    if gt and not gt.endswith("\n"):
        gt += "\n"
    gt += "\n# backups\n" + "\n".join(add) + "\n"
    gi.write_text(gt, encoding="utf-8")
    report.append(".gitignore به‌روز شد: " + " ".join(add))

print("\n".join("✔ " + r for r in report))
