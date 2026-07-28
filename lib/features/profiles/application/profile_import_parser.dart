import 'dart:convert';

import '../domain/profile.dart';
import '../domain/profile_type.dart';

/// ورودی کاربر (URI یا JSON خام هسته) را به [Profile] تبدیل می‌کند.
///
/// پشتیبانی: هر ۱۶ پروتکل مصوب پروژه، هم از طریق scheme لینک و هم از
/// طریق فیلد `type`/`protocol` در JSON هسته (sing-box / v2ray / Xray).
class ProfileImportParser {
  const ProfileImportParser();

  /// نگاشت scheme لینک به نوع پروفایل.
  ///
  /// ترتیب مهم است: کلیدهای طولانی‌تر (مثل `hysteria2`) باید قبل از
  /// کلیدهای کوتاه‌تر (مثل `hysteria`) بررسی شوند، وگرنه `hysteria2://`
  /// به‌اشتباه Hysteria نسخه ۱ تشخیص داده می‌شود.
  static const List<(String, ProfileType)> _schemeMap = <(String, ProfileType)>[
    ('vmess', ProfileType.vmess),
    ('vless', ProfileType.vless),
    ('trojan', ProfileType.trojan),
    ('trojan-go', ProfileType.trojan),
    ('ss', ProfileType.shadowsocks),
    ('shadowsocks', ProfileType.shadowsocks),
    ('hysteria2', ProfileType.hysteria2),
    ('hy2', ProfileType.hysteria2),
    ('hysteria', ProfileType.hysteria),
    ('hy', ProfileType.hysteria),
    ('tuic', ProfileType.tuic),
    ('wireguard', ProfileType.wireguard),
    ('wg', ProfileType.wireguard),
    ('shadowtls', ProfileType.shadowtls),
    ('anytls', ProfileType.anytls),
    ('naive+https', ProfileType.naive),
    ('naive+quic', ProfileType.naive),
    ('naive', ProfileType.naive),
    ('tor', ProfileType.tor),
    ('ssh', ProfileType.ssh),
    ('socks5', ProfileType.socks),
    ('socks4', ProfileType.socks),
    ('socks4a', ProfileType.socks),
    ('socks', ProfileType.socks),
    ('http', ProfileType.http),
    ('https', ProfileType.http),
  ];

  Profile parse(String input) {
    final String value = input.trim();

    if (value.isEmpty) {
      return _fallback(value, 'Empty Profile');
    }

    if (_looksLikeJson(value)) {
      return _parseJson(value);
    }

    // vmess معمولاً payload بیس۶۴ دارد و مسیر جداگانه‌ای می‌خواهد.
    if (_hasScheme(value, 'vmess')) {
      return _parseVmess(value);
    }

    if (_hasScheme(value, 'ss') || _hasScheme(value, 'shadowsocks')) {
      return _parseShadowsocks(value);
    }

    for (final (String scheme, ProfileType type) in _schemeMap) {
      if (_hasScheme(value, scheme)) {
        return _parseUriBased(value, type);
      }
    }

    return _fallback(value, 'Imported Profile');
  }

  bool _hasScheme(String value, String scheme) {
    return value.toLowerCase().startsWith('$scheme://');
  }

