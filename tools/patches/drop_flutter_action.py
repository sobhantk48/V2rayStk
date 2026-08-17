#!/usr/bin/env python3
import re, sys, shutil, datetime, io

P = ".github/workflows/build-apk.yml"
MARK = "NO_FLUTTER_ACTION_V1"

src = io.open(P, encoding="utf-8").read()
if MARK in src:
    print("[SKIP] already patched")
    sys.exit(0)
if "subosito/flutter-action" not in src:
    print("[ERR] flutter-action step not found")
    sys.exit(1)

ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
shutil.copyfile(P, "/tmp/build-apk.yml.flutterbak_" + ts)

lines = src.split("\n")
start = None
for i, l in enumerate(lines):
    if l.strip().startswith("- name:") and "Setup Flutter" in l:
        start = i
        break
if start is None:
    for i, l in enumerate(lines):
        if "subosito/flutter-action" in l:
            for j in range(i, -1, -1):
                if lines[j].strip().startswith("- name:") or lines[j].strip().startswith("- uses:"):
                    start = j
                    break
            break
if start is None:
    print("[ERR] cannot locate step start")
    sys.exit(1)

indent = len(lines[start]) - len(lines[start].lstrip())
end = start + 1
while end < len(lines):
    l = lines[end]
    if l.strip() == "":
        end += 1
        continue
    ind = len(l) - len(l.lstrip())
    if ind <= indent and l.lstrip().startswith("- "):
        break
    if ind < indent:
        break
    end += 1

blk = "\n".join(lines[start:end])
if "subosito/flutter-action" not in blk:
    print("[ERR] wrong block captured")
    sys.exit(1)

sp = " " * indent
new = [
    sp + "# " + MARK,
    sp + "- name: Install Flutter (manual)",
    sp + "  run: |",
    sp + "    set -euo pipefail",
    sp + '    FV="${FLUTTER_VERSION}"',
    sp + '    SDK="$HOME/flutter"',
    sp + '    TB="flutter_linux_${FV}-stable.tar.xz"',
    sp + '    URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${TB}"',
    sp + '    echo "try tarball: $URL"',
    sp + '    if curl -fsSL --retry 6 --retry-delay 5 --retry-all-errors -o "/tmp/${TB}" "$URL"; then',
    sp + '      tar -xf "/tmp/${TB}" -C "$HOME"',
    sp + "    else",
    sp + '      echo "tarball failed -> git clone fallback"',
    sp + '      git clone --depth 1 --branch "$FV" https://github.com/flutter/flutter.git "$SDK"',
    sp + "    fi",
    sp + '    echo "$SDK/bin" >> "$GITHUB_PATH"',
    sp + '    export PATH="$SDK/bin:$PATH"',
    sp + '    git config --global --add safe.directory "$SDK"',
    sp + "    flutter --version",
    sp + "    flutter config --no-analytics || true",
    sp + "    flutter precache --android",
]

out = lines[:start] + new + lines[end:]
txt = "\n".join(out)
io.open(P, "w", encoding="utf-8").write(txt)

if "subosito/flutter-action" in txt:
    print("[ERR] flutter-action still present")
    sys.exit(1)

try:
    import yaml
    yaml.safe_load(txt)
    print("[OK] YAML valid")
except ImportError:
    print("[WARN] PyYAML missing, skipped validation")
except Exception as e:
    print("[ERR] YAML broken:", e)
    sys.exit(1)

print("[OK] patched, backup: /tmp/build-apk.yml.flutterbak_" + ts)
