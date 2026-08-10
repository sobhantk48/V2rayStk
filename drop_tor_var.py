#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import pathlib, re, subprocess

p = pathlib.Path("lib/features/vpn/application/vpn_controller.dart")
s = p.read_text(encoding="utf-8")
lines = s.split("\n")

out, removed = [], 0
for ln in lines:
    # خطوطی مثل:  final tor = ... ;   یا   final bool tor = await ...;
    if re.match(r'\s*(final|var)\s+(bool\s+)?tor\s*=', ln) and "torEnabled" not in ln:
        removed += 1
        continue
    out.append(ln)

if removed:
    p.write_text("\n".join(out), encoding="utf-8")

print("="*58)
print(f" • {removed} خط متغیر مرده 'tor' حذف شد")
print("="*58)
print("\n>>> vpn_controller 50..95:")
subprocess.run(["sed","-n","50,95p",str(p)])
