import 'dart:convert';

import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../domain/sing_box_config.dart';
import '../domain/sing_box_config_exception.dart';

class SingBoxConfigGenerator {
  const SingBoxConfigGenerator();

  /// این مقادیر باید با establishTun در V2rayVpnService.kt یکسان بمانند.
  static const int tunMtu = 9000;
  static const String tunAddress = '172.19.0.1/30';
  static const String tunInterfaceName = 'tun0';
  static const String dnsServerAddress = '8.8.8.8';

  SingBoxConfig generate(Profile profile) {
    final Map<String, dynamic> outbound = _buildOutbound(profile);
    final String proxyTag = outbound['tag'] as String;

    return SingBoxConfig(
      <String, dynamic>{
        'log': <String, dynamic>{
          'level': 'info',
          'timestamp': true,
        },
        'dns': <String, dynamic>{
          'servers': <Map<String, dynamic>>[
            <String, dynamic>{
              'tag': 'dns-remote',
              'address': dnsServerAddress,
              'strategy': 'ipv4_only',
              'detour': proxyTag,
            },
            <String, dynamic>{
              'tag': 'dns-direct',
              'address': dnsServerAddress,
              'strategy': 'ipv4_only',
              'detour': 'direct',
            },
          ],
          'final': 'dns-remote',
          'strategy': 'ipv4_only',
          'independent_cache': true,
        },
        'inbounds': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'tun',
            'tag': 'tun-in',
            'interface_name': tunInterfaceName,
            'mtu': tunMtu,
            'address': <String>[tunAddress],
            // مسیر و آدرس توسط VpnService.Builder ساخته می‌شود،
            // پس هسته نباید خودش route اضافه کند.
            'auto_route': false,
            'strict_route': false,
            'stack': 'gvisor',
            'sniff': true,
            'sniff_override_destination': false,
          },
        ],
        'outbounds': <Map<String, dynamic>>[
          outbound,
          <String, dynamic>{
            'type': 'direct',
            'tag': 'direct',
          },
          <String, dynamic>{
            'type': 'block',
            'tag': 'block',
          },
          <String, dynamic>{
            'type': 'dns',
            'tag': 'dns-out',
          },
        ],
        'route': <String, dynamic>{
          'rules': <Map<String, dynamic>>[
            // پرس‌وجوهای DNS داخل tun باید به outbound نوع dns برود،
            // وگرنه resolve انجام نمی‌شود.
            <String, dynamic>{
              'protocol': 'dns',
              'outbound': 'dns-out',
            },
            <String, dynamic>{
              'port': <int>[53],
              'outbound': 'dns-out',
            },
            // ترافیک شبکه‌های محلی از تونل خارج می‌شود.
            <String, dynamic>{
              'ip_is_private': true,
              'outbound': 'direct',
            },
          ],
          'final': proxyTag,
          'auto_detect_interface': true,
        },
        'experimental': <String, dynamic>{
          'cache_file': <String, dynamic>{
            'enabled': true,
          },
          // آمار لحظه‌ای برای CommandClient در سمت اندروید.
          'clash_api': <String, dynamic>{
            'external_controller': '127.0.0.1:9090',
          },
        },
      },
    );
  }

  Map<String, dynamic> _buildOutbound(Profile profile) {
    switch (profile.type) {
      case ProfileType.vmess:
        return _buildVmessOutbound(profile);
      case ProfileType.vless:
        return _buildVlessOutbound(profile);
      case ProfileType.trojan:
        return _buildTrojanOutbound(profile);
      case ProfileType.shadowsocks:
        return _buildShadowsocksOutbound(profile);
      case ProfileType.socks:
        return _buildSocksOutbound(profile);
      case ProfileType.http:
        return _buildHttpOutbound(profile);
      case ProfileType.wireguard:
      case ProfileType.hysteria2:
      case ProfileType.tuic:
      case ProfileType.unknown:
        throw SingBoxConfigException(
          'Profile type ${profile.type.name} is not supported yet in phase 2.',
        );
    }
  }

  Map<String, dynamic> _buildVmessOutbound(Profile profile) {
    final Map<String, dynamic> json = _decodeVmessJson(profile.rawConfig);

    final String server =
        (json['add'] as String? ?? profile.server ?? '').trim();
    final int serverPort =
        int.tryParse(json['port']?.toString() ?? '') ?? (profile.port ?? 0);
    final String uuid = (json['id'] as String? ?? '').trim();
    final String security = (json['scy'] as String? ?? 'auto').trim();
    final String network = (json['net'] as String? ?? 'tcp').trim();
    final String host = (json['host'] as String? ?? '').trim();
    final String path = (json['path'] as String? ?? '').trim();
    final String tlsValue = (json['tls'] as String? ?? '').trim();
    final String serverName = (json['sni'] as String? ?? host).trim();
    final String tag = _safeTag(profile);

    _require(server.isNotEmpty, 'VMess server is missing.');
    _require(serverPort > 0, 'VMess port is invalid.');
    _require(uuid.isNotEmpty, 'VMess uuid is missing.');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': server,
      'server_port': serverPort,
      'uuid': uuid,
      'security': security,
    };

    if (tlsValue == 'tls') {
      outbound['tls'] = <String, dynamic>{
        'enabled': true,
        if (serverName.isNotEmpty) 'server_name': serverName,
      };
    }

    if (network == 'ws') {
      outbound['transport'] = <String, dynamic>{
        'type': 'ws',
        if (path.isNotEmpty) 'path': path,
        if (host.isNotEmpty)
          'headers': <String, dynamic>{
            'Host': host,
          },
      };
    }

    return outbound;
  }

  Map<String, dynamic> _buildVlessOutbound(Profile profile) {
    final Uri uri = Uri.parse(profile.rawConfig);
    final String uuid = uri.userInfo.trim();
    final String flow = (uri.queryParameters['flow'] ?? '').trim();
    final String security = (uri.queryParameters['security'] ?? '').trim();
    final String type = (uri.queryParameters['type'] ?? 'tcp').trim();
    final String host = (uri.queryParameters['host'] ?? '').trim();
    final String path = (uri.queryParameters['path'] ?? '').trim();
    final String sni = (uri.queryParameters['sni'] ?? '').trim();

    _require(uri.host.isNotEmpty, 'VLESS server is missing.');
    _require(uri.port > 0, 'VLESS port is invalid.');
    _require(uuid.isNotEmpty, 'VLESS uuid is missing.');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vless',
      'tag': _safeTag(profile),
      'server': uri.host,
      'server_port': uri.port,
      'uuid': uuid,
    };

    if (flow.isNotEmpty) {
      outbound['flow'] = flow;
    }

    if (security == 'tls' || security == 'reality') {
      outbound['tls'] = <String, dynamic>{
        'enabled': true,
        if (sni.isNotEmpty) 'server_name': sni,
      };
    }

    if (type == 'ws') {
      outbound['transport'] = <String, dynamic>{
        'type': 'ws',
        if (path.isNotEmpty) 'path': path,
        if (host.isNotEmpty)
          'headers': <String, dynamic>{
            'Host': host,
          },
      };
    }

    return outbound;
  }

  Map<String, dynamic> _buildTrojanOutbound(Profile profile) {
    final Uri uri = Uri.parse(profile.rawConfig);
    final String password = uri.userInfo.trim();
    final String type = (uri.queryParameters['type'] ?? 'tcp').trim();
    final String host = (uri.queryParameters['host'] ?? '').trim();
    final String path = (uri.queryParameters['path'] ?? '').trim();
    final String sni = (uri.queryParameters['sni'] ?? '').trim();
    final String security =
        (uri.queryParameters['security'] ?? 'tls').trim();

    _require(uri.host.isNotEmpty, 'Trojan server is missing.');
    _require(uri.port > 0, 'Trojan port is invalid.');
    _require(password.isNotEmpty, 'Trojan password is missing.');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': _safeTag(profile),
      'server': uri.host,
      'server_port': uri.port,
      'password': password,
    };

    if (security == 'tls' || security.isEmpty) {
      outbound['tls'] = <String, dynamic>{
        'enabled': true,
        if (sni.isNotEmpty) 'server_name': sni,
      };
    }

    if (type == 'ws') {
      outbound['transport'] = <String, dynamic>{
        'type': 'ws',
        if (path.isNotEmpty) 'path': path,
        if (host.isNotEmpty)
          'headers': <String, dynamic>{
            'Host': host,
          },
      };
    }

    return outbound;
  }

  Map<String, dynamic> _buildShadowsocksOutbound(Profile profile) {
    final Uri uri = Uri.parse(profile.rawConfig);

    String method = '';
    String password = '';

    if (uri.userInfo.contains(':')) {
      final List<String> parts = uri.userInfo.split(':');
      method = parts.first.trim();
      password = parts.sublist(1).join(':').trim();
    } else if (uri.userInfo.isNotEmpty) {
      final String normalized = base64.normalize(uri.userInfo);
      final String decoded = utf8.decode(base64Decode(normalized));
      final List<String> parts = decoded.split(':');
      if (parts.isNotEmpty) {
        method = parts.first.trim();
      }
      if (parts.length > 1) {
        password = parts.sublist(1).join(':').trim();
      }
    }

    _require(uri.host.isNotEmpty, 'Shadowsocks server is missing.');
    _require(uri.port > 0, 'Shadowsocks port is invalid.');
    _require(method.isNotEmpty, 'Shadowsocks method is missing.');
    _require(password.isNotEmpty, 'Shadowsocks password is missing.');

    return <String, dynamic>{
      'type': 'shadowsocks',
      'tag': _safeTag(profile),
      'server': uri.host,
      'server_port': uri.port,
      'method': method,
      'password': password,
    };
  }

  Map<String, dynamic> _buildSocksOutbound(Profile profile) {
    final Uri uri = Uri.parse(profile.rawConfig);

    _require(uri.host.isNotEmpty, 'SOCKS server is missing.');
    _require(uri.port > 0, 'SOCKS port is invalid.');

    return <String, dynamic>{
      'type': 'socks',
      'tag': _safeTag(profile),
      'server': uri.host,
      'server_port': uri.port,
      if (uri.userInfo.isNotEmpty) ...<String, dynamic>{
        'username': uri.userInfo.contains(':')
            ? uri.userInfo.split(':').first
            : uri.userInfo,
        'password': uri.userInfo.contains(':')
            ? uri.userInfo.split(':').sublist(1).join(':')
            : '',
      },
    };
  }

  Map<String, dynamic> _buildHttpOutbound(Profile profile) {
    final Uri uri = Uri.parse(profile.rawConfig);

    _require(uri.host.isNotEmpty, 'HTTP server is missing.');
    _require(uri.port > 0, 'HTTP port is invalid.');

    return <String, dynamic>{
      'type': 'http',
      'tag': _safeTag(profile),
      'server': uri.host,
      'server_port': uri.port,
      if (uri.userInfo.isNotEmpty) ...<String, dynamic>{
        'username': uri.userInfo.contains(':')
            ? uri.userInfo.split(':').first
            : uri.userInfo,
        'password': uri.userInfo.contains(':')
            ? uri.userInfo.split(':').sublist(1).join(':')
            : '',
      },
    };
  }

  Map<String, dynamic> _decodeVmessJson(String rawConfig) {
    final String payload = rawConfig.replaceFirst('vmess://', '');
    final String normalized = base64.normalize(payload);
    final String decoded = utf8.decode(base64Decode(normalized));

    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  String _safeTag(Profile profile) {
    final String base =
        profile.name.trim().isEmpty ? profile.id : profile.name;
    return base.replaceAll(RegExp(r'\s+'), '_');
  }

  void _require(bool condition, String message) {
    if (!condition) {
      throw SingBoxConfigException(message);
    }
  }
}
