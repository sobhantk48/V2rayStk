#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""حذف تابع بی‌استفاده _isTorNeeded از vpn_controller.dart"""
import pathlib, re, subprocess, shutil

TARGET = "_isTorNeeded"
p = pathlib.Path("lib/features/vpn/application/vpn_controller.dart")
if not p.exists():
    raise SystemExit(f"!! فایل پیدا نشد: {p}")

src = p.read_text(encoding="utf-8")
shutil.copy2(p, str(p) + ".bak_tornedeed")
lines = src.split("\n")

# 1) پیدا کردن خط تعریف تابع
decl = None
for i, ln in enumerate(lines):
    if TARGET in ln and re.search(r'\b' + TARGET + r'\s*\(', ln):
        decl = i
        break

if decl is None:
    print(f" • {TARGET} پیدا نشد — احتمالاً قبلاً حذف شده.")
else:
    # 2) عقب رفتن روی کامنت‌ها/دکوریتورهای بالای تابع
    start = decl
    j = decl - 1
    while j >= 0:
        t = lines[j].strip()
        if t.startswith("///") or t.startswith("//") or t.startswith("@") \
           or t.startswith("*") or t.startswith("/*"):
            start = j
            j -= 1
        else:
            break

    # 3) پیدا کردن انتهای تابع
    end = None
    # حالت arrow:  Future<bool> _isTorNeeded() async => ...;
    joined = ""
    k = decl
    while k < len(lines) and k < decl + 4:
        joined += lines[k]
        if "=>" in joined and "{" not in joined.split("=>")[0]:
            # دنبال ; برو
            m = k
            while m < len(lines):
                if ";" in lines[m]:
                    end = m
                    break
                m += 1
            break
        if "{" in lines[k]:
            break
        k += 1

    if end is None:
        # حالت بلوکی: brace matching
        depth = 0
        opened = False
        for m in range(decl, len(lines)):
            for ch in lines[m]:
                if ch == "{":
                    depth += 1
                    opened = True
                elif ch == "}":
                    depth -= 1
            if opened and depth == 0:
                end = m
                break

    if end is None:
        raise SystemExit("!! نتوانستم انتهای تابع را پیدا کنم؛ دست نزدم.")

    removed_block = lines[start:end + 1]
    new_lines = lines[:start] + lines[end + 1:]

    # 4) جمع کردن خطوط خالی سه‌تایی
    txt = "\n".join(new_lines)
    txt = re.sub(r'\n{3,}', '\n\n', txt)
    p.write_text(txt, encoding="utf-8")

    print("=" * 60)
    print(f" • بلوک حذف‌شده: خطوط {start+1} تا {end+1}  ({len(removed_block)} خط)")
    print("-" * 60)
    for ln in removed_block:
        print("  - " + ln)
    print("=" * 60)

# 5) اطمینان از باقی‌ماندن _isTorEnabled
cur = p.read_text(encoding="utf-8")
print(f" • _isTorEnabled موجود؟ {'بله' if '_isTorEnabled' in cur else 'خیر (!!)'}")
print(f" • تعداد فراخوانی _isTorEnabled(): {cur.count('_isTorEnabled()')}")
print("\n>>> بازهٔ 95..130 پس از حذف:")
subprocess.run(["sed", "-n", "95,130p", str(p)])
