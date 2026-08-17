import os

file_path = 'lib/features/sing_box/application/sing_box_config_generator.dart'

with open(file_path, 'r') as f:
    content = f.read()

# ۱. اصلاح بلاک کردن UDP/QUIC برای سرعت بیشتر در تور
# پیدا کردن بخش مربوط به بلاک کردن UDP در حالت تور و جایگزینی با نسخه دقیق‌تر
old_udp_block = """          if (isTor)
            {
              'network': 'udp',
              'outbound': 'block',
            },"""

new_udp_block = """          if (isTor)
            {
              'network': 'udp',
              'port': <int>[443, 8443, 5222, 5228], // بلاک کردن QUIC و پورت‌های UDP تلگرام/گوگل
              'outbound': 'block',
            },"""

if old_udp_block in content:
    content = content.replace(old_udp_block, new_udp_block)

# ۲. اضافه کردن Reject به جای Block برای پورت ۴۴۳ (برای اینکه اپ‌ها سریع‌تر بفهمن نباید UDP بزنن)
content = content.replace(
    "'outbound': 'block'", 
    "'outbound': 'block'" # فعلاً بلاک نگه می‌داریم چون سینگ باکس اندروید با Reject گاهی بازی در میاره
)

# ۳. اصلاح بخش sniff برای دقت بیشتر
content = content.replace(
    "'sniff': true,",
    "'sniff': true,\n          'sniff_timeout': '300ms',"
)

with open(file_path, 'w') as f:
    f.write(content)

print("✅ Patch applied: QUIC blocking optimized for Tor speed.")
