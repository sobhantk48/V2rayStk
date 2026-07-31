import re, io

path = "lib/services/sing_box_config_generator.dart"
# اگر مسیر فایلت فرق دارد، همین یک خط را عوض کن
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

if "'protocol': 'quic'" in src:
    print("QUIC block از قبل وجود دارد. تغییری اعمال نشد.")
else:
    dns_rule = """{
        'protocol': 'dns',
        'outbound': 'dns-out',
      }"""
    # الگوی انعطاف‌پذیر برای پیدا کردن rule مربوط به dns با هر میزان فاصله
    pattern = re.compile(
        r"\{\s*'protocol'\s*:\s*'dns'\s*,\s*'outbound'\s*:\s*'dns-out'\s*,?\s*\}"
    )
    m = pattern.search(src)
    if not m:
        raise SystemExit("rule مربوط به dns پیدا نشد؛ فایل را دستی بررسی کن.")
    quic_rule = m.group(0).rstrip() + """,
      {
        'protocol': 'quic',
        'outbound': 'block',
      }"""
    src = src[:m.start()] + quic_rule + src[m.end():]
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("QUIC block با موفقیت اضافه شد.")
