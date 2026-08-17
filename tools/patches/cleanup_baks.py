#!/usr/bin/env python3
"""پاک‌سازی امن فایل‌های .bak و اسکریپت‌های پچ تکراری در ریشه.

اجرا:
    python3 tools/patches/cleanup_baks.py           # فقط نمایش (آزمایشی)
    python3 tools/patches/cleanup_baks.py --apply   # اجرای واقعی
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

APPLY = "--apply" in sys.argv
PATCH_DIR_NAME = "tools/patches"
SKIP_DIRS = {".git", "build", ".dart_tool", ".pub-cache", "node_modules"}
BAK_SUFFIXES = (".bak", ".bak2", ".orig", ".rej", ".removed")
BAK_MARKERS = (".bak_", ".bak.", ".dup_")
SCRIPT_PREFIXES = ("patch_", "fix_", "make_", "cleanup_")


def repo_root() -> Path:
    try:
        out = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        return Path(out.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return Path(__file__).resolve().parents[2]


def walk(root: Path):
    stack = [root]
    while stack:
        current = stack.pop()
        try:
            entries = list(current.iterdir())
        except OSError:
            continue
        for entry in entries:
            if entry.is_dir() and not entry.is_symlink():
                if entry.name in SKIP_DIRS:
                    continue
                stack.append(entry)
            elif entry.is_file() or entry.is_symlink():
                yield entry


def is_backup(name: str) -> bool:
    return name.endswith(BAK_SUFFIXES) or any(m in name for m in BAK_MARKERS)


def clean_gitignore(root: Path, log: list) -> None:
    path = root / ".gitignore"
    if not path.exists():
        return
    seen = set()
    kept = []
    dropped = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            kept.append(line)
            continue
        if stripped in seen:
            dropped += 1
            continue
        seen.add(stripped)
        kept.append(line)
    text = re.sub(r"\n{3,}", "\n\n", "\n".join(kept).strip() + "\n")
    if dropped and APPLY:
        path.write_text(text, encoding="utf-8")
    if dropped:
        log.append("[gitignore] %d خط تکراری حذف شد" % dropped)


def main() -> int:
    root = repo_root()
    patch_dir = root / PATCH_DIR_NAME
    patch_dir.mkdir(parents=True, exist_ok=True)

    deleted = []
    moved = []
    notes = []

    for file in walk(root):
        if PATCH_DIR_NAME in file.as_posix():
            continue
        if is_backup(file.name):
            rel = file.relative_to(root).as_posix()
            if APPLY:
                file.unlink(missing_ok=True)
            deleted.append(rel)

    for file in sorted(root.glob("*.py")):
        if not file.name.startswith(SCRIPT_PREFIXES):
            continue
        twin = patch_dir / file.name
        if twin.exists():
            if twin.read_bytes() == file.read_bytes():
                if APPLY:
                    file.unlink()
                deleted.append(file.name + "  (کپی یکسان در " + PATCH_DIR_NAME + ")")
            else:
                notes.append(file.name + " با نسخه‌ی tools/patches فرق دارد؛ دست نزدم")
        else:
            if APPLY:
                file.replace(twin)
            moved.append(file.name + " -> " + PATCH_DIR_NAME + "/")

    clean_gitignore(root, notes)

    mode = "اجرا شد" if APPLY else "حالت آزمایشی (هیچ تغییری اعمال نشد)"
    print("=" * 60)
    print("ریشه‌ی پروژه: " + str(root))
    print("وضعیت: " + mode)
    print("=" * 60)
    print("")
    print("[1] فایل‌های پشتیبان — %d مورد" % len(deleted))
    for item in deleted:
        print("   x " + item)
    print("")
    print("[2] انتقال اسکریپت‌ها — %d مورد" % len(moved))
    for item in moved:
        print("   > " + item)
    if notes:
        print("")
        print("[3] یادداشت‌ها — %d مورد" % len(notes))
        for item in notes:
            print("   ! " + item)
    print("")
    print("=" * 60)
    if not APPLY:
        print("برای اجرای واقعی:  python3 tools/patches/cleanup_baks.py --apply")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
