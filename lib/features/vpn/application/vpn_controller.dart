import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/vpn_platform_service.dart';
import '../../admin/domain/admin_settings.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../../sing_box/application/admin_config_patcher.dart';
import '../../sing_box/application/sing_box_config_generator.dart';
import '../../sing_box/domain/sing_box_config.dart';
import '../../sing_box/domain/sing_box_config_exception.dart';
import 'admin_settings_reader.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';

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
      await _service.connect(await _buildConfigJson(profile));
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
      await _service.connect(await _buildConfigJson(profile));
      state = VpnConnectionState.connected;
    } catch (_) {
      state = VpnConnectionState.disconnected;
      rethrow;
    }
  }

  /// پروفایل فعال، یا در نبود آن اولین پروفایل موجود.
    Future<Profile> _resolveActiveProfile() async {
    final List<Profile> profiles = await ref.read(profilesProvider.future);
    final adminReader = ref.read(adminSettingsReaderProvider);
    final adminSettings = await adminReader.read();

    if (profiles.isNotEmpty) {
      final active = profiles.where((p) => p.isActive).toList();
      return active.isNotEmpty ? active.first : profiles.first;
    }

    // اگر هیچ پروفایلی نبود ولی تور فعال بود، یک پروفایل مجازی تور می‌سازیم
    if (adminSettings.torEnabled) {
      return Profile(
        id: 'tor_standalone_auto',
        name: 'Tor Direct Network',
        type: ProfileType.socks,
        server: '127.0.0.1',
        port: 9050,
        isActive: true,
        rawConfig: 'socks5://127.0.0.1:9050',
        createdAt: DateTime.now(),
      );
    }

    throw const SingBoxConfigException('هیچ کانفیگی برای اتصال انتخاب نشده است. لطفاً یک کانفیگ اضافه کنید یا در پنل ادمین مسیریابی Tor را روشن کنید.');
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
