import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../profiles/application/profile_providers.dart';
import '../data/local_proxy_traffic_repository.dart';
import '../data/proxy_traffic_repository.dart';
import '../domain/proxy_traffic.dart';

final FutureProvider<ProxyTrafficRepository> proxyTrafficRepositoryProvider =
    FutureProvider<ProxyTrafficRepository>((Ref ref) async {
  final LocalStorageService storage =
      await ref.watch(localStorageProvider.future);
  return LocalProxyTrafficRepository(storage);
});

final AsyncNotifierProvider<ProxyTrafficNotifier, List<ProxyTraffic>>
    proxyTrafficProvider =
    AsyncNotifierProvider<ProxyTrafficNotifier, List<ProxyTraffic>>(
  ProxyTrafficNotifier.new,
);

class ProxyTrafficNotifier extends AsyncNotifier<List<ProxyTraffic>> {
  Future<ProxyTrafficRepository> get _repository =>
      ref.read(proxyTrafficRepositoryProvider.future);

  @override
  Future<List<ProxyTraffic>> build() async {
    final ProxyTrafficRepository repository = await _repository;
    return repository.getAll();
  }

  Future<void> _refresh() async {
    final ProxyTrafficRepository repository = await _repository;
    state = AsyncValue<List<ProxyTraffic>>.data(await repository.getAll());
  }

  /// یک اتصال موفق را ثبت می‌کند (شمارنده اتصال + زمان آخرین استفاده).
  Future<void> recordConnect(String profileId) async {
    final ProxyTrafficRepository repository = await _repository;
    await repository.addUsage(
      profileId: profileId,
      markConnected: true,
    );
    await _refresh();
  }

  Future<void> recordUsage({
    required String profileId,
    int uploadBytes = 0,
    int downloadBytes = 0,
    int durationSeconds = 0,
    int? pingMs,
  }) async {
    final ProxyTrafficRepository repository = await _repository;
    await repository.addUsage(
      profileId: profileId,
      uploadBytes: uploadBytes,
      downloadBytes: downloadBytes,
      durationSeconds: durationSeconds,
      pingMs: pingMs,
    );
    await _refresh();
  }

  Future<void> reset(String profileId) async {
    final ProxyTrafficRepository repository = await _repository;
    await repository.reset(profileId);
    await _refresh();
  }

  Future<void> resetAll() async {
    final ProxyTrafficRepository repository = await _repository;
    await repository.resetAll();
    await _refresh();
  }

  ProxyTraffic statsFor(String profileId) {
    final List<ProxyTraffic> items = state.value ?? <ProxyTraffic>[];
    return items.firstWhere(
      (ProxyTraffic item) => item.profileId == profileId,
      orElse: () => ProxyTraffic(profileId: profileId),
    );
  }
}
