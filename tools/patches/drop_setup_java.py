#!/usr/bin/env python3
# NO_SETUP_JAVA_V1
# Remove actions/setup-java from build-apk.yml.
# ubuntu-latest already ships Java 17 at $JAVA_HOME_17_X64.
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WF = ROOT / ".github" / "workflows" / "build-apk.yml"

if not WF.exists():
    sys.exit("[ERR] not found: %s" % WF)

lines = WF.read_text(encoding="utf-8").splitlines()

if any("NO_SETUP_JAVA_V1" in ln for ln in lines):
    print("[SKIP] already patched")
    sys.exit(0)

start = None
for i, ln in enumerate(lines):
    if ln.strip().startswith("- name:") and "Setup Java" in ln:
        start = i
        break

if start is None:
    for i, ln in enumerate(lines):
        if "actions/setup-java" in ln:
            j = i
            while j >= 0 and not lines[j].strip().startswith("- "):
                j -= 1
            start = j
            break

if start is None:
    sys.exit("[ERR] setup-java step not found")

indent = len(lines[start]) - len(lines[start].lstrip(" "))
end = start + 1
while end < len(lines):
    s = lines[end]
    if s.strip() == "":
        end += 1
        continue
    cur = len(s) - len(s.lstrip(" "))
    if cur <= indent and s.lstrip().startswith("- "):
        break
    if cur < indent:
        break
    end += 1

pad = " " * indent
new_step = [
    pad + "# NO_SETUP_JAVA_V1",
    pad + "# actions/setup-java removed: ubuntu-latest ships Java 17.",
    pad + "# codeload 429/503 was breaking the build.",
    pad + "- name: Use preinstalled Java 17",
    pad + "  run: |",
    pad + "    set -euo pipefail",
    pad + '    echo "JAVA_HOME=$JAVA_HOME_17_X64" >> "$GITHUB_ENV"',
    pad + '    echo "$JAVA_HOME_17_X64/bin" >> "$GITHUB_PATH"',
    pad + '    "$JAVA_HOME_17_X64/bin/java" -version',
    "",
]

removed = lines[start:end]
out = lines[:start] + new_step + lines[end:]

if any("actions/setup-java" in ln for ln in out):
    sys.exit("[ERR] setup-java still present")

bak = WF.with_suffix(WF.suffix + ".javabak")
bak.write_text("\n".join(lines) + "\n", encoding="utf-8")
WF.write_text("\n".join(out) + "\n", encoding="utf-8")

print("[OK] removed %d lines (%d..%d)" % (len(removed), start + 1, end))
for r in removed:
    print("   - " + r)
print("[OK] backup: %s" % bak.name)
print("[OK] patched: %s" % WF)
