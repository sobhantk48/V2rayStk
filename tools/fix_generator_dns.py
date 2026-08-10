import shutil, os, re

p = "lib/features/sing_box/application/sing_box_config_generator.dart"
if not os.path.exists(p):
    raise SystemExit("NOT FOUND: " + p)

src = open(p, encoding="utf-8").read()
shutil.copy(p, p + ".bak")

# هر آدرس DNS خارجی (cloudflare/google/tcp/udp) رو به پورت محلی Tor برگردون
new_addr = "udp://127.0.0.1:5353"
pattern = re.compile(r"'address':\s*'(?:tcp|udp|https)://[^']*'")
src2, n = pattern.subn("'address': '%s'" % new_addr, src)

if n > 0:
    open(p, "w", encoding="utf-8").write(src2)
    print("PATCHED: %d DNS address(es) -> %s" % (n, new_addr))
else:
    print("SKIP: no DNS 'address' found, send me the file content")
