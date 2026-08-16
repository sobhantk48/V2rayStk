import pathlib, sys

p = pathlib.Path("lib/features/sing_box/application/admin_config_patcher.dart")
if not p.exists():
    sys.exit("[!] فایل patcher پیدا نشد")
src = p.read_text(encoding="utf-8")
orig = src

# ---------- باگ ۱: domain_suffix بدون نقطه ----------
variants = [
    "if (!value.contains('.') && !value.startsWith('.')) {",
    "if (!value.contains(\".\") && !value.startsWith(\".\")) {",
]
for v in variants:
    if v in src:
        src = src.replace(v, "if (!value.startsWith('.')) {")
        print("[+] باگ۱ رفع شد: همه دامنه‌ها با نقطه شروع می‌شوند")
        break
else:
    if "if (!value.startsWith('.')) {" in src:
        print("[=] باگ۱ قبلاً رفع شده بود")
    else:
        print("[!] باگ۱: الگو پیدا نشد — دستی چک کن")

p.write_text(src, encoding="utf-8")
print()
print("=" * 55)
print("حالا برای باگ ۲ (حالت Tor) این‌ها را برایم بفرست:")
print("=" * 55)
