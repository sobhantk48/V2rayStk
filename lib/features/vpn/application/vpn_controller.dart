import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/vpn_platform_service.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../../sing_box/application/sing_box_config_generator.dart';
import '../../sing_box/domain/sing_box_config.dart';
import '../../sing_box/domain/sing_box_config_exception.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

final Provider<VpnPlatformService> vpnPlatformServiceProvider =
    Provider<VpnPlatformService>((ref) => VpnPlatformService());

final Provider<SingBoxConfigGenerator> singBoxConfigGeneratorProvider =
    Provider<SingBoxConfigGenerator>((ref) => const SingBoxConfigGenerator());

final NotifierProvider<VpnController, VpnConnectionState>
    vpnControllerProvider = NotifierProvider<VpnController, VpnConnectionState>(
  VpnController.new,
);

class VpnController extends Notifier<VpnConnectionState> {
  VpnPlatformService get _service => ref.read(vpnPlatformServiceProvider);

  SingBoxConfigGenerator get _generator =>
      ref.read(singBoxConfigGeneratorProvider);

  @override
  VpnConnectionState build() {
    return VpnConnectionState.disconnected;
  }

  Future<void> connect() async {
    state = VpnConnectionState.connecting;
    try {
      final String config = await _buildActiveConfigJson();
      await _service.connect(config);
      state = VpnConnectionState.connected;
    } catch (_) {
      state = VpnConnectionState.disconnected;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    state = VpnConnectionState.disconnecting;
    try {
      await _service.disconnect();
      state = VpnConnectionState.disconnected;
    } catch (_) {
      state = VpnConnectionState.connected;
      rethrow;
    }
  }

  /// پروفایل فعال را پیدا می‌کند و آن را به JSON هسته تبدیل می‌کند.
  /// اگر هیچ پروفایلی فعال نباشد، اولین پروفایل موجود استفاده می‌شود.
  Future<String> _buildActiveConfigJson() async {
    final List<Profile> profiles = await ref.read(profilesProvider.future);

    if (profiles.isEmpty) {
      throw const SingBoxConfigException('No profile available to connect.');
    }

    final Profile profile = profiles.firstWhere(
      (Profile item) => item.isActive,
      orElse: () => profiles.first,
    );

    final SingBoxConfig config = _generator.generate(profile);
    return config.toJsonString();
  }

  /// اتصال با یک پروفایل مشخص، بدون توجه به فلگ isActive.
  Future<void> connectWithProfile(Profile profile) async {
    state = VpnConnectionState.connecting;
    try {
      await _service.connect(_generator.generate(profile).toJsonString());
      state = VpnConnectionState.connected;
    } catch (_) {
      state = VpnConnectionState.disconnected;
      rethrow;
    }
  }
}
