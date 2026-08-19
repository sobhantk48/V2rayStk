import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/vpn_platform_service.dart';
import '../../admin/domain/admin_settings.dart';
import '../../logs/application/log_controller.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../../sing_box/application/admin_config_patcher.dart';
import '../../sing_box/application/sing_box_config_generator.dart';
import '../../sing_box/domain/sing_box_config.dart';
import '../../sing_box/domain/sing_box_config_exception.dart';
import 'admin_settings_reader.dart';
import '../../xray/application/xray_config_generator.dart';

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
      final AdminSettings settings = await _reader.read();
      final Profile profile = await _resolveActiveProfile(settings);
      // XRAY_CHAIN_V1
      final String sbJson = await _buildConfigJson(profile, settings);
      final String xrayJson = XrayConfigGenerator.tryBuild(profile);
      await _service.connect(
        xrayJson.isEmpty ? sbJson : _redirectProxyToXray(sbJson),
        torEnabled: settings.torEnabled,
        killSwitch: settings.killSwitch,
        alwaysOnVpn: settings.alwaysOnVpn,
        xrayConfig: xrayJson,
      );
      state = VpnConnectionState.connected;
    } catch (error, stackTrace) {
      _logFailure('connect', error, stackTrace);
      state = VpnConnectionState.disconnected;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    state = VpnConnectionState.disconnecting;
    try {
      await _service.disconnect();
      state = VpnConnectionState.disconnected;
    } catch (error, stackTrace) {
      _logFailure('disconnect', error, stackTrace);
      state = VpnConnectionState.connected;
      rethrow;
    }
  }

  Future<void> connectWithProfile(Profile profile) async {
    state = VpnConnectionState.connecting;
    try {
      final AdminSettings settings = await _reader.read();
      // XRAY_CHAIN_V1
      final String sbJson = await _buildConfigJson(profile, settings);
      final String xrayJson = XrayConfigGenerator.tryBuild(profile);
      await _service.connect(
        xrayJson.isEmpty ? sbJson : _redirectProxyToXray(sbJson),
        torEnabled: settings.torEnabled,
        killSwitch: settings.killSwitch,
        alwaysOnVpn: settings.alwaysOnVpn,
        xrayConfig: xrayJson,
      );
      state = VpnConnectionState.connected;
    } catch (error, stackTrace) {
      _logFailure('connectWithProfile', error, stackTrace);
      state = VpnConnectionState.disconnected;
      rethrow;
    }
  }

  /// XRAY_CHAIN_V1
  ///
  /// وقتی هسته Xray فعال است، outbound اصلی sing-box (تگ `proxy`) به
  /// SOCKS داخلی Xray روی 127.0.0.1 هدایت می‌شود تا کل ترافیک tun از
  /// دل Xray بیرون برود. در این حالت multi-hop سمت sing-box بی‌اثر است.
  String _redirectProxyToXray(String configJson) {
    try {
      final Object? decoded = jsonDecode(configJson);
      if (decoded is! Map) {
        return configJson;
      }
      final Map<String, dynamic> config = Map<String, dynamic>.from(decoded);
      final Object? rawOutbounds = config['outbounds'];
      if (rawOutbounds is! List) {
        return configJson;
      }

      final List<dynamic> outbounds = List<dynamic>.from(rawOutbounds);
      bool replaced = false;
      for (int i = 0; i < outbounds.length; i++) {
        final Object? item = outbounds[i];
        if (item is Map && item['tag'] == 'proxy') {
          outbounds[i] = <String, dynamic>{
            'type': 'socks',
            'tag': 'proxy',
            'server': '127.0.0.1',
            'server_port': XrayConfigGenerator.socksPort,
            'version': '5',
          };
          replaced = true;
          break;
        }
      }
      if (!replaced) {
        return configJson;
      }

      config['outbounds'] = outbounds;
      return jsonEncode(config);
    } catch (_) {
      return configJson;
    }
  }

  Future<Profile> _resolveActiveProfile(AdminSettings settings) async {
    if (settings.torEnabled) {
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
      final List<Profile> active =
          profiles.where((Profile p) => p.isActive).toList();
      return active.isNotEmpty ? active.first : profiles.first;
    }

    throw const SingBoxConfigException(
      'No profile selected. Add a config or enable Tor from the admin panel.',
    );
  }

  Future<String> _buildConfigJson(
    Profile profile,
    AdminSettings settings,
  ) async {
    final List<Profile> hops = await _resolveHopProfiles(profile, settings);
    final SingBoxConfig config = hops.isEmpty
        ? _generator.generate(profile)
        : _generator.generateChain(profile, hops);
    final Map<String, dynamic> patched = _patcher.apply(
      config.value,
      settings,
    );
    return jsonEncode(patched);
  }

  /// پروفایل هاپ‌ها را بر اساس ترتیب multiHopIds برمی‌گرداند.
  /// اگر Multi-Hop خاموش باشد یا Tor روشن باشد، لیست خالی است.
  Future<List<Profile>> _resolveHopProfiles(
    Profile profile,
    AdminSettings settings,
  ) async {
    if (!settings.multiHop || settings.multiHopIds.isEmpty) {
      return const <Profile>[];
    }
    if (settings.torEnabled) {
      return const <Profile>[];
    }
    try {
      final List<Profile> all = await ref.read(profilesProvider.future);
      final List<Profile> out = <Profile>[];
      for (final String id in settings.multiHopIds) {
        for (final Profile candidate in all) {
          if (candidate.id == id && candidate.id != profile.id) {
            out.add(candidate);
            break;
          }
        }
      }
      return out;
    } catch (_) {
      // اگر پروفایل‌ها خوانده نشدند، اتصال ساده بهتر از قطع اتصال است.
      return const <Profile>[];
    }
  }

  Object? _lastError;
  StackTrace? _lastStackTrace;

  /// آخرین خطای رخ‌داده در چرخهٔ اتصال (برای نمایش در UI).
  Object? get lastError => _lastError;

  StackTrace? get lastStackTrace => _lastStackTrace;

  /// پیام خوانا از آخرین خطا؛ رشتهٔ خالی یعنی خطایی ثبت نشده است.
  String get lastErrorMessage {
    final Object? error = _lastError;
    if (error == null) {
      return '';
    }
    if (error is SingBoxConfigException) {
      return error.message;
    }
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return error.toString();
  }

  void _logFailure(String action, Object error, StackTrace stackTrace) {
    _lastError = error;
    _lastStackTrace = stackTrace;
    developer.log(
      'VPN $action failed: $error',
      name: 'VpnController',
      error: error,
      stackTrace: stackTrace,
    );
    _appendToLogBuffer(action, error, stackTrace);
  }

  /// ثبت خطا در بافر ۳۰۰۰تایی Dart تا در صفحهٔ لاگ اپ هم دیده شود.
  void _appendToLogBuffer(String action, Object error, StackTrace stackTrace) {
    try {
      ref.read(logControllerProvider.notifier).append(
            level: 'error',
            tag: 'VpnController',
            message: 'VPN $action failed: $error\n$stackTrace',
          );
    } on Object catch (bufferError) {
      developer.log(
        'log buffer unavailable: $bufferError',
        name: 'VpnController',
      );
    }
  }

}
