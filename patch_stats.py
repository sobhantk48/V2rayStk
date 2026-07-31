#!/usr/bin/env python3
import re, sys
from pathlib import Path

BASE = Path("android/app/src/main/kotlin/com/example/v2ray_stk")
MAIN = BASE / "MainActivity.kt"
SVC  = BASE / "vpn" / "V2rayVpnService.kt"
CCB  = BASE / "vpn" / "CommandClientBridge.kt"

def die(msg):
    print("[x] " + msg)
    sys.exit(1)

for p in (MAIN, SVC, CCB):
    if not p.exists():
        die("فایل پیدا نشد: " + str(p))

ccb = CCB.read_text(encoding="utf-8")

m = re.search(r"fun\s+start\s*\(([^)]*)\)", ccb)
if m is None:
    die("متد start در CommandClientBridge پیدا نشد.")
raw_params = m.group(1).strip()
start_call = "CommandClientBridge.start()" if raw_params == "" else "CommandClientBridge.start(this)"
print("[i] start params -> " + repr(raw_params))
print("[i] فراخوانی انتخابی -> " + start_call)

if re.search(r"fun\s+stop\s*\(", ccb) is None:
    die("متد stop در CommandClientBridge پیدا نشد.")

snap = None
m2 = re.search(r"fun\s+(\w*[Ss]napshot\w*|\w*[Ss]tats\w*)\s*\(\s*\)", ccb)
if m2:
    snap = m2.group(1)

props = re.findall(r"(?:val|var)\s+(\w+)", ccb)
print("[i] اعضای شناسایی شده: " + ", ".join(sorted(set(props))))

CANDIDATES = ["uplink", "downlink", "uplinkTotal", "downlinkTotal",
              "up", "down", "upTotal", "downTotal",
              "connectionsIn", "connectionsOut", "memory", "goroutines"]

if snap:
    stats_expr = "CommandClientBridge." + snap + "()"
    print("[i] منبع آمار -> " + stats_expr)
else:
    found = [c for c in CANDIDATES if c in props]
    if not found:
        print("[x] نتوانستم منبع آمار را تشخیص دهم. محتوای CommandClientBridge.kt:")
        print("-" * 50)
        print(ccb)
        print("-" * 50)
        die("خروجی بالا را برای من بفرست تا نگاشت دقیق را بدهم.")
    pairs = ",\n            ".join(
        '"' + c + '" to CommandClientBridge.' + c for c in found)
    stats_expr = "mapOf(\n            " + pairs + "\n        )"
    print("[i] منبع آمار -> mapOf از " + ", ".join(found))

# ---------- MainActivity ----------
src = MAIN.read_text(encoding="utf-8")
changed = False

NEEDED = [
    "import android.os.Handler",
    "import android.os.Looper",
    "import java.net.InetSocketAddress",
    "import java.net.Socket",
    "import com.example.v2ray_stk.vpn.CommandClientBridge",
]
missing = [i for i in NEEDED if i not in src]
if missing:
    lines = src.split("\n")
    last = max(i for i, l in enumerate(lines) if l.startswith("import "))
    lines[last + 1:last + 1] = missing
    src = "\n".join(lines)
    changed = True
    print("[+] " + str(len(missing)) + " import اضافه شد")
else:
    print("[=] importها از قبل موجود بود")

anchor = '            "getStatus" -> result.success(VpnState.status)'
if anchor not in src:
    die("لنگر getStatus در MainActivity پیدا نشد.")

if '"getStats"' not in src:
    cases = (
        anchor + "\n"
        '            "getStats" -> result.success(statsSnapshot())\n'
        '            "testLatency" -> {\n'
        '                val host = call.argument<String>("host") ?: ""\n'
        '                val port = call.argument<Int>("port") ?: 443\n'
        '                val timeoutMs = call.argument<Int>("timeout") ?: 3000\n'
        '                Thread {\n'
        '                    val ms = measureLatency(host, port, timeoutMs)\n'
        '                    Handler(Looper.getMainLooper()).post { result.success(ms) }\n'
        '                }.start()\n'
        '            }'
    )
    src = src.replace(anchor, cases, 1)
    changed = True
    print("[+] caseهای getStats و testLatency اضافه شد")
else:
    print("[=] caseها از قبل موجود بود")

if "private fun statsSnapshot" not in src:
    helpers = (
        "\n"
        "    private fun statsSnapshot(): Map<String, Any> {\n"
        "        return runCatching {\n"
        "            " + stats_expr + "\n"
        "        }.getOrElse { emptyMap() }\n"
        "    }\n"
        "\n"
        "    private fun measureLatency(host: String, port: Int, timeoutMs: Int): Int {\n"
        "        if (host.isBlank()) return -1\n"
        "        return try {\n"
        "            val socket = Socket()\n"
        "            val t0 = System.nanoTime()\n"
        "            socket.connect(InetSocketAddress(host, port), timeoutMs)\n"
        "            val elapsed = ((System.nanoTime() - t0) / 1000000L).toInt()\n"
        "            runCatching { socket.close() }\n"
        "            elapsed\n"
        "        } catch (e: Throwable) {\n"
        "            -1\n"
        "        }\n"
        "    }\n"
    )
    idx = src.rstrip().rfind("}")
    src = src[:idx] + helpers + src[idx:]
    changed = True
    print("[+] توابع statsSnapshot و measureLatency اضافه شد")
else:
    print("[=] توابع کمکی از قبل موجود بود")

if changed:
    MAIN.write_text(src, encoding="utf-8")
    print("[✓] MainActivity.kt نوشته شد")

# ---------- V2rayVpnService ----------
svc = SVC.read_text(encoding="utf-8")
schanged = False

if "CommandClientBridge" in svc:
    print("[=] wiring سرویس از قبل موجود بود")
else:
    a1 = "SingBoxBridge.start(this, tun.fd, config)"
    if a1 not in svc:
        die("لنگر SingBoxBridge.start در سرویس پیدا نشد.")
    ind = svc[:svc.index(a1)].split("\n")[-1]
    svc = svc.replace(a1, a1 + "\n" + ind + "runCatching { " + start_call + " }", 1)
    schanged = True
    print("[+] CommandClientBridge.start تزریق شد")

    a2 = "runCatching { SingBoxBridge.stop() }"
    if a2 not in svc:
        die("لنگر SingBoxBridge.stop در سرویس پیدا نشد.")
    ind2 = svc[:svc.index(a2)].split("\n")[-1]
    svc = svc.replace(a2, "runCatching { CommandClientBridge.stop() }\n" + ind2 + a2, 1)
    schanged = True
    print("[+] CommandClientBridge.stop تزریق شد")

if schanged:
    SVC.write_text(svc, encoding="utf-8")
    print("[✓] V2rayVpnService.kt نوشته شد")

print("[پایان] پچ کامل شد.")
