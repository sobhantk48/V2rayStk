import 'package:flutter/services.dart';

class VpnPlatformService {
  static const MethodChannel _channel =
      MethodChannel('com.v2ray.stk/vpn');

  Future<String> getStatus() async {
    final String? status = await _channel.invokeMethod<String>('getStatus');
    return status ?? 'disconnected';
  }

  // XRAY_BRIDGE_V1
  Future<void> connect(
    String config, {
    bool torEnabled = false,
    bool killSwitch = false,
    bool alwaysOnVpn = false,
    String xrayConfig = '',
  }) async {
    await _channel.invokeMethod<void>(
      'connect',
      <String, dynamic>{
        'config': config,
        'torEnabled': torEnabled,
        'killSwitch': killSwitch,
        'alwaysOnVpn': alwaysOnVpn,
        'xrayConfig': xrayConfig,
      },
    );
  }

  /// XRAY_BRIDGE_V1: نسخه هسته Xray؛ null یعنی باینری در دسترس نیست.
  Future<String?> xrayVersion() async {
    try {
      return await _channel.invokeMethod<String>('xrayVersion');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
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

  // SPLIT_BRIDGE_V1
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    final List<dynamic>? apps =
        await _channel.invokeMethod<List<dynamic>>('getInstalledApps');
    if (apps == null) return <Map<String, dynamic>>[];
    return apps
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> setSplitTunnel(String mode, List<String> apps) async {
    await _channel.invokeMethod<void>(
      'setSplitTunnel',
      <String, dynamic>{'mode': mode, 'apps': apps},
    );
  }

  Future<Map<String, dynamic>> getSplitTunnel() async {
    final Map<dynamic, dynamic>? data = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('getSplitTunnel');
    if (data == null) {
      return <String, dynamic>{'mode': 'off', 'apps': <String>[]};
    }
    return data.map((k, v) => MapEntry(k.toString(), v));
  }
}
