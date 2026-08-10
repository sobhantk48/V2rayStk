#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""settings_screen.dart را به شکل صحیح patch می‌کند."""
import shutil
from pathlib import Path

ROOT = Path.cwd()
f = ROOT / "lib/features/settings/presentation/settings_screen.dart"
src = f.read_text(encoding="utf-8")

# ---- بک‌آپ
shutil.copy2(f, f.with_suffix(".dart.bak2"))

lines = src.splitlines()
new_lines = []
skip_next = False

for i, line in enumerate(lines):
    if skip_next:
        skip_next = False
        continue

    # حذف import اضافه haptics که unused است
    if "import '../../../core/platform/haptics.dart';" in line:
        # فعلاً نگه می‌داریم - بعداً واقعاً استفاده می‌کنیم
        new_lines.append(line)
        continue

    # درست کردن خط setHaptic - هر شکلی که regex خرابش کرده
    if "setHaptic" in line and "Haptics" in line:
        # خط را از نو می‌نویسیم
        # پیدا کردن indent
        stripped = line.lstrip()
        indent = line[:len(line) - len(stripped)]
        new_lines.append(
            indent + "onChanged: (bool v) {\n"
            + indent + "  Haptics.enabled = v;\n"
            + indent + "  Haptics.selection();\n"
            + indent + "  ref.read(appSettingsProvider.notifier).setHaptic(v);\n"
            + indent + "},"
        )
        continue

    # درست کردن خط setBiometricLock
    if "setBiometricLock" in line and "Haptics" in line:
        stripped = line.lstrip()
        indent = line[:len(line) - len(stripped)]
        new_lines.append(
            indent + "onChanged: (bool v) {\n"
            + indent + "  Haptics.selection();\n"
            + indent + "  ref.read(appSettingsProvider.notifier).setBiometricLock(v);\n"
            + indent + "},"
        )
        continue

    new_lines.append(line)

result = "\n".join(new_lines)
f.write_text(result, encoding="utf-8")
print("✓ settings_screen.dart درست شد.")
