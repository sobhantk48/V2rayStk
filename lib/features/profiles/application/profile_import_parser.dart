import 'dart:convert';

import '../domain/profile.dart';
import '../domain/profile_type.dart';

/// ورودی کاربر (URI یا JSON خام هسته) را به [Profile] تبدیل می‌کند.
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

    if (value.startsWith('vmess://')) {
      return _parseVmess(value);
    }

    if (value.startsWith('vless://')) {
      return _parseUriBased(value, ProfileType.vless);
    }

    if (value.startsWith('trojan://')) {
      return _parseUriBased(value, ProfileType.trojan);
    }

    if (value.startsWith('ss://')) {
      return _parseShadowsocks(value);
    }

    return _fallback(value, 'Imported Profile');
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

    final List<dynamic> outbounds =
        (root['outbounds'] as List<dynamic>?) ?? const <dynamic>[];

    for (final dynamic entry in outbounds) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final String protocol =
          (entry['type'] ?? entry['protocol'] ?? '').toString();
      final ProfileType type = _mapProtocol(protocol);

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
    switch (protocol.trim().toLowerCase()) {
      case 'vmess':
        return ProfileType.vmess;
      case 'vless':
        return ProfileType.vless;
      case 'trojan':
        return ProfileType.trojan;
      case 'shadowsocks':
      case 'ss':
        return ProfileType.shadowsocks;
      default:
        return ProfileType.unknown;
    }
  }

  Profile _parseVmess(String input) {
    final String payload = input.replaceFirst('vmess://', '');
    final String normalized = base64.normalize(payload);
    final Map<String, dynamic> json = jsonDecode(
      utf8.decode(base64Decode(normalized)),
    ) as Map<String, dynamic>;

    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['ps'] as String? ?? 'VMess',
      server: json['add'] as String? ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
      type: ProfileType.vmess,
      rawConfig: input,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  Profile _parseUriBased(String input, ProfileType type) {
    final Uri uri = Uri.parse(input);

    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: uri.fragment.isEmpty ? type.name.toUpperCase() : uri.fragment,
      server: uri.host,
      port: uri.port,
      type: type,
      rawConfig: input,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  Profile _parseShadowsocks(String input) {
    final Uri uri = Uri.parse(input);

    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: uri.fragment.isEmpty ? 'Shadowsocks' : uri.fragment,
      server: uri.host,
      port: uri.port,
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
