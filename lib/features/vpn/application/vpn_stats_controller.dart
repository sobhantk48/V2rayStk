import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vpn_stats.dart';
import 'vpn_controller.dart';

final NotifierProvider<VpnStatsController, VpnStats> vpnStatsProvider =
    NotifierProvider<VpnStatsController, VpnStats>(VpnStatsController.new);

class VpnStatsController extends Notifier<VpnStats> {
  Timer? _timer;
  DateTime? _connectedAt;

  @override
  VpnStats build() {
    ref.listen<VpnConnectionState>(
      vpnControllerProvider,
      (previous, next) {
        if (next == VpnConnectionState.connected) {
          _start();
        } else if (next == VpnConnectionState.disconnected) {
          _stop();
        }
      },
      fireImmediately: true,
    );
    ref.onDispose(() => _timer?.cancel());
    return const VpnStats();
  }

  void _start() {
    _connectedAt ??= DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _connectedAt = null;
    state = const VpnStats();
  }

  Future<void> _tick() async {
    final DateTime? since = _connectedAt;
    if (since == null) return;
    final Duration elapsed = DateTime.now().difference(since);

    final Map<String, dynamic>? raw =
        await ref.read(vpnPlatformServiceProvider).getStats();

    state = raw == null
        ? state.copyWith(duration: elapsed)
        : VpnStats.fromMap(raw, elapsed);
  }

  Future<void> refreshLatency() async {
    final int? ping = await ref.read(vpnPlatformServiceProvider).testLatency();
    if (ping != null && ping >= 0) {
      state = state.copyWith(pingMs: ping);
    }
  }
}
