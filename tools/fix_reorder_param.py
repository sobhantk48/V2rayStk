#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix_reorder_param.py
اصلاح خطای بیلد: No named parameter with the name 'onReorderItem'
پارامتر صحیح در ReorderableListView.builder نام 'onReorder' است.
"""
import os
import re
import shutil
import sys

TARGETS = [
    "lib/features/groups/presentation/groups_manage_screen.dart",
]

# اگر جای دیگری هم همین اشتباه بود، کل lib را اسکن می‌کنیم
def scan_all():
    found = []
    for root, dirs, files in os.walk("lib"):
        for f in files:
            if f.endswith(".dart"):
                p = os.path.join(root, f)
                try:
                    with open(p, "r", encoding="utf-8") as fh:
                        if "onReorderItem" in fh.read():
                            found.append(p)
                except Exception:
                    pass
    return found


def patch(path):
    if not os.path.isfile(path):
        print(f"[SKIP] یافت نشد: {path}")
        return False
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()
    if "onReorderItem" not in src:
        print(f"[OK] قبلاً درست است: {path}")
        return False
    shutil.copy2(path, path + ".bak_reorder")
    new = re.sub(r"\bonReorderItem\s*:", "onReorder:", src)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new)
    n = len(re.findall(r"\bonReorderItem\s*:", src))
    print(f"[FIX] {path} -> {n} مورد onReorderItem به onReorder تغییر کرد")
    print(f"       نسخه پشتیبان: {path}.bak_reorder")
    return True


def main():
    if not os.path.isdir("lib"):
        print("خطا: پوشه lib پیدا نشد. داخل ریشه پروژه اجرا کن.")
        sys.exit(1)

    files = list(dict.fromkeys(TARGETS + scan_all()))
    changed = 0
    for p in files:
        if patch(p):
            changed += 1

    print("-" * 50)
    print(f"تعداد فایل اصلاح‌شده: {changed}")

    # حذف فایل‌های .bak قدیمی که ممکن است باعث خطای analyze شوند
    junk = []
    for root, dirs, fs in os.walk("lib"):
        for f in fs:
            if f.endswith(".dart.bak") or f.endswith(".dart.bak2"):
                junk.append(os.path.join(root, f))
    if junk:
        print("\nفایل‌های پشتیبان قدیمی که بهتر است پاک شوند:")
        for j in junk:
            print("  ", j)


if __name__ == "__main__":
    main()
