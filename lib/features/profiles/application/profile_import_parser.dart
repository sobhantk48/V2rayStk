import 'dart:convert';

import '../../sing_box/application/v2ray_outbound_converter.dart';
import '../domain/profile.dart';
import '../domain/profile_type.dart';

class ProfileImportParser {
  static const V2rayOutboundConverter _converter = V2rayOutboundConverter();

  Profile parse(String input) {
    final String value = input.trim();

    if (value.startsWith('{')) {
      return _parseJsonConfig(value);
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

    if (value.startsWith('socks://') || value.startsWith('socks5://')) {
      return _parseUriBased(value, ProfileType.socks);
    }

    if (value.startsWith('hysteria2://') || value.startsWith('hy2://')) {
      return _parseUriBased(value, ProfileType.hysteria2);
    }

    if (value.startsWith('tuic://')) {
      return _parseUriBased(value, ProfileType.tuic);
    }

    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: 'Imported Profile',
      server: '',
      port: 0,
      type: ProfileType.unknown,
      rawConfig: value,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  /// کانفیگ JSON خام (v2ray/Xray یا sing-box). محتوای اصلی دست‌نخورده
  /// در rawConfig می‌ماند و مولد کانفیگ خودش آن را ترجمه می‌کند.
  Profile _parseJsonConfig(String input) {
    final Object? decoded = jsonDecode(input);
    if (decoded is! Map) {
      throw const FormatException('JSON config must be an object.');
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(decoded);

    String name = (json['remarks'] ?? json['ps'] ?? '').toString().trim();
    String server = '';
    int port = 0;
    ProfileType type = ProfileType.unknown;

    try {
      final Map<String, dynamic> outbound = _converter.pickOutbound(json);
      type = _mapProtocol(
        (outbound['protocol'] ?? outbound['type'] ?? '').toString(),
      );
      if (name.isEmpty) {
        name = (outbound['tag'] ?? '').toString().trim();
      }
      server = _serverOf(outbound);
      port = _portOf(outbound);
    } catch (_) {
      // اگر استخراج outbound ممکن نبود، پروفایل به عنوان JSON خام
      // ذخیره می‌شود تا کاربر بتواند بعداً اصلاحش کند.
    }

    return Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.isEmpty ? 'JSON Config' : name,
      server: server,
      port: port,
      type: type,
      rawConfig: input,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  ProfileType _mapProtocol(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'vmess':
        return ProfileType.vmess;
      case 'vless':
        return ProfileType.vless;
      case 'trojan':
        return ProfileType.trojan;
      case 'shadowsocks':
ನ      case 'ss':
        return ProfileType.shadowsocks;
      case 'socks':
      case 'socks5':
        return ProfileType.socks;
      case 'http':
      case 'https':
        return ProfileType.http;
      case 'wireguard':
        return ProfileType.wireguard;
      case 'hysteria2':
        return ProfileType.hysteria2;
      case 'tuic':
        return ProfileType.tuic;
      default:
        return ProfileType.unknown;
    }
  }

  String _serverOf(Map<String, dynamic> outbound) {
    if (outbound['server'] != null) {
      return outbound['server'].toString();
    }

    final Object? settings = outbound['settings'];
    if (settings is Map) {
      final Object? node = settings['vnext'] ?? settings['servers'];
      if (node is List && node.isNotEmpty && node.first is Map) {
        return ((node.first as Map)['address'] ?? '').toString();
      }
    }

    return '';
  }

  int _portOf(Map<String, dynamic> outbound) {
    if (outbound['server_port'] != null) {
      return int.tryParse(outbound['server_port'].toString()) ?? 0;
    }

    final Object? settings = outbound['settings'];
    if (settings is Map) {
      final Object? node = settings['vnext'] ?? settings['servers'];
      if (node is List && node.isNotEmpty && node.first is Map) {
        return int.tryParse(((node.first as Map)['port'] ?? '').toString()) ?? 0;
      }
    }

    return 0;
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
}
