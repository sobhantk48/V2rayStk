#!/usr/bin/env python3
"""
رفع مشکل:
  گارد _usesTorDns به اشتباه داخل void _patchLog افتاد => return_of_invalid_type
اقدامات:
  1. گارد + return config را از _patchLog پاک می‌کند
  2. همان گارد را درست داخل _patchDns می‌گذارد (بعد از باز شدن {)
  3. متد _usesTorDns را اضافه می‌کند اگر وجود نداشته باشد
"""
import re
from pathlib import Path

P = Path("lib/features/sing_box/application/admin_config_patcher.dart")
src = P.read_text(encoding="utf-8")

# -------------------------------------------------------------------
# 1. گارد اشتباه را از _patchLog پاک کن
# -------------------------------------------------------------------
WRONG_GUARD = (
    "    // در حالت Tor، DNS محلی (127.0.0.1:5353) نباید بازنویسی شود؛\n"
    "    // در غیر این صورت bootstrap مستقیم باعث نشت DNS می‌شود.\n"
    "    if (_usesTorDns(config)) {\n"
    "      return config;\n"
    "    }\n"
)
if WRONG_GUARD in src:
    src = src.replace(WRONG_GUARD, "", 1)
    print("[OK] گارد اشتباه از _patchLog پاک شد")
else:
    print("[SKIP] گارد اشتباه پیدا نشد — شاید از قبل پاک بود")

# -------------------------------------------------------------------
# 2. گارد درست را داخل _patchDns بگذار (بعد از اولین { در امضای void)
# -------------------------------------------------------------------
CORRECT_GUARD = (
    "    // در حالت Tor، DNS محلی (127.0.0.1:5353) نباید بازنویسی شود.\n"
    "    if (_usesTorDns(config)) return;\n"
)

# امضای دقیق تابع را پیدا کن
patch_dns_sig = re.search(
    r"(void _patchDns\(Map<String, dynamic> config, AdminSettings settings\)\s*\{)\n",
    src,
)
if patch_dns_sig and CORRECT_GUARD not in src:
    insert_pos = patch_dns_sig.end()
    src = src[:insert_pos] + CORRECT_GUARD + src[insert_pos:]
    print("[OK] گارد درست داخل _patchDns اضافه شد")
elif CORRECT_GUARD in src:
    print("[SKIP] گارد درست از قبل داخل _patchDns بود")
else:
    print("[FAIL] امضای void _patchDns پیدا نشد!")

# -------------------------------------------------------------------
# 3. متد _usesTorDns را اضافه کن (قبل از _dnsAddress)
# -------------------------------------------------------------------
TOR_HELPER = (
    "  /// آیا DNS محلی Tor (127.0.0.1:5353) در کانفیگ فعال است؟\n"
    "  bool _usesTorDns(Map<String, dynamic> config) {\n"
    "    final Object? dns = config['dns'];\n"
    "    if (dns is! Map) return false;\n"
    "    final Object? servers = dns['servers'];\n"
    "    if (servers is! List) return false;\n"
    "    for (final Object? s in servers) {\n"
    "      if (s is Map &&\n"
    "          (s['address'] ?? '').toString().contains('127.0.0.1:5353')) {\n"
    "        return true;\n"
    "      }\n"
    "    }\n"
    "    return false;\n"
    "  }\n\n"
)

anchor = "  String _dnsAddress(AdminSettings settings) {"
if "bool _usesTorDns(" in src:
    print("[SKIP] _usesTorDns از قبل موجود بود")
elif anchor in src:
    src = src.replace(anchor, TOR_HELPER + anchor, 1)
    print("[OK] متد _usesTorDns اضافه شد")
else:
    print("[FAIL] انکر _dnsAddress پیدا نشد!")

P.write_text(src, encoding="utf-8")
print("\n=== analyze ===")
