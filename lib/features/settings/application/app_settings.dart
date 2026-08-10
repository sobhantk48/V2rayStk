import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/platform/haptics.dart';

/// حالت Split Tunneling
enum SplitTunnelMode { off, include, exclude }

/// تمام تنظیمات غیرهسته‌ای اپ در یک مدل تغییرناپذیر.
@immutable
class AppSettings {
  const AppSettings({
    this.languageCode = 'fa',
    this.hapticEnabled = true,
    this.biometricLock = false,
    this.killSwitch = false,
    this.alwaysOn = false,
    this.notificationsEnabled = true,
    this.notificationSpeedInTitle = true,
    this.liteMode = false,
    this.batteryOptimization = true,
    this.autoServerSelection = false,
    this.autoConnectOnNetworkChange = false,
    this.anonymousMode = false,
    this.blockAds = false,
    this.blockTrackers = false,
    this.blockTorrent = false,
    this.trafficCompression = false,
    this.multiHopEnabled = false,
    this.dohEnabled = false,
    this.dohUrl = 'https://1.1.1.1/dns-query',
    this.dotEnabled = false,
    this.dotUrl = 'tls://1.1.1.1',
    this.splitDnsEnabled = false,
    this.fragmentEnabled = false,
    this.fragmentPackets = 'tlshello',
    this.fragmentLength = '10-20',
    this.fragmentInterval = '10-20',
    this.splitTunnelMode = SplitTunnelMode.off,
    this.splitTunnelApps = const <String>[],
  });

  final String languageCode;
  final bool hapticEnabled;
  final bool biometricLock;
  final bool killSwitch;
  final bool alwaysOn;
  final bool notificationsEnabled;
  final bool notificationSpeedInTitle;
  final bool liteMode;
  final bool batteryOptimization;
  final bool autoServerSelection;
  final bool autoConnectOnNetworkChange;
  final bool anonymousMode;
  final bool blockAds;
  final bool blockTrackers;
  final bool blockTorrent;
  final bool trafficCompression;
  final bool multiHopEnabled;
  final bool dohEnabled;
  final String dohUrl;
  final bool dotEnabled;
  final String dotUrl;
  final bool splitDnsEnabled;
  final bool fragmentEnabled;
  final String fragmentPackets;
  final String fragmentLength;
  final String fragmentInterval;
  final SplitTunnelMode splitTunnelMode;
  final List<String> splitTunnelApps;

  Locale get locale => Locale(languageCode);
  bool get isPersian => languageCode == 'fa';

  AppSettings copyWith({
    String? languageCode,
    bool? hapticEnabled,
    bool? biometricLock,
    bool? killSwitch,
    bool? alwaysOn,
    bool? notificationsEnabled,
    bool? notificationSpeedInTitle,
    bool? liteMode,
    bool? batteryOptimization,
    bool? autoServerSelection,
    bool? autoConnectOnNetworkChange,
    bool? anonymousMode,
    bool? blockAds,
    bool? blockTrackers,
    bool? blockTorrent,
    bool? trafficCompression,
    bool? multiHopEnabled,
    bool? dohEnabled,
    String? dohUrl,
    bool? dotEnabled,
    String? dotUrl,
    bool? splitDnsEnabled,
    bool? fragmentEnabled,
    String? fragmentPackets,
    String? fragmentLength,
    String? fragmentInterval,
    SplitTunnelMode? splitTunnelMode,
    List<String>? splitTunnelApps,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      biometricLock: biometricLock ?? this.biometricLock,
      killSwitch: killSwitch ?? this.killSwitch,
      alwaysOn: alwaysOn ?? this.alwaysOn,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationSpeedInTitle:
          notificationSpeedInTitle ?? this.notificationSpeedInTitle,
      liteMode: liteMode ?? this.liteMode,
      batteryOptimization: batteryOptimization ?? this.batteryOptimization,
      autoServerSelection: autoServerSelection ?? this.autoServerSelection,
      autoConnectOnNetworkChange:
          autoConnectOnNetworkChange ?? this.autoConnectOnNetworkChange,
      anonymousMode: anonymousMode ?? this.anonymousMode,
      blockAds: blockAds ?? this.blockAds,
      blockTrackers: blockTrackers ?? this.blockTrackers,
      blockTorrent: blockTorrent ?? this.blockTorrent,
      trafficCompression: trafficCompression ?? this.trafficCompression,
      multiHopEnabled: multiHopEnabled ?? this.multiHopEnabled,
      dohEnabled: dohEnabled ?? this.dohEnabled,
      dohUrl: dohUrl ?? this.dohUrl,
      dotEnabled: dotEnabled ?? this.dotEnabled,
      dotUrl: dotUrl ?? this.dotUrl,
      splitDnsEnabled: splitDnsEnabled ?? this.splitDnsEnabled,
      fragmentEnabled: fragmentEnabled ?? this.fragmentEnabled,
      fragmentPackets: fragmentPackets ?? this.fragmentPackets,
      fragmentLength: fragmentLength ?? this.fragmentLength,
      fragmentInterval: fragmentInterval ?? this.fragmentInterval,
      splitTunnelMode: splitTunnelMode ?? this.splitTunnelMode,
      splitTunnelApps: splitTunnelApps ?? this.splitTunnelApps,
    );
  }
}

