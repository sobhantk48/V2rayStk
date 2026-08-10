#!/usr/bin/env python3
import io

p = 'lib/features/settings/application/app_settings.dart'
with io.open(p, 'r', encoding='utf-8') as f:
    s = f.read()

marker = 'Haptics.enabled = state.hapticEnabled;'
if marker in s:
    print("SKIP: already synced")
    raise SystemExit(0)

anchor = 'Future<void> _load() async {'
i = s.find(anchor)
if i == -1:
    print("WARN: _load() anchor not found")
    raise SystemExit(1)

# شمارش آکولاد از ابتدای بدنه تا بسته شدن متد
start = i + len(anchor) - 1   # روی '{'
depth = 0
end = -1
for j in range(start, len(s)):
    if s[j] == '{':
        depth += 1
    elif s[j] == '}':
        depth -= 1
        if depth == 0:
            end = j
            break

if end == -1:
    print("WARN: closing brace not found")
    raise SystemExit(1)

s = s[:end] + "    " + marker + "\n  " + s[end:]
with io.open(p, 'w', encoding='utf-8') as f:
    f.write(s)
print("PATCHED: _load() sync added at offset", end)
