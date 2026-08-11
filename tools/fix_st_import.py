#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""remove unnecessary dart:typed_data import"""
import os, shutil, time

P = "lib/features/split_tunnel/domain/installed_app.dart"
BAK = ".trash_bak"
os.makedirs(BAK, exist_ok=True)
STAMP = time.strftime("%Y%m%d-%H%M%S")

with open(P, encoding="utf-8") as f:
    lines = f.readlines()

out = [ln for ln in lines if ln.strip() != "import 'dart:typed_data';"]

if len(out) == len(lines):
    print("  -- import not found (already clean?)")
else:
    shutil.copy2(P, os.path.join(BAK, "installed_app.dart.bak_imp_" + STAMP))
    # حذف خط خالی احتمالی در ابتدای فایل
    while out and out[0].strip() == "":
        out.pop(0)
    with open(P, "w", encoding="utf-8") as f:
        f.writelines(out)
    print("  OK removed dart:typed_data from", P)

print("DONE")
