#!/usr/bin/env python3
import io, re

p = 'lib/features/settings/application/app_settings.dart'
with io.open(p, 'r', encoding='utf-8') as f:
    s = f.read()

if 'Haptics.enabled = state.hapticEnabled;' in s:
    print("SKIP: already synced")
else:
    # داخل متد load، بعد از آخرین state = ... مقداردهی می‌کنیم
    m = re.search(r'(Future<void>\s+load\(\)\s+async\s*\{)(.*?)(\n\s*\})', s, flags=re.S)
    if not m:
        print("WARN: load() not found — بفرست تا دستی بزنم")
    else:
        body = m.group(2)
        new_body = body.rstrip() + "\n    Haptics.enabled = state.hapticEnabled;"
        s = s[:m.start(2)] + new_body + s[m.end(2):]
        with io.open(p, 'w', encoding='utf-8') as f:
            f.write(s)
        print("PATCHED: load() sync added")
