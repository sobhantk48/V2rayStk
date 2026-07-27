/// تنظیمات سراسری اپ که فقط از پنل ادمین قابل تغییر است.
/// کاربر عادی این مقادیر را نمی‌بیند و فقط پروفایل و دکمه اتصال دارد.
class AdminSettings {
  const AdminSettings({
    required this.passwordHash,
    required this.salt,
    this.killSwitch = false,
    this.torEnabled = false,
    this.anonymousMode = false,
    this.firewallEnabled = true,
    this.blockAds = true,
    this.blockTrackers = true,
    this.blockTorrent = false,
    this.biometricLock = false,
    this.liteMode = false,
    this.batteryOptimization = true,
    this.trafficCompression = false,
    this.autoServerSelection = true,
    this.dynamicRouting = false,
    this.multiHop = false,
    this.lwoEnabled = false,
    this.nordLynxEnabled = false,
    this.dnsMode = 'doh',
    this.dnsServer = 'https://1.1.1.1/dns-query',
    this.splitDns = false,
    this.fragmentEnabled = false,
    this.fragmentPackets = 'tlshello',
    this.fragmentLength = '10-20',
    this.fragmentInterval = '10-20',
    this.mtu = 9000,
    this.logLevel = 'warn',
    this.clashApiEnabled = true,
    this.clashApiPort = 9090,
    this.allowUserEdit = false,
    this.allowUserImport = false,
    this.allowUserGroups = false,
    this.autoConnectOnNetworkChange = false,
    this.alwaysOnVpn = false,
    this.hapticFeedback = true,
  });

  final String passwordHash;
  final String salt;

  final bool killSwitch;
  final bool torEnabled;
  final bool anonymousMode;
  final bool firewallEnabled;
  final bool blockAds;
  final bool blockTrackers;
  final bool blockTorrent;
  final bool biometricLock;
  final bool liteMode;
  final bool batteryOptimization;
  final bool trafficCompression;
  final bool autoServerSelection;
  final bool dynamicRouting;
  final bool multiHop;
  final bool lwoEnabled;
  final bool nordLynxEnabled;

  final String dnsMode;
  final String dnsServer;
  final bool splitDns;

  final bool fragmentEnabled;
  final String fragmentPackets;
  final String fragmentLength;
  final String fragmentInterval;

  final int mtu;
  final String logLevel;
  final bool clashApiEnabled;
  final int clashApiPort;

  final bool allowUserEdit;
  final bool allowUserImport;
  final bool allowUserGroups;

  final bool autoConnectOnNetworkChange;
  final bool alwaysOnVpn;
  final bool hapticFeedback;

