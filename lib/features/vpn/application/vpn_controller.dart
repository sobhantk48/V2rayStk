import 'package:flutter_riverpod/flutter_riverpod.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

final NotifierProvider<VpnController, VpnConnectionState> vpnControllerProvider =
    NotifierProvider<VpnController, VpnConnectionState>(
  VpnController.new,
);

class VpnController extends Notifier<VpnConnectionState> {
  @override
  VpnConnectionState build() {
    return VpnConnectionState.disconnected;
  }

  Future<void> connect() async {
    state = VpnConnectionState.connecting;
    state = VpnConnectionState.connected;
  }

  Future<void> disconnect() async {
    state = VpnConnectionState.disconnecting;
    state = VpnConnectionState.disconnected;
  }
}
