import 'package:flutter/services.dart';

class VpnPlatformService {
  static const MethodChannel _channel =
      MethodChannel('com.example.v2ray_stk/vpn');

  Future<String> getStatus() async {
    final String? status = await _channel.invokeMethod<String>('getStatus');
    return status ?? 'disconnected';
  }

  Future<void> connect(
    String config, {
    bool torEnabled = false,
    bool killSwitch = false,
    bool alwaysOnVpn = false,
  }) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
        'torEnabled': torEnabled,
        'killSwitch': killSwitch,
        'alwaysOnVpn': alwaysOnVpn,
      },
    );
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod<void>('disconnect');
  }

  Future<Map<String, dynamic>> getStats() async {
    final Map<dynamic, dynamic>? raw =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('getStats');
    if (raw == null) {
      return <String, dynamic>{};
    }
    return raw.map<String, dynamic>(
      (dynamic key, dynamic value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }

  Future<int> testLatency([
    String host = '1.1.1.1',
    int port = 443,
  ]) async {
    final int? result = await _channel.invokeMethod<int>(
      'testLatency',
      <String, dynamic>{'host': host, 'port': port},
    );
    return result ?? -1;
  }
}
