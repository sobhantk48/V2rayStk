#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# gam 1: raf-e marg-e UDP dar zanjire sing-box -> Xray
import re
import shutil
import sys
from pathlib import Path

TARGET = Path("lib/features/sing_box/application/sing_box_config_generator.dart")

if not TARGET.exists():
    print("khata: file peyda nashod:", TARGET)
    sys.exit(1)

src = TARGET.read_text(encoding="utf-8")
shutil.copy2(TARGET, Path(str(TARGET) + ".bak_udp"))
print("backup:", str(TARGET) + ".bak_udp")

pattern = re.compile(r"(['\"]udp_over_tcp['\"]\s*:\s*)true")
new_src, n = pattern.subn(r"\1false", src)

if n:
    TARGET.write_text(new_src, encoding="utf-8")
    print("OK -", n, "morede udp_over_tcp be false taghir kard")
else:
    print("! hich udp_over_tcp: true peyda nashod. hameye erja'at:")
    for i, line in enumerate(src.splitlines(), 1):
        if "udp_over_tcp" in line:
            print("   ", i, ":", line.strip())

lines = new_src.splitlines()
keys = ["address_resolver", "bootstrap", "detour", "query_type",
        "1.1.1.1", "8.8.8.8", "tls://", "https://", "udp_over_tcp",
        "'dns'", "\"dns\"", "10808"]

print()
print("=" * 60)
print("KHOTOOT-E DNS (in khorooji ra baram befrest):")
print("=" * 60)
for i, l in enumerate(lines, 1):
    for k in keys:
        if k in l:
            print(i, ":", l.rstrip())
            break
print("=" * 60)
print("kol khotoot-e file:", len(lines))
