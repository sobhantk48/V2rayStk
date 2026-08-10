import re, pathlib, sys

NEW = "1.0.5+5"
p = pathlib.Path("pubspec.yaml")
src = p.read_text(encoding="utf-8")

m = re.search(r"^version:\s*(.+)$", src, flags=re.M)
if not m:
    sys.exit("!! خط version در pubspec.yaml پیدا نشد")

old = m.group(1).strip()
if old == NEW:
    print(f"== نسخه از قبل {NEW} است، تغییری لازم نبود")
else:
    src = src[:m.start(1)] + NEW + src[m.end(1):]
    p.write_text(src, encoding="utf-8")
    print(f"== version: {old}  ->  {NEW}")
