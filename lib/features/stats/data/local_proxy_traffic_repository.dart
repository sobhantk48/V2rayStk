import '../../../core/storage/local_storage_service.dart';
import '../domain/proxy_traffic.dart';
import 'proxy_traffic_repository.dart';

class LocalProxyTrafficRepository implements ProxyTrafficRepository {
  LocalProxyTrafficRepository(this._storage);

  static const String _trafficKey = 'proxy_traffic';

  final LocalStorageService _storage;

  @override
  Future<List<ProxyTraffic>> getAll() async {
    final List<Map<String, dynamic>> items =
        await _storage.readJsonList(_trafficKey);

    return items
        .map(ProxyTraffic.fromJson)
        .where((ProxyTraffic item) => item.profileId.isNotEmpty)
        .toList();
  }

  @override
  Future<ProxyTraffic> getFor(String profileId) async {
    final List<ProxyTraffic> all = await getAll();

    return all.firstWhere(
      (ProxyTraffic item) => item.profileId == profileId,
      orElse: () => ProxyTraffic(profileId: profileId),
    );
  }

  Future<void> _persist(List<ProxyTraffic> items) async {
    await _storage.saveJsonList(
      _trafficKey,
      items.map((ProxyTraffic item) => item.toJson()).toList(),
    );
  }

  @override
  Future<void> addUsage({
    required String profileId,
    int uploadBytes = 0,
    int downloadBytes = 0,
    int durationSeconds = 0,
    bool markConnected = false,
    int? pingMs,
  }) async {
    if (profileId.isEmpty) {
      return;
    }

    final List<ProxyTraffic> all = await getAll();
    final int index =
        all.indexWhere((ProxyTraffic item) => item.profileId == profileId);

    final ProxyTraffic current =
        index == -1 ? ProxyTraffic(profileId: profileId) : all[index];

    final ProxyTraffic updated = current.copyWith(
      uploadBytes: current.uploadBytes + (uploadBytes < 0 ? 0 : uploadBytes),
      downloadBytes:
          current.downloadBytes + (downloadBytes < 0 ? 0 : downloadBytes),
      totalDurationSeconds: current.totalDurationSeconds +
          (durationSeconds < 0 ? 0 : durationSeconds),
      connectCount:
          markConnected ? current.connectCount + 1 : current.connectCount,
      lastUsedAt: DateTime.now(),
      lastPingMs: pingMs ?? current.lastPingMs,
    );

    if (index == -1) {
      all.add(updated);
    } else {
      all[index] = updated;
    }

    await _persist(all);
  }

  @override
  Future<void> reset(String profileId) async {
    final List<ProxyTraffic> all = await getAll();
    all.removeWhere((ProxyTraffic item) => item.profileId == profileId);
    await _persist(all);
  }

  @override
  Future<void> resetAll() async {
    await _persist(<ProxyTraffic>[]);
  }
}
