#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Split Tunneling - Flutter layer + Manifest"""
import os, shutil, time

ROOT = os.getcwd()
BAK = os.path.join(ROOT, ".trash_bak")
os.makedirs(BAK, exist_ok=True)
STAMP = time.strftime("%Y%m%d-%H%M%S")

def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()

def write(p, s, backup=True):
    if backup and os.path.exists(p):
        shutil.copy2(p, os.path.join(BAK, os.path.basename(p) + ".bak_split_" + STAMP))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(s)
    print("  OK", os.path.relpath(p, ROOT))

# ---------------------------------------------------------- 1) domain model
write(os.path.join(ROOT, "lib/features/split_tunnel/domain/installed_app.dart"), r'''import 'dart:typed_data';

import 'package:flutter/foundation.dart';

enum SplitMode {
  off('off'),
  exclude('exclude'),
  include('include');

  const SplitMode(this.wire);

  final String wire;

  static SplitMode fromWire(String? value) {
    switch (value) {
      case 'exclude':
        return SplitMode.exclude;
      case 'include':
        return SplitMode.include;
      default:
        return SplitMode.off;
    }
  }
}

@immutable
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.name,
    required this.isSystem,
    this.icon,
  });

  final String packageName;
  final String name;
  final bool isSystem;
  final Uint8List? icon;

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    final Object? rawIcon = map['icon'];
    return InstalledApp(
      packageName: (map['packageName'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      isSystem: (map['isSystem'] as bool?) ?? false,
      icon: rawIcon is Uint8List
          ? rawIcon
          : (rawIcon is List<int> ? Uint8List.fromList(rawIcon) : null),
    );
  }

  bool matches(String query) {
    if (query.isEmpty) return true;
    final String q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        packageName.toLowerCase().contains(q);
  }
}

@immutable
class SplitTunnelConfig {
  const SplitTunnelConfig({
    this.mode = SplitMode.off,
    this.apps = const <String>{},
  });

  final SplitMode mode;
  final Set<String> apps;

  SplitTunnelConfig copyWith({SplitMode? mode, Set<String>? apps}) =>
      SplitTunnelConfig(mode: mode ?? this.mode, apps: apps ?? this.apps);
}
''')

# ---------------------------------------------------------- 2) native service
write(os.path.join(ROOT, "lib/features/split_tunnel/data/split_tunnel_service.dart"), r'''import 'package:flutter/services.dart';

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
''')

# ---------------------------------------------------------- 3) providers
write(os.path.join(ROOT, "lib/features/split_tunnel/application/split_tunnel_providers.dart"), r'''import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/split_tunnel_service.dart';
import '../domain/installed_app.dart';

final Provider<SplitTunnelService> splitTunnelServiceProvider =
    Provider<SplitTunnelService>((Ref ref) => const SplitTunnelService());

final FutureProvider<List<InstalledApp>> installedAppsProvider =
    FutureProvider<List<InstalledApp>>((Ref ref) async {
  return ref.read(splitTunnelServiceProvider).loadApps();
});

class SplitTunnelNotifier extends AsyncNotifier<SplitTunnelConfig> {
  SplitTunnelService get _service => ref.read(splitTunnelServiceProvider);

  @override
  Future<SplitTunnelConfig> build() => _service.load();

  Future<void> _apply(SplitTunnelConfig next) async {
    state = AsyncValue<SplitTunnelConfig>.data(next);
    await _service.save(next);
  }

  Future<void> setMode(SplitMode mode) async {
    final SplitTunnelConfig current = state.value ?? const SplitTunnelConfig();
    await _apply(current.copyWith(mode: mode));
  }

  Future<void> toggleApp(String packageName) async {
    final SplitTunnelConfig current = state.value ?? const SplitTunnelConfig();
    final Set<String> apps = Set<String>.of(current.apps);
    if (!apps.remove(packageName)) apps.add(packageName);
    await _apply(current.copyWith(apps: apps));
  }

  Future<void> clearAll() async {
    final SplitTunnelConfig current = state.value ?? const SplitTunnelConfig();
    await _apply(current.copyWith(apps: const <String>{}));
  }

  Future<void> selectAll(Iterable<String> packages) async {
    final SplitTunnelConfig current = state.value ?? const SplitTunnelConfig();
    await _apply(current.copyWith(apps: packages.toSet()));
  }
}

final AsyncNotifierProvider<SplitTunnelNotifier, SplitTunnelConfig>
    splitTunnelProvider =
    AsyncNotifierProvider<SplitTunnelNotifier, SplitTunnelConfig>(
        SplitTunnelNotifier.new);
''')

# ---------------------------------------------------------- 4) manifest
MANIFEST = os.path.join(ROOT, "android/app/src/main/AndroidManifest.xml")
if os.path.exists(MANIFEST):
    s = read(MANIFEST)
    changed = False
    if 'QUERY_ALL_PACKAGES' not in s:
        if 'xmlns:tools=' not in s:
            s = s.replace(
                '<manifest',
                '<manifest xmlns:tools="http://schemas.android.com/tools"',
                1,
            )
        perm = ('    <uses-permission '
                'android:name="android.permission.QUERY_ALL_PACKAGES" '
                'tools:ignore="QueryAllPackagesPermission" />\n')
        idx = s.find('<application')
        if idx != -1:
            line_start = s.rfind('\n', 0, idx) + 1
            s = s[:line_start] + perm + '\n' + s[line_start:]
            changed = True
    if changed:
        write(MANIFEST, s)
        print("  OK manifest updated")
    else:
        print("  -- manifest already has QUERY_ALL_PACKAGES")
else:
    print("  !! manifest not found")

print("\nDONE: Flutter layer + manifest ready.")
