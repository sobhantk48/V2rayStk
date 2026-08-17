#!/usr/bin/env python3
"""
release_110.py
تمیزکاری نهایی ورک‌اسپیس + بامپ نسخه به 1.1.0+10 برای تگ v1.1.0

کارهایی که انجام می‌دهد:
  1. حذف تمام فایل‌های پشتیبان (*.bak و *.bak_YYYYMMDD_HHMMSS)
  2. یکپارچه‌سازی اسکریپت‌های پچ: هر *.py ریشه که در tools/patches
     همنام دارد حذف می‌شود، بقیه به tools/patches منتقل می‌شوند
  3. بامپ نسخه در pubspec.yaml به 1.1.0+10
  4. اطمینان از وجود الگوهای لازم در .gitignore
  5. حذف پوشه‌های کش موقت پایتون (__pycache__)

اجرا:
    python3 tools/patches/release_110.py
    python3 tools/patches/release_110.py --dry-run   # فقط گزارش، بدون تغییر
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

# ---------------------------------------------------------------- تنظیمات

NEW_VERSION = "1.1.0"
NEW_BUILD = "10"

# فایل‌های پایتون ریشه که نباید جابه‌جا یا حذف شوند
ROOT_PY_KEEP = {
    "fast_build.py",
    "setup.py",
    "conftest.py",
}

# الگوهای فایل پشتیبان
BAK_GLOBS = (
    "**/*.bak",
    "**/*.bak_*",
    "**/*.orig",
    "**/*.rej",
)

# مسیرهایی که هرگز پیمایش نمی‌شوند
SKIP_DIRS = {
    ".git",
    ".dart_tool",
    "build",
    ".gradle",
    "node_modules",
    ".idea",
}

# خطوطی که باید در .gitignore باشند
GITIGNORE_REQUIRED = [
    "# --- backups & archives ---",
    "*.bak",
    "*.bak_*",
    "*.orig",
    "*.rej",
    "V2rayStk_source_new.zip",
    "*.zip",
    "__pycache__/",
    "*.pyc",
]

GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CYAN = "\033[96m"
BOLD = "\033[1m"
OFF = "\033[0m"


def info(msg: str) -> None:
    print(f"{CYAN}•{OFF} {msg}")


def ok(msg: str) -> None:
    print(f"{GREEN}✓{OFF} {msg}")


def warn(msg: str) -> None:
    print(f"{YELLOW}!{OFF} {msg}")


def fail(msg: str) -> None:
    print(f"{RED}✗{OFF} {msg}")


def is_skipped(path: Path, root: Path) -> bool:
    """آیا مسیر داخل یکی از پوشه‌های نادیده‌گرفته‌شده است؟"""
    try:
        parts = path.relative_to(root).parts
    except ValueError:
        return True
    return any(part in SKIP_DIRS for part in parts)


# ---------------------------------------------------------------- گام‌ها


def find_repo_root() -> Path:
    """ریشه پروژه را پیدا می‌کند: پوشه‌ای که هم .git دارد هم pubspec.yaml."""
    here = Path.cwd().resolve()
    for candidate in (here, *here.parents):
        if (candidate / ".git").exists() and (candidate / "pubspec.yaml").is_file():
            return candidate
    fail("ریشه پروژه پیدا نشد (پوشه‌ای با .git و pubspec.yaml لازم است).")
    fail("اول این را اجرا کن:  cd ~/development/V2rayStk")
    sys.exit(1)


def step_remove_backups(root: Path, dry: bool) -> list[Path]:
    """تمام فایل‌های پشتیبان را حذف می‌کند."""
    print(f"\n{BOLD}[1/5] حذف فایل‌های پشتیبان{OFF}")
    found: set[Path] = set()
    for pattern in BAK_GLOBS:
        for path in root.glob(pattern):
            if path.is_file() and not is_skipped(path, root):
                found.add(path)

    removed = sorted(found)
    if not removed:
        ok("هیچ فایل پشتیبانی باقی نمانده بود.")
        return []

    for path in removed:
        rel = path.relative_to(root)
        size_kb = path.stat().st_size / 1024
        print(f"    - {rel}  ({size_kb:.1f} KB)")
        if not dry:
            path.unlink()
    ok(f"{len(removed)} فایل پشتیبان حذف شد.")
    return removed


def step_consolidate_scripts(root: Path, dry: bool) -> tuple[list[Path], list[Path]]:
    """اسکریپت‌های پچ ریشه را در tools/patches یکپارچه می‌کند."""
    print(f"\n{BOLD}[2/5] یکپارچه‌سازی اسکریپت‌های پچ{OFF}")
    target_dir = root / "tools" / "patches"
    if not dry:
        target_dir.mkdir(parents=True, exist_ok=True)

    deleted: list[Path] = []
    moved: list[Path] = []

    for path in sorted(root.glob("*.py")):
        if not path.is_file() or path.name in ROOT_PY_KEEP:
            continue
        twin = target_dir / path.name
        if twin.is_file():
            print(f"    - تکراری، حذف: {path.name}")
            if not dry:
                path.unlink()
            deleted.append(path)
        else:
            print(f"    → انتقال: {path.name}  ->  tools/patches/")
            if not dry:
                shutil.move(str(path), str(twin))
            moved.append(path)

    if not deleted and not moved:
        ok("ریشه پروژه از قبل تمیز بود.")
    else:
        ok(f"{len(deleted)} تکراری حذف شد، {len(moved)} فایل منتقل شد.")
    return deleted, moved


def step_bump_version(root: Path, dry: bool) -> bool:
    """نسخه pubspec.yaml را به NEW_VERSION+NEW_BUILD تغییر می‌دهد."""
    print(f"\n{BOLD}[3/5] بامپ نسخه در pubspec.yaml{OFF}")
    pubspec = root / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")

    pattern = re.compile(r"^version:\s*(.+?)\s*$", re.MULTILINE)
    match = pattern.search(text)
    if not match:
        fail("خط version در pubspec.yaml پیدا نشد. دستی بررسی کن.")
        return False

    old = match.group(1)
    new = f"{NEW_VERSION}+{NEW_BUILD}"
    if old == new:
        ok(f"نسخه از قبل {new} است.")
        return True

    print(f"    نسخه قبلی: {old}")
    print(f"    نسخه جدید: {new}")
    if not dry:
        pubspec.write_text(pattern.sub(f"version: {new}", text, count=1), encoding="utf-8")
    ok(f"versionName -> {NEW_VERSION} , versionCode -> {NEW_BUILD}")
    return True


def step_fix_gitignore(root: Path, dry: bool) -> list[str]:
    """الگوهای لازم را به .gitignore اضافه می‌کند (بدون تکرار)."""
    print(f"\n{BOLD}[4/5] بررسی .gitignore{OFF}")
    gi = root / ".gitignore"
    lines = gi.read_text(encoding="utf-8").splitlines() if gi.is_file() else []
    existing = {line.strip() for line in lines}

    added = [item for item in GITIGNORE_REQUIRED if item.strip() not in existing]
    if not added:
        ok("همه الگوهای لازم موجود بودند.")
        return []

    for item in added:
        if not item.startswith("#"):
            print(f"    + {item}")
    if not dry:
        body = "\n".join(lines).rstrip("\n")
        block = "\n".join(added)
        gi.write_text(f"{body}\n\n{block}\n", encoding="utf-8")
    ok(f"{len([a for a in added if not a.startswith('#')])} الگو اضافه شد.")
    return added


def step_clear_pycache(root: Path, dry: bool) -> int:
    """پوشه‌های __pycache__ را پاک می‌کند."""
    print(f"\n{BOLD}[5/5] پاک‌سازی __pycache__{OFF}")
    count = 0
    for path in root.glob("**/__pycache__"):
        if path.is_dir() and not is_skipped(path, root):
            print(f"    - {path.relative_to(root)}")
            if not dry:
                shutil.rmtree(path, ignore_errors=True)
            count += 1
    if count == 0:
        ok("کشی وجود نداشت.")
    else:
        ok(f"{count} پوشه کش حذف شد.")
    return count


# ---------------------------------------------------------------- main


def main() -> int:
    parser = argparse.ArgumentParser(description="تمیزکاری و بامپ نسخه V2rayStk")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="فقط گزارش بده، هیچ فایلی را تغییر نده",
    )
    args = parser.parse_args()

    root = find_repo_root()
    print(f"{BOLD}ریشه پروژه:{OFF} {root}")
    if args.dry_run:
        warn("حالت آزمایشی: هیچ تغییری روی دیسک اعمال نمی‌شود.")

    baks = step_remove_backups(root, args.dry_run)
    deleted, moved = step_consolidate_scripts(root, args.dry_run)
    bumped = step_bump_version(root, args.dry_run)
    gitignore_added = step_fix_gitignore(root, args.dry_run)
    caches = step_clear_pycache(root, args.dry_run)

    print(f"\n{BOLD}{'=' * 52}{OFF}")
    print(f"{BOLD}خلاصه{OFF}")
    print(f"{'=' * 52}")
    print(f"  فایل پشتیبان حذف‌شده : {len(baks)}")
    print(f"  اسکریپت تکراری حذف   : {len(deleted)}")
    print(f"  اسکریپت منتقل‌شده    : {len(moved)}")
    print(f"  نسخه                : {NEW_VERSION}+{NEW_BUILD} " + ("(اعمال شد)" if bumped else "(خطا)"))
    print(f"  الگوی gitignore     : {len([a for a in gitignore_added if not a.startswith('#')])}")
    print(f"  پوشه کش حذف‌شده     : {caches}")
    print(f"{'=' * 52}\n")

    if args.dry_run:
        warn("برای اعمال واقعی، بدون --dry-run اجرا کن.")
    else:
        ok("تمیزکاری تمام شد. مرحله بعد: flutter analyze و flutter test")
    return 0 if bumped else 1


if __name__ == "__main__":
    sys.exit(main())
