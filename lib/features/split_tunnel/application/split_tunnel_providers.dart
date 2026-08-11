import 'package:flutter_riverpod/flutter_riverpod.dart';

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
