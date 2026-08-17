#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""حالت تور: DNS با FakeIP -> صفر تأخیر لوکاپ + تحویل دامنه به SOCKS تور."""
import shutil, sys, datetime, pathlib

SRC = pathlib.Path("lib/features/sing_box/application/sing_box_config_generator.dart")

if not SRC.exists():
    sys.exit("!! فایل پیدا نشد: %s" % SRC)

text = SRC.read_text(encoding="utf-8")

if "'fakeip-dns'" in text:
    sys.exit("== پچ قبلاً اعمال شده. تغییری لازم نیست.")

# ---------- ۱) سرور fakeip ----------
A1_OLD = "      {'tag': 'block-dns', 'address': 'rcode://success'},\n    ];"
A1_NEW = (
    "      {'tag': 'block-dns', 'address': 'rcode://success'},\n"
    "      // پاسخ‌دهندهٔ FakeIP: بدون هیچ رفت‌وبرگشت شبکه، آنی IP مصنوعی\n"
    "      // می‌دهد. فقط در حالت تور لازم است.\n"
    "      if (isTor) {'tag': 'fakeip-dns', 'address': 'fakeip'},\n"
    "    ];"
)

# ---------- ۲) قوانین DNS ----------
A2_OLD = (
    "      {\n"
    "        'domain_suffix': <String>['.local', '.lan', '.home'],\n"
    "        'server': isTor ? 'block-dns' : 'bootstrap-dns',\n"
    "      },\n"
    "    ];"
)
A2_NEW = (
    "      {\n"
    "        'domain_suffix': <String>['.local', '.lan', '.home'],\n"
    "        'server': isTor ? 'block-dns' : 'bootstrap-dns',\n"
    "      },\n"
    "      // تور IPv6 تحویل نمی‌دهد؛ AAAA (type 28) را خالی برگردان تا\n"
    "      // اپ‌ها منتظر پاسخی نمانند که هرگز نمی‌آید.\n"
    "      if (isTor)\n"
    "        {\n"
    "          'query_type': <int>[28],\n"
    "          'server': 'block-dns',\n"
    "        },\n"
    "      // کل کوئری‌های A از FakeIP جواب می‌گیرند: تأخیر DNS صفر می‌شود و\n"
    "      // دامنهٔ اصلی (نه IP) به SOCKS تور تحویل داده می‌شود.\n"
    "      if (isTor)\n"
    "        {\n"
    "          'query_type': <int>[1],\n"
    "          'server': 'fakeip-dns',\n"
    "        },\n"
    "    ];"
)

# ---------- ۳) بلاک fakeip در خروجی ----------
A3_OLD = (
    "    return <String, dynamic>{\n"
    "      'servers': servers,\n"
    "      'rules': rules,\n"
    "      'final': 'proxy-dns',\n"
    "      'strategy': 'ipv4_only',\n"
    "      'independent_cache': true,\n"
    "      'disable_cache': false,\n"
    "      'reverse_mapping': true,\n"
    "    };"
)
A3_NEW = (
    "    final Map<String, dynamic> dns = <String, dynamic>{\n"
    "      'servers': servers,\n"
    "      'rules': rules,\n"
    "      'final': 'proxy-dns',\n"
    "      'strategy': 'ipv4_only',\n"
    "      'independent_cache': true,\n"
    "      'disable_cache': false,\n"
    "      'reverse_mapping': true,\n"
    "    };\n"
    "    if (isTor) {\n"
    "      // محدودهٔ 198.18.0.0/15 توسط auto_route وارد tun می‌شود و\n"
    "      // sing-box هنگام اتصال، fakeip را به دامنهٔ واقعی برمی‌گرداند.\n"
    "      dns['fakeip'] = <String, dynamic>{\n"
    "        'enabled': true,\n"
    "        'inet4_range': '198.18.0.0/15',\n"
    "      };\n"
    "    }\n"
    "    return dns;"
)

patches = [
    ("سرور fakeip-dns", A1_OLD, A1_NEW),
    ("قوانین AAAA/A", A2_OLD, A2_NEW),
    ("بلاک dns.fakeip", A3_OLD, A3_NEW),
]

for name, old, new in patches:
    if text.count(old) != 1:
        sys.exit("!! لنگر «%s» پیدا نشد یا تکراری است (count=%d). پچ متوقف شد."
                 % (name, text.count(old)))

stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bak = SRC.with_suffix(SRC.suffix + ".fakeip.bak_" + stamp)
shutil.copy2(SRC, bak)
print("== بکاپ: %s" % bak)

for name, old, new in patches:
    text = text.replace(old, new, 1)
    print("   [ok] %s" % name)

SRC.write_text(text, encoding="utf-8")
print("== نوشته شد: %s" % SRC)
