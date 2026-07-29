import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profile_providers.dart';
import '../data/local_proxy_traffic_repository.dart';
import '../data/proxy_traffic_repository.dart';
import '../domain/proxy_traffic.dart';

final FutureProvider<ProxyTrafficRepository> proxyTrafficRepositoryProvider =
    FutureProvider<ProxyTrafficRepository>((Ref ref) async {
  final localStorage = await ref.watch(localStorageProvider.future);
  return LocalProxyTrafficRepository(localStorage);
});

class ProxyTrafficNotifier extends AsyncNotifier<List<ProxyTraffic>> {
  @override
  Future<List<ProxyTraffic>> build() async {
    final ProxyTrafficRepository repository =
        await ref.watch(proxyTrafficRepositoryProvider.future);
    return repository.getAll();
  }

  Future<ProxyTrafficRepository> get _repository =>
      ref.read(proxyTrafficRepositoryProvider.future);

  Future<void> _refresh() async {
    final ProxyTrafficRepository repository = await _repository;
    state = AsyncValue<List<ProxyTraffic>>.data(await repository.getAll());
  }

  Future<void> recordConnect(String profileId) async {
    final ProxyTrafficRepository repository = await _repository;
    await repository.addUsage(profileId: profileId, markConnected: true);
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
    final List<ProxyTraffic> items =
        state.valueOrNull ?? const <ProxyTraffic>[];

    return items.firstWhere(
      (ProxyTraffic item) => item.profileId == profileId,
      orElse: () => ProxyTraffic(profileId: profileId),
    );
  }
}

final AsyncNotifierProvider<ProxyTrafficNotifier, List<ProxyTraffic>>
    proxyTrafficProvider =
    AsyncNotifierProvider<ProxyTrafficNotifier, List<ProxyTraffic>>(
  ProxyTrafficNotifier.new,
);
