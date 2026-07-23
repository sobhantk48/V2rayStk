import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/vpn_platform_service.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../domain/vpn_status.dart';

final Provider<VpnPlatformService> vpnPlatformServiceProvider =
    Provider<VpnPlatformService>((Ref ref) {
  return VpnPlatformService();
});

final StateNotifierProvider<VpnController, VpnStatus> vpnControllerProvider =
    StateNotifierProvider<VpnController, VpnStatus>((Ref ref) {
  return VpnController(
    ref.watch(vpnPlatformServiceProvider),
    ref,
  );
});

class VpnController extends StateNotifier<VpnStatus> {
  VpnController(
    this._platformService,
    this._ref,
  ) : super(VpnStatus.disconnected);

  final VpnPlatformService _platformService;
  final Ref _ref;

  Future<void> refresh() async {
    final String rawStatus = await _platformService.getStatus();
    state = _mapStatus(rawStatus);
  }

  Future<void> connect() async {
    final List<Profile> profiles =
        await _ref.read(profilesProvider.future);
    final bool hasActiveProfile =
        profiles.any((Profile profile) => profile.isActive);

    if (!hasActiveProfile) {
      state = VpnStatus.disconnected;
      return;
    }

    state = VpnStatus.connecting;
    await _platformService.connect();
    await refresh();
  }

  Future<void> disconnect() async {
    await _platformService.disconnect();
    state = VpnStatus.disconnected;
  }

  VpnStatus _mapStatus(String rawStatus) {
    switch (rawStatus) {
      case 'connected':
        return VpnStatus.connected;
      case 'connecting':
        return VpnStatus.connecting;
      default:
        return VpnStatus.disconnected;
    }
  }
}
