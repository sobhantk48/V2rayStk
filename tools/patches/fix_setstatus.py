import re, shutil, sys, time, pathlib
p = pathlib.Path("android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt")
s = p.read_text(encoding="utf-8")
if "fun setStatus(" in s:
    print("SKIP: setStatus already exists")
    sys.exit(0)
m = re.search(r"^class V2rayVpnService : VpnService\(\) \{[ \t]*$", s, re.M)
if not m:
    print("FAIL: class line not found")
    sys.exit(1)
shutil.copy2(str(p), str(p) + ".setstatus.bak_" + time.strftime("%Y%m%d_%H%M%S"))
fn = (
    "\n"
    "    private fun setStatus(newStatus: String) {\n"
    "        if (VpnState.status == newStatus) return\n"
    "        VpnState.update(newStatus)\n"
    "        android.util.Log.i(TAG, \"status -> \" + newStatus)\n"
    "    }\n"
)
s = s[:m.end()] + fn + s[m.end():]
p.write_text(s, encoding="utf-8")
print("OK: setStatus restored")
