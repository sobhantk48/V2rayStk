#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""حذف address_resolver خودارجاع از bootstrap-dns"""
from pathlib import Path

T = Path("lib/features/sing_box/application/sing_box_config_generator.dart")
src = T.read_text(encoding="utf-8")

bad = """        'address': 'tcp://8.8.8.8',
        'address_resolver': 'bootstrap-dns',
        'strategy': 'ipv4_only',
        'detour': 'direct',"""

good = """        'address': 'tcp://8.8.8.8',
        'strategy': 'ipv4_only',
        'detour': 'direct',"""

if bad in src:
    src = src.replace(bad, good, 1)
    T.write_text(src, encoding="utf-8")
    print("✅ address_resolver خودارجاع حذف شد")
elif "'address': 'tcp://8.8.8.8'," in src and "'address_resolver': 'bootstrap-dns',\n        'strategy'" not in src:
    print("ℹ️ از قبل تمیز است، تغییری لازم نبود")
else:
    raise SystemExit("❌ الگو پیدا نشد — دستی بررسی کن")
