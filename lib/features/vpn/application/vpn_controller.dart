import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/vpn_platform_service.dart';
import '../../admin/domain/admin_settings.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../../sing_box/application/admin_config_patcher.dart';
import '../../sing_box/application/sing_box_config_generator.dart';
import '../../sing_box/domain/sing_box_config.dart';
import '../../sing_box/domain/sing_box_config_exception.dart';
import 'admin_settings_reader.dart';

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

final Provider<AdminConfigPatcher> adminConfigPatcherProvider =
    Provider<AdminConfigPatcher>((ref) => const AdminConfigPatcher());

final Provider<AdminSettingsReader> adminSettingsReaderProvider =
    Provider<AdminSettingsReader>((ref) => const AdminSettingsReader());

final NotifierProvider<VpnController, VpnConnectionState>
    vpnControllerProvider = NotifierProvider<VpnController, VpnConnectionState>(
  VpnController.new,
);

class VpnController extends Notifier<VpnConnectionState> {
  VpnPlatformService get _service => ref.read(vpnPlatformServiceProvider);

  SingBoxConfigGenerator get _generator =>
      ref.read(singBoxConfigGeneratorProvider);

  AdminConfigPatcher get _patcher => ref.read(adminConfigPatcherProvider);

  AdminSettingsReader get _reader => ref.read(adminSettingsReaderProvider);

  @override
  VpnConnectionState build() {
    return VpnConnectionState.disconnected;
  }

  Future<void> connect() async {
    state = VpnConnectionState.connecting;
    try {
      final Profile profile = await _resolveActiveProfile();
      final flags = await _readVpnFlags();
      await _service.connect(
        await _buildConfigJson(profile),
        torEnabled: await _isTorEnabled(),
        killSwitch: flags.killSwitch,
        alwaysOnVpn: flags.alwaysOnVpn,
      );
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

  /// اتصال با یک پروفایل مشخص، بدون توجه به فلگ isActive.
  Future<void> connectWithProfile(Profile profile) async {
    state = VpnConnectionState.connecting;
    try {
      final flags = await _readVpnFlags();
      await _service.connect(
        await _buildConfigJson(profile),
        torEnabled: await _isTorEnabled(),
        killSwitch: flags.killSwitch,
        alwaysOnVpn: flags.alwaysOnVpn,
      );
      state = VpnConnectionState.connected;
    } catch (_) {
      state = VpnConnectionState.disconnected;
      rethrow;
    }
  }

  /// فلگ Tor را از تنظیمات ادمین می‌خواند تا به سرویس نیتیو برسد.
  /// اگر خواندن شکست بخورد false برمی‌گردد تا پورت ۹۰۵۰ بی‌دلیل اشغال نشود.
  Future<bool> _isTorEnabled() async {
    try {
      final AdminSettings settings = await _reader.read();
      return settings.torEnabled;
    } catch (_) {
      return false;
    }
  }

  /// تنظیمات Kill Switch و Always-on VPN را از پنل ادمین می‌خواند.
  Future<({bool killSwitch, bool alwaysOnVpn})> _readVpnFlags() async {
    try {
      final AdminSettings settings = await _reader.read();
      return (
        killSwitch: settings.killSwitch,
        alwaysOnVpn: settings.alwaysOnVpn,
      );
    } catch (_) {
      return (killSwitch: false, alwaysOnVpn: false);
    }
  }

  Future<Profile> _resolveActiveProfile() async {
    // TOR-ONLY PRIORITY
    final adminReader = ref.read(adminSettingsReaderProvider);
    final adminSettings = await adminReader.read();

    if (adminSettings.torEnabled) {
      return Profile(
        id: 'tor_standalone_auto',
        name: 'Tor Direct Network',
        type: ProfileType.tor,
        server: '127.0.0.1',
        port: 9050,
        isActive: true,
        rawConfig: 'socks5://127.0.0.1:9050',
        createdAt: DateTime.now(),
      );
    }

    final List<Profile> profiles = await ref.read(profilesProvider.future);
    if (profiles.isNotEmpty) {
      final active = profiles.where((p) => p.isActive).toList();
      return active.isNotEmpty ? active.first : profiles.first;
    }

    throw const SingBoxConfigException(
      'هیچ پروفایلی انتخاب نشده است. یک کانفیگ اضافه کنید یا Tor را از پنل ادمین فعال کنید.',
    );
  }

  /// کانفیگ پروفایل را می‌سازد و تنظیمات پنل ادمین را روی آن اعمال می‌کند.
  Future<String> _buildConfigJson(Profile profile) async {
    final SingBoxConfig config = _generator.generate(profile);
    final String rawJson = config.toJsonString();

    try {
      final AdminSettings settings = await _reader.read();
      final dynamic decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        return rawJson;
      }
      final Map<String, dynamic> patched = _patcher.apply(
        Map<String, dynamic>.from(decoded),
        settings,
      );
      return jsonEncode(patched);
    } catch (_) {
      // اگر اعمال تنظیمات به هر دلیلی شکست خورد، اتصال با کانفیگ خام
      // ادامه پیدا می‌کند تا کاربر بی‌اینترنت نماند.
      return rawJson;
    }
  }
}
