import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/vpn_bridge.dart';

final vpnBridgeProvider = Provider<VpnBridge>((ref) {
  return VpnBridge.instance;
});

/// Live native VPN events.
final vpnEventProvider = StreamProvider<VpnEvent>((ref) {
  final bridge = ref.watch(vpnBridgeProvider);
  return bridge.statusStream;
});

final vpnControllerProvider = Provider<VpnController>((ref) {
  return VpnController(ref.watch(vpnBridgeProvider));
});

class VpnController {
  VpnController(this._bridge);

  final VpnBridge _bridge;

  Future<bool> connect({String config = ''}) async {
    final prepared = await _bridge.prepare();
    if (!prepared) {
      return false;
    }
    await _bridge.startVpn(config: config);
    return true;
  }

  Future<void> disconnect() => _bridge.stopVpn();

  Future<String> refreshStatus() => _bridge.getStatus();

  Future<VpnEvent> refreshStats() => _bridge.getStats();
}
