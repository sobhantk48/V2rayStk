#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""در حالت Tor ترافیک UDP را بلاک می‌کند.
SOCKS5 تور از UDP ASSOCIATE پشتیبانی نمی‌کند و هر تلاش UDP (مثل QUIC/443)
خطای «code=7 command not supported» می‌سازد. با بلاک UDP کلاینت‌ها
به TCP/TLS سقوط می‌کنند و ارور تمام می‌شود.
"""
import io
import os
import re
import shutil
import sys

PATH = "lib/features/sing_box/application/sing_box_config_generator.dart"
MARKER = "'network': 'udp'"

# anchor: پایان لیست rules + خط final  (تورفتگی هرچه باشد گرفته می‌شود)
ANCHOR_RE = re.compile(
    r"(?P<ind>[ \t]*)\],\n(?P<ind2>[ \t]*)'final': 'proxy',"
)

BLOCK_TMPL = (
    "{item}// ۴) در حالت Tor هیچ UDP نداریم (SOCKS5 تور UDP ندارد).\n"
    "{item}//    پورت ۵۳ و loopback بالاتر هندل شده‌اند، پس DNS سالم می‌ماند.\n"
    "{item}if (isTor)\n"
    "{item}  {{\n"
    "{item}    'network': 'udp',\n"
    "{item}    'outbound': 'block',\n"
    "{item}  }},\n"
    "{close}],\n"
    "{close}'final': 'proxy',"
)


def main():
    if not os.path.isfile(PATH):
        print("[x] فایل پیدا نشد: %s" % PATH)
        return 1

    with io.open(PATH, "r", encoding="utf-8") as fh:
        src = fh.read()

    if MARKER in src:
        print("[=] پچ از قبل اعمال شده بود؛ تغییری لازم نبود.")
        return 0

    matches = list(ANCHOR_RE.finditer(src))
    if len(matches) != 1:
        print("[x] anchor پیدا نشد یا چندتایی بود (تعداد=%d)." % len(matches))
        return 2

    m = matches[0]
    close = m.group("ind")          # تورفتگی ']' مثلا ۸ فاصله
    item = close + "  "             # تورفتگی آیتم‌های داخل لیست => ۱۰ فاصله

    src = src[:m.start()] + BLOCK_TMPL.format(item=item, close=close) \
        + src[m.end():]

    shutil.copy2(PATH, PATH + ".bak_udpblock")
    with io.open(PATH, "w", encoding="utf-8") as fh:
        fh.write(src)

    print("[+] قانون بلاک UDP برای حالت Tor اضافه شد.")
    print("[+] پشتیبان: %s.bak_udpblock" % PATH)
    return 0


if __name__ == "__main__":
    sys.exit(main())
