import 'package:flutter/services.dart';

class VpnBridge {
  static const _channel = MethodChannel('v2ray_stk/vpn');
  static Future<void> setEnabled(bool enabled) =>
      _channel.invokeMethod('setEnabled', {'enabled': enabled});
  static Future<void> setTor(bool enabled) =>
      _channel.invokeMethod('setTor', {'enabled': enabled});
  static Future<Map<dynamic, dynamic>> stats() => _channel.invokeMethod('stats');
}
