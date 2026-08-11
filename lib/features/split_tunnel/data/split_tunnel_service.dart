import 'package:flutter/services.dart';

import '../domain/installed_app.dart';

class SplitTunnelService {
  const SplitTunnelService();

  static const MethodChannel _channel = MethodChannel('com.v2ray.stk/vpn');

  Future<List<InstalledApp>> loadApps({bool withIcons = true}) async {
    final List<Object?>? raw = await _channel.invokeMethod<List<Object?>>(
      'getInstalledApps',
      <String, Object?>{'withIcons': withIcons},
    );
    if (raw == null) return const <InstalledApp>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map(InstalledApp.fromMap)
        .where((InstalledApp app) => app.packageName.isNotEmpty)
        .toList(growable: false);
  }

  Future<SplitTunnelConfig> load() async {
    final Map<Object?, Object?>? raw =
        await _channel.invokeMethod<Map<Object?, Object?>>('getSplitTunnel');
    if (raw == null) return const SplitTunnelConfig();
    final Object? apps = raw['apps'];
    return SplitTunnelConfig(
      mode: SplitMode.fromWire(raw['mode'] as String?),
      apps: apps is List ? apps.whereType<String>().toSet() : const <String>{},
    );
  }

  Future<void> save(SplitTunnelConfig config) async {
    await _channel.invokeMethod<void>(
      'setSplitTunnel',
      <String, Object?>{
        'mode': config.mode.wire,
        'apps': config.apps.toList(growable: false),
      },
    );
  }
}
