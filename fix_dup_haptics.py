#!/usr/bin/env python3
import os, re, io

def read(p):
    with io.open(p,'r',encoding='utf-8') as f: return f.read()
def write(p,s):
    with io.open(p,'w',encoding='utf-8') as f: f.write(s)
    print("WROTE:", p)

# 1) حذف فایل تکراری
dup = 'lib/core/haptics/haptics.dart'
if os.path.exists(dup):
    os.remove(dup)
    print("REMOVED:", dup)
    try:
        os.rmdir('lib/core/haptics')
        print("REMOVED DIR: lib/core/haptics")
    except OSError:
        pass

# 2) پاکسازی importهای اضافه در settings_screen
p = 'lib/features/settings/presentation/settings_screen.dart'
s = read(p)
s = s.replace("import '../../../core/haptics/haptics.dart';\n", "")
s = s.replace("import 'package:flutter/services.dart';\n", "")
write(p, s)

# 3) اصلاح import در app_settings به مسیر درست
p = 'lib/features/settings/application/app_settings.dart'
s = read(p)
s = s.replace("import '../../../core/haptics/haptics.dart';",
              "import '../../../core/platform/haptics.dart';")
write(p, s)
print("DONE")
