#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پاکسازی پچ خراب Kill Switch در vpn_controller.dart"""
import pathlib, shutil, sys

p = pathlib.Path('lib/features/vpn/application/vpn_controller.dart')
if not p.exists():
    sys.exit('!! فایل پیدا نشد: %s' % p)

src = p.read_text(encoding='utf-8')
shutil.copy(str(p), str(p) + '.bak_ksfix')
print('[+] بکاپ: %s.bak_ksfix' % p)

# ---------- گام ۱: حذف آرگومان تکراری killSwitch ----------
lines = src.split('\n')
kept = [l for l in lines if l.strip() != 'killSwitch: await _isKillSwitchEnabled(),']
n_removed = len(lines) - len(kept)
src = '\n'.join(kept)
print('[+] گام ۱: %d خط killSwitch تکراری حذف شد' % n_removed)

# ---------- گام ۲: بازسازی متد _isTorEnabled و حذف متد تودرتو ----------
START = '  Future<bool> _isTorEnabled() async {'
END   = '  /// تنظیمات Kill Switch'

i = src.find(START)
j = src.find(END)

CLEAN = '''  Future<bool> _isTorEnabled() async {
    try {
      final AdminSettings settings = await _reader.read();
      return settings.torEnabled;
    } catch (_) {
      return false;
    }
  }

'''

if i == -1:
    print('[!] گام ۲: _isTorEnabled پیدا نشد (شاید قبلاً درست شده)')
elif j == -1 or j <= i:
    print('[!] گام ۲: مرز پایانی پیدا نشد - دستی بررسی کن')
else:
    broken = src[i:j]
    if '_isKillSwitchEnabled' in broken:
        src = src[:i] + CLEAN + src[j:]
        print('[+] گام ۲: _isTorEnabled بازسازی و _isKillSwitchEnabled زائد حذف شد')
    else:
        print('[=] گام ۲: بلاک سالم است، تغییری لازم نبود')

# ---------- گام ۳: بررسی موازنه آکولاد ----------
op, cl = src.count('{'), src.count('}')
print('[i] آکولاد باز: %d | بسته: %d | اختلاف: %d' % (op, cl, op - cl))
if op != cl:
    print('[!] هشدار: آکولادها نامتوازن‌اند!')

# ---------- گام ۴: بررسی باقیمانده ----------
if '_isKillSwitchEnabled' in src:
    print('[!] هنوز ردی از _isKillSwitchEnabled هست:')
    for k, l in enumerate(src.split('\n'), 1):
        if '_isKillSwitchEnabled' in l:
            print('    خط %d: %s' % (k, l.strip()))
else:
    print('[+] گام ۴: هیچ ردی از _isKillSwitchEnabled نمانده')

p.write_text(src, encoding='utf-8')
print('\n[OK] فایل ذخیره شد. حالا بزن: flutter analyze')