/// کلیدهای ذخیره‌سازی. تغییرشان باعث از دست رفتن تنظیمات کاربر می‌شود.
class _Keys {
  static const prefix = 'settings.';
  static const language = '${prefix}language';
  static const haptic = '${prefix}haptic';
  static const biometric = '${prefix}biometric';
  static const killSwitch = '${prefix}kill_switch';
  static const alwaysOn = '${prefix}always_on';
  static const notifications = '${prefix}notifications';
  static const notificationSpeed = '${prefix}notification_speed';
  static const liteMode = '${prefix}lite_mode';
  static const battery = '${prefix}battery';
  static const autoServer = '${prefix}auto_server';
  static const autoConnect = '${prefix}auto_connect';
  static const anonymous = '${prefix}anonymous';
  static const blockAds = '${prefix}block_ads';
  static const blockTrackers = '${prefix}block_trackers';
  static const blockTorrent = '${prefix}block_torrent';
  static const compression = '${prefix}compression';
  static const multiHop = '${prefix}multi_hop';
  static const dohEnabled = '${prefix}doh_enabled';
  static const dohUrl = '${prefix}doh_url';
  static const dotEnabled = '${prefix}dot_enabled';
  static const dotUrl = '${prefix}dot_url';
  static const splitDns = '${prefix}split_dns';
  static const fragmentEnabled = '${prefix}fragment_enabled';
  static const fragmentPackets = '${prefix}fragment_packets';
  static const fragmentLength = '${prefix}fragment_length';
  static const fragmentInterval = '${prefix}fragment_interval';
  static const splitMode = '${prefix}split_mode';
  static const splitApps = '${prefix}split_apps';
}

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController() : super(const AppSettings()) {
    _load();
  }

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> _load() async {
    final p = await _p;
    final modeIndex = p.getInt(_Keys.splitMode) ?? 0;
    state = AppSettings(
      languageCode: p.getString(_Keys.language) ?? 'fa',
      hapticEnabled: p.getBool(_Keys.haptic) ?? true,
      biometricLock: p.getBool(_Keys.biometric) ?? false,
      killSwitch: p.getBool(_Keys.killSwitch) ?? false,
      alwaysOn: p.getBool(_Keys.alwaysOn) ?? false,
      notificationsEnabled: p.getBool(_Keys.notifications) ?? true,
      notificationSpeedInTitle: p.getBool(_Keys.notificationSpeed) ?? true,
      liteMode: p.getBool(_Keys.liteMode) ?? false,
      batteryOptimization: p.getBool(_Keys.battery) ?? true,
      autoServerSelection: p.getBool(_Keys.autoServer) ?? false,
      autoConnectOnNetworkChange: p.getBool(_Keys.autoConnect) ?? false,
      anonymousMode: p.getBool(_Keys.anonymous) ?? false,
      blockAds: p.getBool(_Keys.blockAds) ?? false,
      blockTrackers: p.getBool(_Keys.blockTrackers) ?? false,
      blockTorrent: p.getBool(_Keys.blockTorrent) ?? false,
      trafficCompression: p.getBool(_Keys.compression) ?? false,
      multiHopEnabled: p.getBool(_Keys.multiHop) ?? false,
      dohEnabled: p.getBool(_Keys.dohEnabled) ?? false,
      dohUrl: p.getString(_Keys.dohUrl) ?? 'https://1.1.1.1/dns-query',
      dotEnabled: p.getBool(_Keys.dotEnabled) ?? false,
      dotUrl: p.getString(_Keys.dotUrl) ?? 'tls://1.1.1.1',
      splitDnsEnabled: p.getBool(_Keys.splitDns) ?? false,
      fragmentEnabled: p.getBool(_Keys.fragmentEnabled) ?? false,
      fragmentPackets: p.getString(_Keys.fragmentPackets) ?? 'tlshello',
      fragmentLength: p.getString(_Keys.fragmentLength) ?? '10-20',
      fragmentInterval: p.getString(_Keys.fragmentInterval) ?? '10-20',
      splitTunnelMode: SplitTunnelMode
          .values[modeIndex.clamp(0, SplitTunnelMode.values.length - 1)],
      splitTunnelApps: p.getStringList(_Keys.splitApps) ?? const <String>[],
    );
    Haptics.enabled = state.hapticEnabled;
  }

  Future<void> setLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    (await _p).setString(_Keys.language, code);
  }

  Future<void> setHaptic(bool v) async {
    Haptics.enabled = v;
    state = state.copyWith(hapticEnabled: v);
    (await _p).setBool(_Keys.haptic, v);
  }

  Future<void> setBiometricLock(bool v) async {
    state = state.copyWith(biometricLock: v);
    (await _p).setBool(_Keys.biometric, v);
  }

  Future<void> setKillSwitch(bool v) async {
    state = state.copyWith(killSwitch: v);
    (await _p).setBool(_Keys.killSwitch, v);
  }

  Future<void> setAlwaysOn(bool v) async {
    state = state.copyWith(alwaysOn: v);
    (await _p).setBool(_Keys.alwaysOn, v);
  }

  Future<void> setNotificationsEnabled(bool v) async {
    state = state.copyWith(notificationsEnabled: v);
    (await _p).setBool(_Keys.notifications, v);
  }

  Future<void> setNotificationSpeedInTitle(bool v) async {
    state = state.copyWith(notificationSpeedInTitle: v);
    (await _p).setBool(_Keys.notificationSpeed, v);
  }

  Future<void> setLiteMode(bool v) async {
    state = state.copyWith(liteMode: v);
    (await _p).setBool(_Keys.liteMode, v);
  }

  Future<void> setBatteryOptimization(bool v) async {
    state = state.copyWith(batteryOptimization: v);
    (await _p).setBool(_Keys.battery, v);
  }

  Future<void> setAutoServerSelection(bool v) async {
    state = state.copyWith(autoServerSelection: v);
    (await _p).setBool(_Keys.autoServer, v);
  }

  Future<void> setAutoConnectOnNetworkChange(bool v) async {
    state = state.copyWith(autoConnectOnNetworkChange: v);
    (await _p).setBool(_Keys.autoConnect, v);
  }

  Future<void> setAnonymousMode(bool v) async {
    state = state.copyWith(anonymousMode: v);
    (await _p).setBool(_Keys.anonymous, v);
  }

  Future<void> setBlockAds(bool v) async {
    state = state.copyWith(blockAds: v);
    (await _p).setBool(_Keys.blockAds, v);
  }

  Future<void> setBlockTrackers(bool v) async {
    state = state.copyWith(blockTrackers: v);
    (await _p).setBool(_Keys.blockTrackers, v);
  }

  Future<void> setBlockTorrent(bool v) async {
    state = state.copyWith(blockTorrent: v);
    (await _p).setBool(_Keys.blockTorrent, v);
  }

  Future<void> setTrafficCompression(bool v) async {
    state = state.copyWith(trafficCompression: v);
    (await _p).setBool(_Keys.compression, v);
  }

  Future<void> setMultiHop(bool v) async {
    state = state.copyWith(multiHopEnabled: v);
    (await _p).setBool(_Keys.multiHop, v);
  }

  Future<void> setDoh(bool enabled, {String? url}) async {
    state = state.copyWith(dohEnabled: enabled, dohUrl: url);
    final p = await _p;
    p.setBool(_Keys.dohEnabled, enabled);
    if (url != null) p.setString(_Keys.dohUrl, url);
  }

  Future<void> setDot(bool enabled, {String? url}) async {
    state = state.copyWith(dotEnabled: enabled, dotUrl: url);
    final p = await _p;
    p.setBool(_Keys.dotEnabled, enabled);
    if (url != null) p.setString(_Keys.dotUrl, url);
  }

  Future<void> setSplitDns(bool v) async {
    state = state.copyWith(splitDnsEnabled: v);
    (await _p).setBool(_Keys.splitDns, v);
  }

  Future<void> setFragment({
    bool? enabled,
    String? packets,
    String? length,
    String? interval,
  }) async {
    state = state.copyWith(
      fragmentEnabled: enabled,
      fragmentPackets: packets,
      fragmentLength: length,
      fragmentInterval: interval,
    );
    final p = await _p;
    if (enabled != null) p.setBool(_Keys.fragmentEnabled, enabled);
    if (packets != null) p.setString(_Keys.fragmentPackets, packets);
    if (length != null) p.setString(_Keys.fragmentLength, length);
    if (interval != null) p.setString(_Keys.fragmentInterval, interval);
  }

  Future<void> setSplitTunnel(
    SplitTunnelMode mode, {
    List<String>? apps,
  }) async {
    state = state.copyWith(splitTunnelMode: mode, splitTunnelApps: apps);
    final p = await _p;
    p.setInt(_Keys.splitMode, mode.index);
    if (apps != null) p.setStringList(_Keys.splitApps, apps);
  }

  Future<void> reload() => _load();
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>(
  (ref) => AppSettingsController(),
);

/// زبان فعلی اپ، برای استفاده در MaterialApp.locale
final localeProvider = Provider<Locale>(
  (ref) => ref.watch(appSettingsProvider).locale,
);
