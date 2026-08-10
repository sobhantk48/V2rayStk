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
}
