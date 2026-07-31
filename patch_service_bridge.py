import re, sys, io

P = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"
src = io.open(P, encoding="utf-8").read()
orig = src

START_ANCHORS = ["SingBoxBridge.start", "boxService.start", "core.start(",
                 "startCore(", "singBoxCore.start", "vpnCore.start"]
STOP_ANCHORS  = ["SingBoxBridge.stop", "boxService.stop", "core.stop(",
                 "stopCore(", "singBoxCore.stop", "vpnCore.stop"]

def inject_after(text, anchors, call):
    if call in text:
        print("  skip (already present):", call)
        return text, True
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        for a in anchors:
            if a in ln and "CommandClientBridge" not in ln:
                indent = re.match(r"[ \t]*", ln).group(0)
                lines.insert(i + 1, indent + call)
                print("  injected after line %d (anchor: %s)" % (i + 1, a))
                return "\n".join(lines), True
    return text, False

print("[start]")
src, ok1 = inject_after(src, START_ANCHORS, "CommandClientBridge.start()")
print("[stop]")
src, ok2 = inject_after(src, STOP_ANCHORS, "CommandClientBridge.stop()")

if src != orig:
    io.open(P, "w", encoding="utf-8").write(src)
    print("\n>>> WROTE", P)
else:
    print("\n>>> NO CHANGE")

if not (ok1 and ok2):
    print("\n===== ANCHOR NOT FOUND -> file dump =====")
    for n, l in enumerate(orig.split("\n"), 1):
        print("%4d| %s" % (n, l))
