import 'package:flutter/services.dart';

/// هلپر مرکزی بازخورد لمسی. با توجه به تنظیم کاربر لرزش می‌دهد.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

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
}