  AdminSettings copyWith({
    String? passwordHash,
    String? salt,
    bool? killSwitch,
    bool? torEnabled,
    bool? anonymousMode,
    bool? firewallEnabled,
    bool? blockAds,
    bool? blockTrackers,
    bool? blockTorrent,
    bool? biometricLock,
    bool? liteMode,
    bool? batteryOptimization,
    bool? trafficCompression,
    bool? autoServerSelection,
    bool? dynamicRouting,
    bool? multiHop,
    bool? lwoEnabled,
    bool? nordLynxEnabled,
    String? dnsMode,
    String? dnsServer,
    bool? splitDns,
    bool? fragmentEnabled,
    String? fragmentPackets,
    String? fragmentLength,
    String? fragmentInterval,
    int? mtu,
    String? logLevel,
    bool? clashApiEnabled,
    int? clashApiPort,
    bool? allowUserEdit,
    bool? allowUserImport,
    bool? allowUserGroups,
    bool? autoConnectOnNetworkChange,
    bool? alwaysOnVpn,
    bool? hapticFeedback,
  }) {
    return AdminSettings(
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      killSwitch: killSwitch ?? this.killSwitch,
      torEnabled: torEnabled ?? this.torEnabled,
      anonymousMode: anonymousMode ?? this.anonymousMode,
      firewallEnabled: firewallEnabled ?? this.firewallEnabled,
      blockAds: blockAds ?? this.blockAds,
      blockTrackers: blockTrackers ?? this.blockTrackers,
      blockTorrent: blockTorrent ?? this.blockTorrent,
      biometricLock: biometricLock ?? this.biometricLock,
      liteMode: liteMode ?? this.liteMode,
      batteryOptimization: batteryOptimization ?? this.batteryOptimization,
      trafficCompression: trafficCompression ?? this.trafficCompression,
      autoServerSelection: autoServerSelection ?? this.autoServerSelection,
      dynamicRouting: dynamicRouting ?? this.dynamicRouting,
      multiHop: multiHop ?? this.multiHop,
      lwoEnabled: lwoEnabled ?? this.lwoEnabled,
      nordLynxEnabled: nordLynxEnabled ?? this.nordLynxEnabled,
      dnsMode: dnsMode ?? this.dnsMode,
      dnsServer: dnsServer ?? this.dnsServer,
      splitDns: splitDns ?? this.splitDns,
      fragmentEnabled: fragmentEnabled ?? this.fragmentEnabled,
      fragmentPackets: fragmentPackets ?? this.fragmentPackets,
      fragmentLength: fragmentLength ?? this.fragmentLength,
      fragmentInterval: fragmentInterval ?? this.fragmentInterval,
      mtu: mtu ?? this.mtu,
      logLevel: logLevel ?? this.logLevel,
      clashApiEnabled: clashApiEnabled ?? this.clashApiEnabled,
      clashApiPort: clashApiPort ?? this.clashApiPort,
      allowUserEdit: allowUserEdit ?? this.allowUserEdit,
      allowUserImport: allowUserImport ?? this.allowUserImport,
      allowUserGroups: allowUserGroups ?? this.allowUserGroups,
      autoConnectOnNetworkChange:
          autoConnectOnNetworkChange ?? this.autoConnectOnNetworkChange,
      alwaysOnVpn: alwaysOnVpn ?? this.alwaysOnVpn,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'passwordHash': passwordHash,
        'salt': salt,
        'killSwitch': killSwitch,
        'torEnabled': torEnabled,
        'anonymousMode': anonymousMode,
        'firewallEnabled': firewallEnabled,
        'blockAds': blockAds,
        'blockTrackers': blockTrackers,
        'blockTorrent': blockTorrent,
        'biometricLock': biometricLock,
        'liteMode': liteMode,
        'batteryOptimization': batteryOptimization,
        'trafficCompression': trafficCompression,
        'autoServerSelection': autoServerSelection,
        'dynamicRouting': dynamicRouting,
        'multiHop': multiHop,
        'lwoEnabled': lwoEnabled,
        'nordLynxEnabled': nordLynxEnabled,
        'dnsMode': dnsMode,
        'dnsServer': dnsServer,
        'splitDns': splitDns,
        'fragmentEnabled': fragmentEnabled,
        'fragmentPackets': fragmentPackets,
        'fragmentLength': fragmentLength,
        'fragmentInterval': fragmentInterval,
        'mtu': mtu,
        'logLevel': logLevel,
        'clashApiEnabled': clashApiEnabled,
        'clashApiPort': clashApiPort,
        'allowUserEdit': allowUserEdit,
        'allowUserImport': allowUserImport,
        'allowUserGroups': allowUserGroups,
        'autoConnectOnNetworkChange': autoConnectOnNetworkChange,
        'alwaysOnVpn': alwaysOnVpn,
        'hapticFeedback': hapticFeedback,
      };

  static AdminSettings fromJson(Map<String, dynamic> json) {
    bool boolOf(String key, bool fallback) {
      final Object? value = json[key];
      return value is bool ? value : fallback;
    }

    String stringOf(String key, String fallback) {
      final Object? value = json[key];
      return value is String && value.isNotEmpty ? value : fallback;
    }

    int intOf(String key, int fallback) {
      final Object? value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return fallback;
    }

    return AdminSettings(
      passwordHash: stringOf('passwordHash', ''),
      salt: stringOf('salt', ''),
      killSwitch: boolOf('killSwitch', false),
      torEnabled: boolOf('torEnabled', false),
      anonymousMode: boolOf('anonymousMode', false),
      firewallEnabled: boolOf('firewallEnabled', true),
      blockAds: boolOf('blockAds', true),
      blockTrackers: boolOf('blockTrackers', true),
      blockTorrent: boolOf('blockTorrent', false),
      biometricLock: boolOf('biometricLock', false),
      liteMode: boolOf('liteMode', false),
      batteryOptimization: boolOf('batteryOptimization', true),
      trafficCompression: boolOf('trafficCompression', false),
      autoServerSelection: boolOf('autoServerSelection', true),
      dynamicRouting: boolOf('dynamicRouting', false),
      multiHop: boolOf('multiHop', false),
      lwoEnabled: boolOf('lwoEnabled', false),
      nordLynxEnabled: boolOf('nordLynxEnabled', false),
      dnsMode: stringOf('dnsMode', 'doh'),
      dnsServer: stringOf('dnsServer', 'https://1.1.1.1/dns-query'),
      splitDns: boolOf('splitDns', false),
      fragmentEnabled: boolOf('fragmentEnabled', false),
      fragmentPackets: stringOf('fragmentPackets', 'tlshello'),
      fragmentLength: stringOf('fragmentLength', '10-20'),
      fragmentInterval: stringOf('fragmentInterval', '10-20'),
      mtu: intOf('mtu', 9000),
      logLevel: stringOf('logLevel', 'warn'),
      clashApiEnabled: boolOf('clashApiEnabled', true),
      clashApiPort: intOf('clashApiPort', 9090),
      allowUserEdit: boolOf('allowUserEdit', false),
      allowUserImport: boolOf('allowUserImport', false),
      allowUserGroups: boolOf('allowUserGroups', false),
      autoConnectOnNetworkChange: boolOf('autoConnectOnNetworkChange', false),
      alwaysOnVpn: boolOf('alwaysOnVpn', false),
      hapticFeedback: boolOf('hapticFeedback', true),
    );
  }
}