  bool _looksLikeJson(String value) {
    if (!value.startsWith('{') || !value.endsWith('}')) {
      return false;
    }
    try {
      jsonDecode(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// JSON خام sing-box یا v2ray/Xray. اولین outbound/endpoint معتبر برای
  /// نمایش نام/سرور/پورت استخراج می‌شود و کل متن در rawConfig می‌ماند.
  Profile _parseJson(String value) {
    final Map<String, dynamic> root = jsonDecode(value) as Map<String, dynamic>;

    // در sing-box 1.11+ پروتکل‌هایی مثل wireguard زیر endpoints می‌آیند.
    final List<dynamic> entries = <dynamic>[
      ...((root['outbounds'] as List<dynamic>?) ?? const <dynamic>[]),
      ...((root['endpoints'] as List<dynamic>?) ?? const <dynamic>[]),
    ];

    for (final dynamic entry in entries) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final String protocol =
          (entry['type'] ?? entry['protocol'] ?? '').toString();
      final ProfileType type = _mapProtocol(protocol, entry);

      if (type == ProfileType.unknown) {
        continue;
      }

      final String server = _readServer(entry);
      final int port = _readPort(entry);

      return Profile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: (entry['tag'] as String?)?.trim().isNotEmpty == true
            ? entry['tag'] as String
            : protocol.toUpperCase(),
        server: server,
        port: port,
        type: type,
        rawConfig: value,
        isActive: false,
        createdAt: DateTime.now(),
      );
    }

    return _fallback(value, 'JSON Profile');
  }

  String _readServer(Map<String, dynamic> outbound) {
    final Object? direct = outbound['server'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    // wireguard در sing-box آدرس را داخل peers نگه می‌دارد.
    final Object? peers = outbound['peers'];
    if (peers is List<dynamic> && peers.isNotEmpty) {
      final dynamic first = peers.first;
      if (first is Map<String, dynamic>) {
        final Object? address = first['address'] ?? first['server'];
        if (address is String && address.trim().isNotEmpty) {
          return address.trim();
        }
      }
    }

    final Object? settings = outbound['settings'];
    if (settings is Map<String, dynamic>) {
      final Object? vnext = settings['vnext'];
      if (vnext is List<dynamic> && vnext.isNotEmpty) {
        final dynamic first = vnext.first;
        if (first is Map<String, dynamic>) {
          return (first['address'] as String?)?.trim() ?? '';
        }
      }

      final Object? servers = settings['servers'];
      if (servers is List<dynamic> && servers.isNotEmpty) {
        final dynamic first = servers.first;
        if (first is Map<String, dynamic>) {
          return (first['address'] as String?)?.trim() ?? '';
        }
      }
    }

    return '';
  }

  int _readPort(Map<String, dynamic> outbound) {
    final int? direct = int.tryParse(
      (outbound['server_port'] ?? outbound['port'] ?? '').toString(),
    );
    if (direct != null && direct > 0) {
      return direct;
    }

    final Object? peers = outbound['peers'];
    if (peers is List<dynamic> && peers.isNotEmpty) {
      final dynamic first = peers.first;
      if (first is Map<String, dynamic>) {
        final int? peerPort = int.tryParse(
          (first['server_port'] ?? first['port'] ?? '').toString(),
        );
        if (peerPort != null && peerPort > 0) {
          return peerPort;
        }
      }
    }

    final Object? settings = outbound['settings'];
    if (settings is Map<String, dynamic>) {
      for (final String key in const <String>['vnext', 'servers']) {
        final Object? list = settings[key];
        if (list is List<dynamic> && list.isNotEmpty) {
          final dynamic first = list.first;
          if (first is Map<String, dynamic>) {
            final int? port = int.tryParse(first['port']?.toString() ?? '');
            if (port != null && port > 0) {
              return port;
            }
          }
        }
      }
    }

    return 0;
  }

  /// نام پروتکل هسته را به [ProfileType] نگاشت می‌کند.
  ///
  /// [outbound] اختیاری است و فقط برای تفکیک VLESS معمولی از
  /// VLESS + XTLS Reality استفاده می‌شود.
  ProfileType _mapProtocol(String protocol, [Map<String, dynamic>? outbound]) {
    switch (protocol.trim().toLowerCase()) {
      case 'vmess':
        return ProfileType.vmess;
      case 'vless':
        return _isReality(outbound) ? ProfileType.reality : ProfileType.vless;
      case 'reality':
        return ProfileType.reality;
      case 'trojan':
      case 'trojan-go':
        return ProfileType.trojan;
      case 'shadowsocks':
      case 'ss':
        return ProfileType.shadowsocks;
      case 'shadowtls':
        return ProfileType.shadowtls;
      case 'anytls':
        return ProfileType.anytls;
      case 'hysteria':
        return ProfileType.hysteria;
      case 'hysteria2':
      case 'hy2':
        return ProfileType.hysteria2;
      case 'tuic':
        return ProfileType.tuic;
      case 'wireguard':
      case 'wg':
        return ProfileType.wireguard;
      case 'naive':
      case 'naiveproxy':
        return ProfileType.naive;
      case 'tor':
        return ProfileType.tor;
      case 'ssh':
        return ProfileType.ssh;
      case 'socks':
      case 'socks4':
      case 'socks4a':
      case 'socks5':
        return ProfileType.socks;
      case 'http':
      case 'https':
        return ProfileType.http;
      default:
        return ProfileType.unknown;
    }
  }

  /// وجود `reality` در بخش TLS به‌معنای VLESS + XTLS Reality است.
  bool _isReality(Map<String, dynamic>? outbound) {
    if (outbound == null) {
      return false;
    }

    final Object? tls = outbound['tls'] ?? outbound['streamSettings'];
    if (tls is Map<String, dynamic>) {
      final Object? reality = tls['reality'] ?? tls['realitySettings'];
      if (reality is Map<String, dynamic> && reality.isNotEmpty) {
        return reality['enabled'] != false;
      }
      if ((tls['security'] ?? '').toString().toLowerCase() == 'reality') {
        return true;
      }
    }

    return false;
  }

  Profile _parseVmess(String input) {
    final String payload = input.substring('vmess://'.length).trim();

    try {
      final String normalized = base64.normalize(payload);
      final Map<String, dynamic> json = jsonDecode(
        utf8.decode(base64Decode(normalized)),
      ) as Map<String, dynamic>;

      return Profile(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: (json['ps'] as String?)?.trim().isNotEmpty == true
            ? (json['ps'] as String).trim()
            : 'VMess',
        server: json['add'] as String? ?? '',
        port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
        type: ProfileType.vmess,
        rawConfig: input,
        isActive: false,
        createdAt: DateTime.now(),
      );
    } on Object {
      // برخی پنل‌ها vmess را به‌شکل URI استاندارد (VMessAEAD) می‌دهند.
      return _parseUriBased(input, ProfileType.vmess);
    }
  }

  Profile _parseUriBased(String input, ProfileType type) {
    ProfileType resolved = type;
    String host = '';
    int port = 0;
    String name = type.name.toUpperCase();

    try {
      final Uri uri = Uri.parse(input);
      host = uri.host;
      port = uri.hasPort ? uri.port : 0;

      if (uri.fragment.trim().isNotEmpty) {
        name = Uri.decodeComponent(uri.fragment).trim();
      }

      // vless با security=reality نوع مجزا دارد.
      if (type == ProfileType.vless) {
        final String security =
            (uri.queryParameters['security'] ?? '').toLowerCase();
        final bool hasPbk =
            (uri.queryParameters['pbk'] ?? '').trim().isNotEmpty;
        if (security == 'reality' || hasPbk) {
          resolved = ProfileType.reality;
        }
      }
    } on FormatException {
      // ورودی خراب است؛ همان مقادیر پیش‌فرض می‌ماند و rawConfig حفظ می‌شود.
    }

    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      server: host,
      port: port,
      type: resolved,
      rawConfig: input,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  /// دو قالب رایج Shadowsocks:
  /// `ss://base64(method:pass@host:port)#name` و
  /// `ss://base64(method:pass)@host:port#name`
  Profile _parseShadowsocks(String input) {
    final int schemeEnd = input.indexOf('://') + 3;
    String body = input.substring(schemeEnd);
    String name = 'Shadowsocks';

    final int hashIndex = body.indexOf('#');
    if (hashIndex >= 0) {
      final String tag = body.substring(hashIndex + 1).trim();
      if (tag.isNotEmpty) {
        try {
          name = Uri.decodeComponent(tag);
        } on ArgumentError {
          name = tag;
        }
      }
      body = body.substring(0, hashIndex);
    }

    final int queryIndex = body.indexOf('?');
    if (queryIndex >= 0) {
      body = body.substring(0, queryIndex);
    }

    // اگر @ وجود ندارد، کل بدنه بیس۶۴ است.
    if (!body.contains('@')) {
      try {
        body = utf8.decode(base64Decode(base64.normalize(body)));
      } on Object {
        // بیس۶۴ نبود؛ همان متن خام بررسی می‌شود.
      }
    }

    String host = '';
    int port = 0;
    final int atIndex = body.lastIndexOf('@');
    if (atIndex >= 0) {
      final String hostPort = body.substring(atIndex + 1);
      final int colonIndex = hostPort.lastIndexOf(':');
      if (colonIndex > 0) {
        host = hostPort.substring(0, colonIndex).replaceAll(RegExp(r'^\[|\]$'), '');
        port = int.tryParse(hostPort.substring(colonIndex + 1)) ?? 0;
      } else {
        host = hostPort;
      }
    }

    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      server: host,
      port: port,
      type: ProfileType.shadowsocks,
      rawConfig: input,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  Profile _fallback(String value, String name) {
    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      server: '',
      port: 0,
      type: ProfileType.unknown,
      rawConfig: value,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }
}
