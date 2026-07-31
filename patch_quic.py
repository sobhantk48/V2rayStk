import io, sys

PATH = "lib/features/sing_box/application/sing_box_config_generator.dart"

with io.open(PATH, encoding="utf-8") as f:
    src = f.read()

if "'protocol': 'quic'" in src:
    print("[=] QUIC rule already exists, nothing to do.")
    sys.exit(0)

OLD = """        'rules': <Map<String, dynamic>>[
          <String, dynamic>{
            'protocol': 'dns',
            'outbound': 'dns-out',
          },
        ],"""

NEW = """        'rules': <Map<String, dynamic>>[
          <String, dynamic>{
            'protocol': 'dns',
            'outbound': 'dns-out',
          },
          <String, dynamic>{
            'protocol': 'quic',
            'outbound': 'block',
          },
          <String, dynamic>{
            'network': 'udp',
            'port': <int>[443],
            'outbound': 'block',
          },
        ],"""

if OLD not in src:
    print("[!] Pattern not found. File may have changed.")
    sys.exit(1)

src = src.replace(OLD, NEW, 1)

with io.open(PATH, "w", encoding="utf-8") as f:
    f.write(src)

print("[+] QUIC + UDP/443 block rules added successfully.")
