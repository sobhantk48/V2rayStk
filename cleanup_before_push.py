#!/usr/bin/env python3
"""حذف فایل یتیم log_viewer_screen.dart و تمام .bak ها قبل از commit."""
import subprocess
from pathlib import Path

ROOT = Path.cwd()
ORPHAN = ROOT / "lib/features/logs/presentation/log_viewer_screen.dart"


def is_referenced(class_name: str, filename: str) -> bool:
    """آیا کلاس یا فایل جایی در lib/ (غیر از خودش و .bak) استفاده شده؟"""
    for dart in ROOT.joinpath("lib").rglob("*.dart"):
        if dart.name == filename or dart.suffix == ".bak":
            continue
        try:
            text = dart.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if class_name in text or filename in text:
            print(f"  [!] ارجاع پیدا شد در: {dart.relative_to(ROOT)}")
            return True
    return False


def main() -> None:
    removed = []

    # 1) فایل یتیم، فقط اگر واقعا ارجاعی نداشته باشد
    print("[1] بررسی log_viewer_screen.dart ...")
    if ORPHAN.exists():
        if is_referenced("LogViewerScreen", "log_viewer_screen.dart"):
            print("  [skip] ارجاع دارد؛ حذف نشد.")
        else:
            ORPHAN.unlink()
            removed.append(ORPHAN)
            print("  [ok] حذف شد (یتیم بود).")
    else:
        print("  [skip] از قبل وجود ندارد.")

    # 2) همه فایل های پشتیبان
    print("[2] حذف فایل های .bak ...")
    patterns = ("*.bak", "*.bak.*", "*.qs.bak", "*.gap.bak")
    seen = set()
    for pat in patterns:
        for f in ROOT.rglob(pat):
            if ".git/" in str(f) or f in seen:
                continue
            seen.add(f)
            f.unlink()
            removed.append(f)
            print(f"  [ok] {f.relative_to(ROOT)}")

    if not removed:
        print("\n[=] چیزی برای حذف نبود.")
        return

    print(f"\n[+] مجموعا {len(removed)} فایل حذف شد.")

    # 3) جلوگیری از برگشت .bak ها
    gitignore = ROOT / ".gitignore"
    lines = gitignore.read_text(encoding="utf-8").splitlines() if gitignore.exists() else []
    added = [p for p in ("*.bak", "*.bak.*") if p not in lines]
    if added:
        with gitignore.open("a", encoding="utf-8") as fh:
            fh.write("\n# backup files from patch scripts\n")
            fh.write("\n".join(added) + "\n")
        print(f"[3] به .gitignore اضافه شد: {', '.join(added)}")

    subprocess.run(["git", "status", "--short"], check=False)


if __name__ == "__main__":
    main()
