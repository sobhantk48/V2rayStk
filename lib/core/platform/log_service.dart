import 'package:flutter/services.dart';

/// سرویس خواندن لاگ‌های native از طریق MethodChannel
class NativeLogService {
  NativeLogService._();

  static const _channel = MethodChannel('com.v2ray.stk/native_log');

  /// بازگشت لیست خطوط لاگ
  /// اگر [onlyVpn] true باشد فقط لاگ‌های مرتبط با هسته نشان داده می‌شود
  static Future<List<String>> dump({bool onlyVpn = true}) async {
    try {
      final raw = await _channel.invokeMethod<String>(
        'dump',
        <String, dynamic>{'onlyVpn': onlyVpn},
      );
      if (raw == null || raw.isEmpty) return [];
      return raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    } on PlatformException catch (e) {
      return ['[Error] ${e.code}: ${e.message}'];
    } on MissingPluginException {
      return ['[Error] کانال native_log ثبت نشده — بیلد را تجدید کنید'];
    }
  }

  /// پاک کردن logcat
  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<bool>('clear');
    } catch (_) {}
  }
}
