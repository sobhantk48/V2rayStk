import re, shutil, sys, pathlib

P = pathlib.Path("lib/features/sing_box/application/sing_box_config_generator.dart")
if not P.exists():
    sys.exit("!! فایل پیدا نشد: %s" % P)

src = P.read_text(encoding="utf-8")
shutil.copy(P, str(P) + ".bak")

# ---------- 1) پیدا کردن بلوک 'dns': { ... } با شمارش آکولاد ----------
m = re.search(r"""(['"]dns['"]\s*:\s*)\{""", src)
if not m:
    sys.exit("!! کلید 'dns' پیدا نشد")

start_key = m.start()
open_idx = src.index("{", m.end() - 1)
depth, i = 0, open_idx
in_str, q = False, ""
while i < len(src):
    c = src[i]
    if in_str:
        if c == "\\":
            i += 2
            continue
        if c == q:
            in_str = False
    else:
        if c in "'\"":
            in_str, q = True, c
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
    i += 1
if depth != 0:
    sys.exit("!! بلوک dns بسته نشد")
close_idx = i

# indent همان خطی که 'dns' شروع شده
line_start = src.rfind("\n", 0, start_key) + 1
indent = src[line_start:start_key]
if indent.strip():
    indent = "      "
ind2 = indent + "  "
ind3 = indent + "    "
ind4 = indent + "      "

new_dns = (
    "'dns': {\n"
    f"{ind2}'servers': [\n"
    f"{ind3}{{\n"
    f"{ind4}'tag': 'bootstrap-dns',\n"
    f"{ind4}'address': 'tcp://8.8.8.8',\n"
    f"{ind4}'detour': 'direct',\n"
    f"{ind3}}},\n"
    f"{ind3}{{\n"
    f"{ind4}'tag': 'proxy-dns',\n"
    f"{ind4}'address': 'tcp://1.1.1.1',\n"
    f"{ind4}'address_resolver': 'bootstrap-dns',\n"
    f"{ind4}'address_strategy': 'ipv4_only',\n"
    f"{ind4}'detour': 'proxy',\n"
    f"{ind3}}},\n"
    f"{ind3}{{\n"
    f"{ind4}'tag': 'tor-dns',\n"
    f"{ind4}'address': 'udp://127.0.0.1:5353',\n"
    f"{ind4}'detour': 'direct',\n"
    f"{ind3}}},\n"
    f"{ind3}{{'tag': 'local-dns', 'address': 'local', 'detour': 'direct'}},\n"
    f"{ind3}{{'tag': 'block-dns', 'address': 'rcode://success'}},\n"
    f"{ind2}],\n"
    f"{ind2}'rules': [\n"
    f"{ind3}{{'outbound': ['direct'], 'server': 'local-dns'}},\n"
    f"{ind3}{{'domain_suffix': ['.lan', '.local', '.internal'], 'server': 'local-dns'}},\n"
    f"{ind3}{{'domain': ['localhost'], 'server': 'local-dns'}},\n"
    f"{ind2}],\n"
    f"{ind2}'final': 'proxy-dns',\n"
    f"{ind2}'strategy': 'ipv4_only',\n"
    f"{ind2}'independent_cache': true,\n"
    f"{ind2}'disable_cache': false,\n"
    f"{ind2}'reverse_mapping': true,\n"
    f"{indent}}}"
)

src = src[:start_key] + new_dns + src[close_idx + 1:]
print("[ok] بلوک dns بازنویسی شد (bootstrap-dns + address_resolver + tor-dns)")

# ---------- 2) gvisor -> system ----------
if re.search(r"""['"]stack['"]\s*:\s*['"]gvisor['"]""", src):
    src = re.sub(r"""(['"]stack['"]\s*:\s*)['"]gvisor['"]""", r"\1'system'", src)
    print("[ok] stack: gvisor -> system")
else:
    print("[skip] stack گویزور پیدا نشد (احتمالاً قبلاً عوض شده)")

P.write_text(src, encoding="utf-8")
print("[done] بکاپ: %s.bak" % P)
