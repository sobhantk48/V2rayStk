import 'dart:convert';

import '../domain/profile.dart';
import '../domain/profile_type.dart';

class ProfileImportParser {
  Profile parse(String input) {
    final String value = input.trim();

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
