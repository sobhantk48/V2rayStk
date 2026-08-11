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
