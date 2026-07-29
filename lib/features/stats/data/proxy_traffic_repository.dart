import '../domain/proxy_traffic.dart';

abstract class ProxyTrafficRepository {
  Future<List<ProxyTraffic>> getAll();

  Future<ProxyTraffic> getFor(String profileId);

  /// افزودن مصرف تجمعی (delta) برای یک پروفایل.
  Future<void> addUsage({
    required String profileId,
    int uploadBytes,
    int downloadBytes,
    int durationSeconds,
    bool markConnected,
    int? pingMs,
  });

  Future<void> reset(String profileId);

  Future<void> resetAll();
}
