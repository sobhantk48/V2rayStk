import 'dart:convert';

import '../domain/profile.dart';
import '../domain/profile_type.dart';

/// ورودی کاربر (URI یا JSON خام هسته) را به [Profile] تبدیل می‌کند.
///
/// همه‌ی ۱۶ پروتکل پروژه پشتیبانی می‌شوند؛ متن اصلی همیشه در
/// [Profile.rawConfig] می‌ماند تا generator بتواند جزئیات را دوباره بخواند.
class ProfileImportParser {
  const ProfileImportParser();

  Profile parse(String input) {
    final String value = input.trim();

    if (value.isEmpty) {
      return _fallback(value, 'Empty Profile');
    }

    if (_looksLikeJson(value)) {
      return _parseJson(value);
    }

    switch (_schemeOf(value)) {
      case 'vmess':
        return _parseVmess(value);
      case 'vless':
        return _parseVless(value);
      case 'trojan':
        return _parseUriBased(value, ProfileType.trojan);
      case 'ss':
        return _parseShadowsocks(value);
      case 'hysteria2':
      case 'hy2':
        return _parseUriBased(value, ProfileType.hysteria2);
      case 'hysteria':
      case 'hy':
        return _parseUriBased(value, ProfileType.hysteria);
      case 'tuic':
        return _parseUriBased(value, ProfileType.tuic);
      case 'wireguard':
      case 'wg':
        return _parseUriBased(value, ProfileType.wireguard);
      case 'shadowtls':
        return _parseUriBased(value, ProfileType.shadowtls);
      case 'anytls':
        return _parseUriBased(value, ProfileType.anytls);
      case 'naive':
      case 'naive+https':
      case 'naive+quic':
        return _parseNaive(value);
      case 'tor':
        return _parseUriBased(value, ProfileType.tor);
      case 'ssh':
        return _parseUriBased(value, ProfileType.ssh);
      case 'socks':
      case 'socks4':
      case 'socks4a':
      case 'socks5':
        return _parseUriBased(value, ProfileType.socks);
      case 'http':
      case 'https':
        return _parseUriBased(value, ProfileType.http);
      default:
        return _fallback(value, 'Imported Profile');
    }
  }

  String _schemeOf(String value) {
    final int index = value.indexOf('://');
    if (index <= 0) {
      return '';
    }
    return value.substring(0, index).toLowerCase();
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

  /// JSON خام sing-box یا v2ray/Xray. اولین outbound معتبر برای
  /// نمایش نام/سرور/پورت استخراج می‌شود و کل متن در rawConfig می‌ماند.
  Profile _parseJson(String value) {
    final Map<String, dynamic> root = jsonDecode(value) as Map<String, dynamic>;

    final List<dynamic> candidates = <dynamic>[
      ...((root['outbounds'] as List<dynamic>?) ?? const <dynamic>[]),
      ...((root['endpoints'] as List<dynamic>?) ?? const <dynamic>[]),
    ];

    for (final dynamic entry in candidates) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final String protocol =
          (entry['type'] ?? entry['protocol'] ?? '').toString();
      final ProfileType type = _mapProtocol(protocol);

      if (type == ProfileType.unknown) {
        continue;
      }

      return Profile(
        id: _newId(),
        name: (entry['tag'] as String?)?.trim().isNotEmpty == true
            ? entry['tag'] as String
            : protocol.toUpperCase(),
        server: _readServer(entry),
        port: _readPort(entry),
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

    final Object? peers = outbound['peers'];
    if (peers is List<dynamic> && peers.isNotEmpty) {
      final dynamic first = peers.first;
      if (first is Map<String, dynamic>) {
        return (first['server'] as String?)?.trim() ?? '';
      }
    }

    final Object? settings = outbound['settings'];
    if (settings is Map<String, dynamic>) {
      for (final String key in const <String>['vnext', 'servers']) {
        final Object? list = settings[key];
        if (list is List<dynamic> && list.isNotEmpty) {
          final dynamic first = list.first;
          if (first is Map<String, dynamic>) {
            return (first['address'] as String?)?.trim() ?? '';
          }
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
        final int? port = int.tryParse(first['server_port']?.toString() ?? '');
        if (port != null && port > 0) {
          return port;
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
  ProfileType _mapProtocol(String protocol) {
    return ProfileTypeX.fromName(protocol);
  }

  Profile _parseVmess(String input) {
    try {
      final String payload = input.replaceFirst('vmess://', '');
      final Map<String, dynamic> json = jsonDecode(
        utf8.decode(base64Decode(base64.normalize(payload))),
      ) as Map<String, dynamic>;

      return Profile(
        id: _newId(),
        name: (json['ps'] as String?)?.trim().isNotEmpty == true
            ? json['ps'] as String
            : 'VMess',
        server: json['add'] as String? ?? '',
        port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
        type: ProfileType.vmess,
        rawConfig: input,
        isActive: false,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      // فرمت جدید vmess://uuid@host:port?params
      return _parseUriBased(input, ProfileType.vmess);
    }
  }

  /// VLESS با تشخیص خودکار Reality (security=reality یا وجود pbk).
  Profile _parseVless(String input) {
    ProfileType type = ProfileType.vless;

    try {
      final Uri uri = Uri.parse(input);
      final Map<String, String> params = uri.queryParameters;
      final String security = (params['security'] ?? '').toLowerCase();
      final bool hasPublicKey = (params['pbk'] ?? '').trim().isNotEmpty;

      if (security == 'reality' || hasPublicKey) {
        type = ProfileType.reality;
      }
    } catch (_) {
      // اگر URI شکسته بود، نوع پایه VLESS می‌ماند.
    }

    return _parseUriBased(input, type);
  }

  Profile _parseNaive(String input) {
    final String normalized = input
        .replaceFirst('naive+https://', 'https://')
        .replaceFirst('naive+quic://', 'https://')
        .replaceFirst('naive://', 'https://');

    final Profile parsed = _parseUriBased(normalized, ProfileType.naive);

    // rawConfig باید متن اصلی کاربر بماند تا generator طرح naive را بشناسد.
    return parsed.copyWith(rawConfig: input);
  }

  Profile _parseShadowsocks(String input) {
    ProfileType type = ProfileType.shadowsocks;

    try {
      final Uri uri = Uri.parse(input);
      final String plugin = (uri.queryParameters['plugin'] ?? '').toLowerCase();
      if (plugin.contains('shadow-tls')) {
        type = ProfileType.shadowtls;
      }
    } catch (_) {
      // نادیده می‌گیریم؛ نوع پایه Shadowsocks است.
    }

    return _parseUriBased(input, type);
  }

  Profile _parseUriBased(String input, ProfileType type) {
    try {
      final Uri uri = Uri.parse(input);
      final String fragment = Uri.decodeComponent(uri.fragment).trim();

      return Profile(
        id: _newId(),
        name: fragment.isEmpty ? type.label : fragment,
        server: uri.host,
        port: uri.hasPort ? uri.port : type.defaultPort,
        type: type,
        rawConfig: input,
        isActive: false,
        createdAt: DateTime.now(),
      );
    } catch (_) {
      return Profile(
        id: _newId(),
        name: type.label,
        server: '',
        port: 0,
        type: type,
        rawConfig: input,
        isActive: false,
        createdAt: DateTime.now(),
      );
    }
  }

  Profile _fallback(String value, String name) {
    return Profile(
      id: _newId(),
      name: name,
      server: '',
      port: 0,
      type: ProfileType.unknown,
      rawConfig: value,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
