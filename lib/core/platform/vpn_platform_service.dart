import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

class VpnPlatformService {
  VpnPlatformService()
      : _channel = const MethodChannel(AppConstants.vpnChannelName);

  final MethodChannel _channel;

  Future<String> getStatus() async {
    final String? result = await _channel.invokeMethod<String>('getStatus');
    return result ?? 'disconnected';
  }

  /// کانفیگ JSON هسته sing-box را به سرویس نیتیو می‌فرستد.
  /// کلید `config` باید با `call.argument<String>("config")` در
  /// MainActivity.kt یکسان بماند.
  /// کلید `torEnabled` هم‌نام با call.argument<Boolean>("torEnabled") است
  /// و مشخص می‌کند دیمون Tor در سرویس نیتیو اجرا شود یا نه.
  Future<void> connect(String config, {bool torEnabled = false}) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
        'torEnabled': torEnabled,
      },
    );
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
  }

  /// آمار لحظه‌ای هسته. تا وقتی سمت نیتیو پیاده نشده null برمی‌گردد
  /// و UI بدون کرش با مقادیر صفر کار می‌کند.
  Future<Map<String, dynamic>?> getStats() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getStats');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<int?> testLatency() async {
    try {
      return await _channel.invokeMethod<int>('testLatency');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
