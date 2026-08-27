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
    this.multiHopIds = const <String>[],
    this.lwoEnabled = false,
    this.nordLynxEnabled = false,
    this.dnsMode = 'doh',
    this.dnsServer = 'https://cloudflare-dns.com/dns-query',
    this.splitDns = false,
    this.splitDnsDirectDomains = 'ir',
    this.splitDnsLocalServer = 'local',
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
    this.sniffEnabled = false,
    this.sniffOverrideDestination = false,
    this.sniffTimeout = '300ms',
    this.muxEnabled = false,
    this.muxProtocol = 'h2mux',
    this.muxMaxStreams = 8,
    this.muxPadding = false,
    this.sniSpoofEnabled = false,
    this.sniSpoofValue = '',
    this.utlsFingerprint = 'chrome',
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

  /// شناسهٔ پروفایل‌هایی که به‌عنوان هاپ میانی زنجیره می‌شوند.
  /// ترتیب لیست = ترتیب زنجیره از نزدیک‌ترین پله به سرور نهایی.
  final List<String> multiHopIds;
  final bool lwoEnabled;
  final bool nordLynxEnabled;

  final String dnsMode;
  final String dnsServer;
  final bool splitDns;

  /// دامنه‌هایی که باید با DNS محلی حل شوند (با کاما جدا).
  final String splitDnsDirectDomains;

  /// سرور DNS محلی برای دامنه‌های داخلی؛ 'local' = DNS سیستم.
  final String splitDnsLocalServer;

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
  final bool sniffEnabled;
  final bool sniffOverrideDestination;
  final String sniffTimeout;
  final bool muxEnabled;
  final String muxProtocol;
  final int muxMaxStreams;
  final bool muxPadding;
  final bool sniSpoofEnabled;
  final String sniSpoofValue;
  final String utlsFingerprint;

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
    List<String>? multiHopIds,
    bool? lwoEnabled,
    bool? nordLynxEnabled,
    String? dnsMode,
    String? dnsServer,
    bool? splitDns,
    String? splitDnsDirectDomains,
    String? splitDnsLocalServer,
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
    bool? sniffEnabled,
    bool? sniffOverrideDestination,
    String? sniffTimeout,
    bool? muxEnabled,
    String? muxProtocol,
    int? muxMaxStreams,
    bool? muxPadding,
    bool? sniSpoofEnabled,
    String? sniSpoofValue,
    String? utlsFingerprint,
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
      multiHopIds: multiHopIds ?? this.multiHopIds,
      lwoEnabled: lwoEnabled ?? this.lwoEnabled,
      nordLynxEnabled: nordLynxEnabled ?? this.nordLynxEnabled,
      dnsMode: dnsMode ?? this.dnsMode,
      dnsServer: dnsServer ?? this.dnsServer,
      splitDns: splitDns ?? this.splitDns,
      splitDnsDirectDomains:
          splitDnsDirectDomains ?? this.splitDnsDirectDomains,
      splitDnsLocalServer: splitDnsLocalServer ?? this.splitDnsLocalServer,
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
      sniffEnabled: sniffEnabled ?? this.sniffEnabled,
      sniffOverrideDestination:
          sniffOverrideDestination ?? this.sniffOverrideDestination,
      sniffTimeout: sniffTimeout ?? this.sniffTimeout,
      muxEnabled: muxEnabled ?? this.muxEnabled,
      muxProtocol: muxProtocol ?? this.muxProtocol,
      muxMaxStreams: muxMaxStreams ?? this.muxMaxStreams,
      muxPadding: muxPadding ?? this.muxPadding,
      sniSpoofEnabled: sniSpoofEnabled ?? this.sniSpoofEnabled,
      sniSpoofValue: sniSpoofValue ?? this.sniSpoofValue,
      utlsFingerprint: utlsFingerprint ?? this.utlsFingerprint,
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
        'multiHopIds': multiHopIds,
        'lwoEnabled': lwoEnabled,
        'nordLynxEnabled': nordLynxEnabled,
        'dnsMode': dnsMode,
        'dnsServer': dnsServer,
        'splitDns': splitDns,
        'splitDnsDirectDomains': splitDnsDirectDomains,
        'splitDnsLocalServer': splitDnsLocalServer,
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
        'sniffEnabled': sniffEnabled,
        'sniffOverrideDestination': sniffOverrideDestination,
        'sniffTimeout': sniffTimeout,
        'muxEnabled': muxEnabled,
        'muxProtocol': muxProtocol,
        'muxMaxStreams': muxMaxStreams,
        'muxPadding': muxPadding,
        'sniSpoofEnabled': sniSpoofEnabled,
        'sniSpoofValue': sniSpoofValue,
        'utlsFingerprint': utlsFingerprint,
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

    List<String> stringListOf(String key) {
      final Object? value = json[key];
      if (value is! List) {
        return const <String>[];
      }
      final List<String> out = <String>[];
      for (final Object? item in value) {
        if (item is String && item.trim().isNotEmpty) {
          out.add(item.trim());
        }
      }
      return out;
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
      multiHopIds: stringListOf('multiHopIds'),
      lwoEnabled: boolOf('lwoEnabled', false),
      nordLynxEnabled: boolOf('nordLynxEnabled', false),
      dnsMode: stringOf('dnsMode', 'doh'),
      dnsServer: stringOf('dnsServer', 'https://cloudflare-dns.com/dns-query'),
      splitDns: boolOf('splitDns', false),
      splitDnsDirectDomains: stringOf('splitDnsDirectDomains', 'ir'),
      splitDnsLocalServer: stringOf('splitDnsLocalServer', 'local'),
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
      sniffEnabled: boolOf('sniffEnabled', false),
      sniffOverrideDestination: boolOf('sniffOverrideDestination', false),
      sniffTimeout: stringOf('sniffTimeout', '300ms'),
      muxEnabled: boolOf('muxEnabled', false),
      muxProtocol: stringOf('muxProtocol', 'h2mux'),
      muxMaxStreams: intOf('muxMaxStreams', 8),
      muxPadding: boolOf('muxPadding', false),
      sniSpoofEnabled: boolOf('sniSpoofEnabled', false),
      sniSpoofValue: stringOf('sniSpoofValue', ''),
      utlsFingerprint: stringOf('utlsFingerprint', 'chrome'),
    );
  }
}
