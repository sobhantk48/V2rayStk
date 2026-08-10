#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""سیم‌کشی بازخورد لمسی به دکمه‌های اتصال/قطع VPN"""
import io, os, re, sys

ROOT = os.path.dirname(os.path.abspath(__file__))

def read(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()

def write(p, s):
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)
    print('  ✔ نوشته شد:', os.path.relpath(p, ROOT))

# ---------------------------------------------------------------- 1) haptics
HAPTICS = os.path.join(ROOT, 'lib/core/platform/haptics.dart')
src = read(HAPTICS)

if 'static Future<void> success()' not in src:
    extra = '''
  /// الگوی موفقیت: دو ضربهٔ کوتاه پشت سر هم.
  static Future<void> success() async {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    HapticFeedback.lightImpact();
  }

  /// الگوی خطا: سه ضربهٔ سنگین کوتاه.
  static Future<void> error() async {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    HapticFeedback.heavyImpact();
  }
'''
    idx = src.rstrip().rfind('}')
    src = src[:idx] + extra + '}\n'
    write(HAPTICS, src)
else:
    print('  → haptics.dart از قبل success/error دارد؛ رد شد.')

# ---------------------------------------------------------------- 2) home
HOME = os.path.join(ROOT, 'lib/features/home/presentation/home_screen.dart')
src = read(HOME)

if "core/platform/haptics.dart" not in src:
    src = src.replace(
        "import '../../../core/widgets/app_scaffold.dart';",
        "import '../../../core/platform/haptics.dart';\n"
        "import '../../../core/widgets/app_scaffold.dart';", 1)

old = """  try {
    if (state == VpnConnectionState.connected) {
      await controller.disconnect();
    } else {
      await controller.connect();
      await ref.read(vpnStatsProvider.notifier).refreshLatency();
    }
  } on SingBoxConfigException {
    messenger.showSnackBar(
      SnackBar(content: Text(strings.noProfileSelected)),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(strings.connectionFailed)),
    );
  }"""

new = """  final bool wasConnected = state == VpnConnectionState.connected;
  // بازخورد فوری لمس، مستقل از نتیجهٔ هسته.
  Haptics.medium();

  try {
    if (wasConnected) {
      await controller.disconnect();
      Haptics.light();
    } else {
      await controller.connect();
      unawaited(Haptics.success());
      await ref.read(vpnStatsProvider.notifier).refreshLatency();
    }
  } on SingBoxConfigException {
    unawaited(Haptics.error());
    messenger.showSnackBar(
      SnackBar(content: Text(strings.noProfileSelected)),
    );
  } catch (_) {
    unawaited(Haptics.error());
    messenger.showSnackBar(
      SnackBar(content: Text(strings.connectionFailed)),
    );
  }"""

# نرمال‌سازی فاصله‌ها برای اطمینان از تطبیق
def loose(t):
    return re.sub(r'\s+', ' ', t).strip()

if loose(old) in loose(src):
    # تطبیق دقیق با regex بر پایهٔ فاصلهٔ آزاد
    pat = re.compile(r'\s+'.join(map(re.escape, old.split())))
    src = pat.sub(lambda m: new, src, count=1)
    if 'dart:async' not in src:
        src = "import 'dart:async';\n\n" + src
    write(HOME, src)
else:
    print('  ✖ الگوی home_screen پیدا نشد!')
    sys.exit(1)

# ---------------------------------------------------------------- 3) dashboard
DASH = os.path.join(ROOT, 'lib/features/dashboard/presentation/dashboard_screen.dart')
src = read(DASH)

if "core/platform/haptics.dart" not in src:
    src = src.replace(
        "import '../../../core/widgets/app_scaffold.dart';",
        "import '../../../core/platform/haptics.dart';\n"
        "import '../../../core/widgets/app_scaffold.dart';", 1)

old2 = """  final VpnController controller = ref.read(vpnControllerProvider.notifier);
  try {
    if (state == VpnConnectionState.connected) {
      await controller.disconnect();
    } else if (state == VpnConnectionState.disconnected) {
      await controller.connect();
    }
  } catch (error) {
    if (!mounted) return;"""

new2 = """  final VpnController controller = ref.read(vpnControllerProvider.notifier);
  // بازخورد فوری لمس، مستقل از نتیجهٔ هسته.
  Haptics.medium();

  try {
    if (state == VpnConnectionState.connected) {
      await controller.disconnect();
      Haptics.light();
    } else if (state == VpnConnectionState.disconnected) {
      await controller.connect();
      unawaited(Haptics.success());
    }
  } catch (error) {
    unawaited(Haptics.error());
    if (!mounted) return;"""

if loose(old2) in loose(src):
    pat = re.compile(r'\s+'.join(map(re.escape, old2.split())))
    src = pat.sub(lambda m: new2, src, count=1)
    write(DASH, src)
else:
    print('  ✖ الگوی dashboard_screen پیدا نشد!')
    sys.exit(1)

print('\n✅ تمام. حالا format و analyze اجرا کن.')
