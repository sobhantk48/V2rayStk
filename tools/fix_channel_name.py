#!/usr/bin/env python3
"""یکسان‌سازی نام MethodChannel بین Dart و Kotlin."""
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CANON_VPN = "com.v2ray.stk/vpn"
CANON_STATUS = "com.v2ray.stk/vpn_status"

# هر رشته‌ای که شکل نام کانال دارد
CHANNEL_RE = re.compile(r'["\']((?:com|dev|io)\.[A-Za-z0-9_.]+/[A-Za-z0-9_/]+)["\']')

TARGET_DIRS = [ROOT / "lib", ROOT / "android" / "app" / "src" / "main"]
EXTS = {".dart", ".kt", ".java"}


def scan():
    print("=== نام کانال‌های موجود ===")
    found = {}
    for base in TARGET_DIRS:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if path.suffix not in EXTS or not path.is_file():
                continue
            for num, line in enumerate(
                path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1
            ):
                for name in CHANNEL_RE.findall(line):
                    rel = path.relative_to(ROOT)
                    found.setdefault(name, []).append(f"{rel}:{num}")
    for name in sorted(found):
        print(f"\n  {name}")
        for loc in found[name]:
            print(f"      {loc}")
    if not found:
        print("  چیزی پیدا نشد.")
    return found


def fix():
    # ترتیب مهم است: اول vpn_status بعد vpn
    subs = [
        ("com.example.v2ray_stk/vpn_status", CANON_STATUS),
        ("com.example.v2ray_stk/vpn", CANON_VPN),
    ]
    changed = []
    for base in TARGET_DIRS:
        if not base.exists():
            continue
        for path in sorted(base.rglob("*.dart")):
            text = path.read_text(encoding="utf-8")
            new = text
            for old, canon in subs:
                new = new.replace(old, canon)
            if new != text:
                shutil.copy2(path, path.with_suffix(path.suffix + ".bak_channel"))
                path.write_text(new, encoding="utf-8")
                changed.append(path.relative_to(ROOT))
    print("\n=== فایل‌های اصلاح‌شده ===")
    if changed:
        for item in changed:
            print(f"  {item}")
    else:
        print("  هیچ فایلی نیاز به تغییر نداشت (رشته‌ی com.example.v2ray_stk/vpn پیدا نشد).")
    return changed


if __name__ == "__main__":
    scan()
    fix()
    print("\n=== بازبینی بعد از اصلاح ===")
    scan()
