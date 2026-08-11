#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Bump pubspec.yaml version to 1.0.8+8"""
import re, sys, pathlib

NEW_VER = "1.0.8"
NEW_BUILD = "8"

p = pathlib.Path("pubspec.yaml")
if not p.exists():
    print("[X] pubspec.yaml پیدا نشد. داخل روت پروژه اجرا کن.")
    sys.exit(1)

src = p.read_text(encoding="utf-8")
m = re.search(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$', src, re.M)
if not m:
    print("[X] خط version: پیدا نشد.")
    sys.exit(1)

old = f"{m.group(1)}+{m.group(2)}"
new = f"{NEW_VER}+{NEW_BUILD}"

if old == new:
    print(f"[=] نسخه از قبل {new} است. کاری نکردم.")
    sys.exit(0)

src = src[:m.start()] + f"version: {new}" + src[m.end():]
p.write_text(src, encoding="utf-8")
print(f"[OK] نسخه {old}  ->  {new}")
