#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""رفع خطای Unresolved reference 'tunFd' در V2rayVpnService.kt"""
import re, sys, shutil, os

PATH = "android/app/src/main/kotlin/com/example/v2ray_stk/vpn/V2rayVpnService.kt"

if not os.path.exists(PATH):
    sys.exit("[error] فایل پیدا نشد: " + PATH)

src = open(PATH, encoding="utf-8").read()

if "tunFd" not in src:
    print("[skip] هیچ ارجاعی به tunFd نیست؛ فایل از قبل سالم است.")
    sys.exit(0)

shutil.copy(PATH, PATH + ".tunfd.bak")
print("[backup] " + PATH + ".tunfd.bak")

NEW_FUNC = '''    @Synchronized
    private fun closeTunFd() {
        val pending = pendingTun
        val active = tunInterface
        pendingTun = null
        tunInterface = null
        if (pending != null) {
            runCatching { pending.close() }
                .onSuccess { Log.i(TAG, "pendingTun closed") }
                .onFailure { Log.w(TAG, "pendingTun close failed: ${it.message}") }
        }
        if (active != null) {
            runCatching { active.close() }
                .onSuccess { Log.i(TAG, "tunInterface closed") }
                .onFailure { Log.w(TAG, "tunInterface close failed: ${it.message}") }
        }
    }
'''

# پیدا کردن بلوک تابع closeTunFd (با یا بدون @Synchronized)
pattern = re.compile(
    r'[ \t]*(?:@Synchronized[ \t]*\r?\n)?[ \t]*private fun closeTunFd\(\)[ \t]*\{.*?\n[ \t]*\}[ \t]*\r?\n',
    re.DOTALL,
)
m = pattern.search(src)
if not m:
    sys.exit("[error] بلوک closeTunFd پیدا نشد؛ دستی بررسی کن.")

src = src[:m.start()] + NEW_FUNC + src[m.end():]
print("[ok] بدنه closeTunFd بازنویسی شد")

if "tunFd" in src.replace("closeTunFd", ""):
    print("[warn] هنوز ارجاع tunFd باقی است:")
    for i, ln in enumerate(src.splitlines(), 1):
        if "tunFd" in ln.replace("closeTunFd", ""):
            print("   %d: %s" % (i, ln.strip()))

open(PATH, "w", encoding="utf-8").write(src)
print("[done] فایل ذخیره شد (%d خط)" % len(src.splitlines()))
