#!/usr/bin/env python3
"""حذف آکولاد بستهٔ اضافه در انتهای V2rayVpnService.kt

خط 410 یک '}' با تورفتگی است که از تابع قدیمی closeTunFd باقی مانده.
با حذف آن، '}' خط 412 در ستون 1 کلاس را می‌بندد و تعادل آکولادها صفر می‌شود.
"""
import shutil
import sys
from pathlib import Path

TARGET = Path(
    "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"
)


def brace_depth(lines):
    """محاسبهٔ سادهٔ عمق آکولادها و کمترین عمق رسیده."""
    depth = 0
    lowest = 0
    for line in lines:
        for ch in line:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                lowest = min(lowest, depth)
    return depth, lowest


def main():
    if not TARGET.exists():
        sys.exit(f"[x] فایل پیدا نشد: {TARGET}")

    text = TARGET.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)

    before_depth, before_lowest = brace_depth(lines)
    print(f"[i] تعداد خطوط فعلی : {len(lines)}")
    print(f"[i] عمق آکولاد فعلی : {before_depth} (کمترین: {before_lowest})")

    if before_depth == 0:
        print("[=] فایل از قبل متعادل است. تغییری لازم نیست.")
        return

    if before_depth != -1:
        sys.exit(f"[x] عمق غیرمنتظره {before_depth}؛ برای بررسی دستی متوقف شدم.")

    # ایندکس صفرپایه برای خط 410
    idx = 409
    if idx >= len(lines):
        sys.exit("[x] فایل کوتاه‌تر از حد انتظار است.")

    victim = lines[idx]
    if victim.strip() != "}":
        sys.exit(f"[x] خط 410 آکولاد تنها نیست: {victim!r}")
    if not victim.startswith(" "):
        sys.exit("[x] خط 410 تورفتگی ندارد؛ ممکن است آکولاد بستن کلاس باشد.")

    backup = TARGET.with_suffix(TARGET.suffix + ".brace.bak")
    shutil.copy2(TARGET, backup)
    print(f"[+] نسخهٔ پشتیبان: {backup}")

    del lines[idx]

    after_depth, after_lowest = brace_depth(lines)
    if after_depth != 0 or after_lowest < 0:
        shutil.copy2(backup, TARGET)
        sys.exit(f"[x] نتیجه نامتعادل ({after_depth}/{after_lowest})؛ بازگردانی شد.")

    TARGET.write_text("".join(lines), encoding="utf-8")
    print(f"[+] خط 410 حذف شد. تعداد خطوط جدید: {len(lines)}")
    print(f"[+] عمق آکولاد نهایی: {after_depth} ✓")


if __name__ == "__main__":
    main()
