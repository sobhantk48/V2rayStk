import os

file_path = 'lib/features/sing_box/application/sing_box_config_generator.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old = "'address': 'https://8.8.8.8/dns-query',"
new = "'address': 'https://1.1.1.1/dns-query',"

if old in content:
    content = content.replace(old, new)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("OK: DNS به کلودفلر (1.1.1.1) تغییر کرد.")
else:
    print("هشدار: رشته‌ی موردنظر پیدا نشد. شاید قبلاً تغییر کرده باشه.")
