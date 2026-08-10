#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
silence_reorder_warn.py
1) افزودن // ignore: deprecated_member_use بالای onReorder
   دلیل: CI روی Flutter 3.35.5 است و onReorderItem وجود ندارد،
   پس باید onReorder بماند اما هشدار محلی حذف شود.
2) پاک کردن فایل‌های پشتیبان قدیمی داخل lib
"""
import os
import re
import shutil

TARGET = "lib/features/groups/presentation/groups_manage_screen.dart"
IGNORE = "// ignore: deprecated_member_use"


def patch(path):
    if not os.path.isfile(path):
        print(f"[SKIP] یافت نشد: {path}")
        return
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    out = []
    added = 0
    for i, line in enumerate(lines):
        if re.search(r"^\s*onReorder\s*:", line):
            prev = out[-1].strip() if out else ""
            if "deprecated_member_use" not in prev:
                indent = re.match(r"^(\s*)", line).group(1)
                out.append(f"{indent}{IGNORE}\n")
                added += 1
        out.append(line)

    if added == 0:
        print(f"[OK] چیزی برای تغییر نبود: {path}")
        return

    shutil.copy2(path, path + ".bak_ignore")
    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)
    print(f"[FIX] {added} کامنت ignore اضافه شد -> {path}")


def clean_backups():
    removed = []
    for root, _dirs, files in os.walk("lib"):
        for f in files:
            if re.search(r"\.dart\.(bak|bak2|bak_reorder|bak_ignore)$", f):
                p = os.path.join(root, f)
                # فایل پشتیبانی که همین الان ساختیم را نگه می‌داریم
                if f.endswith(".bak_ignore"):
                    continue
                os.remove(p)
                removed.append(p)
    if removed:
        print("\n[CLEAN] فایل‌های پشتیبان قدیمی پاک شدند:")
        for r in removed:
            print("   -", r)
    else:
        print("\n[CLEAN] فایل پشتیبان قدیمی نبود.")


if __name__ == "__main__":
    if not os.path.isdir("lib"):
        raise SystemExit("خطا: داخل ریشه پروژه اجرا کن (پوشه lib پیدا نشد).")
    patch(TARGET)
    clean_backups()
    print("\nحالا اجرا کن: flutter analyze")
