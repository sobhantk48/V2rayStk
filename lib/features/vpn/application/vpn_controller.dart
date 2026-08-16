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
      await _service.connect(
        _buildConfigJson(profile, settings),
        torEnabled: settings.torEnabled,
        killSwitch: settings.killSwitch,
        alwaysOnVpn: settings.alwaysOnVpn,
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
      await _service.connect(
        _buildConfigJson(profile, settings),
        torEnabled: settings.torEnabled,
        killSwitch: settings.killSwitch,
        alwaysOnVpn: settings.alwaysOnVpn,
      );
      state = VpnConnectionState.connected;
    } catch (error, stackTrace) {
      _logFailure('connectWithProfile', error, stackTrace);
      state = VpnConnectionState.disconnected;
      rethrow;
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

  String _buildConfigJson(Profile profile, AdminSettings settings) {
    final SingBoxConfig config = _generator.generate(profile);
    final Map<String, dynamic> patched = _patcher.apply(
      config.value,
      settings,
    );
    return jsonEncode(patched);
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
