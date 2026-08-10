import re, shutil, sys, os

p = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/TorDaemon.kt"
if not os.path.exists(p):
    sys.exit("NOT FOUND: " + p)

src = open(p, encoding="utf-8").read()
shutil.copy(p, p + ".bak")

# بلاک جدید torrc: هر بار بازنویسی + DNSPort + Automap برای رفع نشتی DNS
new_block = (
    'val torrc = File(context.filesDir, "torrc")\n'
    '    torrc.writeText("""\n'
    '        SocksPort 9050\n'
    '        DNSPort 5353\n'
    '        AutomapHostsOnResolve 1\n'
    '        AutomapHostsSuffixes .onion,.exit\n'
    '        VirtualAddrNetworkIPv4 172.30.0.0/16\n'
    '        ClientDNSRejectInternalAddresses 1\n'
    '        DataDirectory ${context.filesDir.absolutePath}/tordata\n'
    '        Log notice stdout\n'
    '    """.trimIndent())'
)

# الگوی بلاک قدیمی: از تعریف torrc تا بسته‌شدن if
pattern = re.compile(
    r'val\s+torrc\s*=\s*File\(context\.filesDir,\s*"torrc"\)\s*'
    r'if\s*\(\s*!\s*torrc\.exists\(\)\s*\)\s*\{\s*'
    r'torrc\.writeText\(""".*?""".*?\)\s*'
    r'\}',
    re.DOTALL
)

src2, n = pattern.subn(new_block, src)
if n > 0:
    open(p, "w", encoding="utf-8").write(src2)
    print("PATCHED: TorDaemon.kt (torrc + DNSPort)")
else:
    print("NO MATCH: pattern not found, check file manually")
