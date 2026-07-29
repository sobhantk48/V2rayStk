import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../domain/sing_box_config.dart';
import '../domain/sing_box_config_exception.dart';
import 'v2ray_outbound_converter.dart';

class SingBoxConfigGenerator {
  const SingBoxConfigGenerator();

  /// این مقادیر باید با establishTun در V2rayVpnService.kt یکسان بمانند.
  static const int tunMtu = 1500;
  static const String tunAddress = '172.19.0.1/28';
  static const String tunInterfaceName = 'tun0';
  static const String dnsRemoteAddress = 'https://1.1.1.1/dns-query';
  static const String dnsDirectAddress = '1.1.1.1';

  /// تگ ثابت خروجی اصلی. رول‌های dns و route به همین تگ وابسته‌اند.
  static const String proxyTag = 'proxy';

  static const V2rayOutboundConverter _v2rayConverter =
      V2rayOutboundConverter();

  static const Set<String> _helperOutboundTypes = <String>{
    'direct',
    'block',
    'dns',
  };

  SingBoxConfig generate(Profile profile) {
    final Map<String, dynamic>? json = _tryDecodeJsonObject(profile.rawConfig);

    if (json != null) {
      if (_looksLikeSingBoxConfig(json)) {
        return SingBoxConfig(_adoptSingBoxConfig(json));
      }
      return SingBoxConfig(
        _wrap(_v2rayConverter.convert(json, tag: proxyTag)),
      );
    }

    return SingBoxConfig(_wrap(_buildOutbound(profile)));
  }

  // --------------------------------------------------------------- templates

  Map<String, dynamic> _wrap(Map<String, dynamic> outbound) {
    return <String, dynamic>{
      'log': <String, dynamic>{
        'level': 'info',
        'timestamp': true,
      },
      'dns': _defaultDns(),
      'inbounds': <Map<String, dynamic>>[
        _tunInbound(),
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
          <String, dynamic>{
            'protocol': 'dns',
            'outbound': 'dns-out',
          },
        ],
        'auto_detect_interface': true,
      },
      'experimental': _experimental(),
    };
  }

  Map<String, dynamic> _tunInbound() {
    return <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': tunInterfaceName,
      'address': <String>[tunAddress],
      'mtu': tunMtu,
      'auto_route': true,
      'strict_route': true,
      'stack': 'gvisor',
      'sniff': true,
    };
  }

  Map<String, dynamic> _defaultDns() {
    return <String, dynamic>{
      'servers': <Map<String, dynamic>>[
        <String, dynamic>{
          'tag': 'dns-remote',
          'address': dnsRemoteAddress,
          'detour': proxyTag,
        },
        <String, dynamic>{
          'tag': 'dns-direct',
          'address': dnsDirectAddress,
          'detour': 'direct',
        },
      ],
      'rules': <Map<String, dynamic>>[
        <String, dynamic>{
          'outbound': 'any',
          'server': 'dns-remote',
        },
      ],
      'strategy': 'ipv4_only',
    };
  }

  Map<String, dynamic> _experimental() {
    return <String, dynamic>{
      'clash_api': <String, dynamic>{
        'external_controller': AppConstants.clashApiListenAddress,
        'external_ui': 'ui',
        'secret': AppConstants.clashApiSecret,
        'default_mode': 'rule',
      },
    };
  }

  // ---------------------------------------------------------------- outbounds

  Map<String, dynamic> _buildOutbound(Profile profile) {
    const String tag = proxyTag;

    switch (profile.type) {
      case ProfileType.vmess:
        return _buildVmessOutbound(profile, tag);
      case ProfileType.vless:
        return _buildVlessOutbound(profile, tag);
      case ProfileType.trojan:
        return _buildTrojanOutbound(profile, tag);
      case ProfileType.shadowsocks:
        return _buildShadowsocksOutbound(profile, tag);
      case ProfileType.wireguard:
        return _buildWireGuardOutbound(profile, tag);
      case ProfileType.hysteria2:
        return _buildHysteria2Outbound(profile, tag);
      case ProfileType.tuic:
        return _buildTuicOutbound(profile, tag);
      default:
        throw SingBoxConfigException(
          'Protocol ${profile.type} is not implemented yet.',
        );
    }
  }

  Map<String, dynamic> _buildWireGuardOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'wireguard',
      'tag': tag,
      'server': _requireServer(profile),
      'server_port': _requirePort(profile),
      'system_interface': false,
      'local_address': _asStringList(
        _require(data['local_address'], 'WireGuard local_address'),
      ),
      'private_key':
          _require(data['private_key'], 'WireGuard private_key').toString(),
      'peer_public_key': _require(
        data['peer_public_key'],
        'WireGuard peer_public_key',
      ).toString(),
      if (data['pre_shared_key'] != null)
        'pre_shared_key': data['pre_shared_key'].toString(),
      'mtu': _asInt(data['mtu']) ?? 1420,
    };
  }

  Map<String, dynamic> _buildHysteria2Outbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    final String server = _requireServer(profile);
    return <String, dynamic>{
      'type': 'hysteria2',
      'tag': tag,
      'server': server,
      'server_port': _requirePort(profile),
      'password': _require(data['password'], 'Hysteria2 password').toString(),
      if (data['obfs'] != null)
        'obfs': <String, dynamic>{
          'type': (data['obfs_type'] ?? 'salamander').toString(),
          'password': data['obfs'].toString(),
        },
      if (data['up_mbps'] != null) 'up_mbps': _asInt(data['up_mbps']),
      if (data['down_mbps'] != null) 'down_mbps': _asInt(data['down_mbps']),
      'tls': <String, dynamic>{
        'enabled': true,
        'server_name': (data['sni'] ?? server).toString(),
        'insecure': _asBool(data['insecure']) ?? false,
        if (data['alpn'] != null) 'alpn': _asStringList(data['alpn']),
      },
    };
  }

  Map<String, dynamic> _buildTuicOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    final String server = _requireServer(profile);
    return <String, dynamic>{
      'type': 'tuic',
      'tag': tag,
      'server': server,
      'server_port': _requirePort(profile),
      'uuid': _require(data['uuid'], 'TUIC uuid').toString(),
      'password': _require(data['password'], 'TUIC password').toString(),
      'congestion_control':
          (data['congestion_control'] ?? 'bbr').toString(),
      if (data['udp_relay_mode'] != null)
        'udp_relay_mode': data['udp_relay_mode'].toString(),
      'tls': <String, dynamic>{
        'enabled': true,
        'server_name': (data['sni'] ?? server).toString(),
        'insecure': _asBool(data['insecure']) ?? false,
        'alpn': data['alpn'] != null
            ? _asStringList(data['alpn'])
            : <String>['h3'],
      },
    };
  }

  Map<String, dynamic> _buildVmessOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    final String server = _requireServer(profile);
    final Map<String, dynamic>? tls = _buildTls(data, server);
    final Map<String, dynamic>? transport = _buildTransport(data);
    return <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': server,
      'server_port': _requirePort(profile),
      'uuid': _require(data['uuid'], 'VMess uuid').toString(),
      'security': (data['security'] ?? 'auto').toString(),
      'alter_id': _asInt(data['alterId']) ?? _asInt(data['alter_id']) ?? 0,
      if (tls != null) 'tls': tls,
      if (transport != null) 'transport': transport,
    };
  }

  Map<String, dynamic> _buildVlessOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    final String server = _requireServer(profile);
    final Map<String, dynamic>? tls = _buildTls(data, server);
    final Map<String, dynamic>? transport = _buildTransport(data);
    final String flow = (data['flow'] ?? '').toString();
    return <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': server,
      'server_port': _requirePort(profile),
      'uuid': _require(data['uuid'], 'VLESS uuid').toString(),
      if (flow.isNotEmpty) 'flow': flow,
      if (tls != null) 'tls': tls,
      if (transport != null) 'transport': transport,
    };
  }

  Map<String, dynamic> _buildTrojanOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    final String server = _requireServer(profile);
    final Map<String, dynamic>? transport = _buildTransport(data);
    return <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': server,
      'server_port': _requirePort(profile),
      'password': _require(data['password'], 'Trojan password').toString(),
      'tls': _buildTls(data, server) ??
          <String, dynamic>{
            'enabled': true,
            'server_name': server,
            'insecure': _asBool(data['insecure']) ?? false,
          },
      if (transport != null) 'transport': transport,
    };
  }

  Map<String, dynamic> _buildShadowsocksOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'shadowsocks',
      'tag': tag,
      'server': _requireServer(profile),
      'server_port': _requirePort(profile),
      'method': _require(data['method'], 'Shadowsocks method').toString(),
      'password': _require(data['password'], 'Shadowsocks password').toString(),
      if (data['plugin'] != null) 'plugin': data['plugin'].toString(),
      if (data['plugin_opts'] != null)
        'plugin_opts': data['plugin_opts'].toString(),
    };
  }

  // ------------------------------------------------------------ tls/transport

  Map<String, dynamic>? _buildTls(Map<String, dynamic> data, String server) {
    final String securityValue =
        (data['tls'] ?? data['security'] ?? '').toString().toLowerCase();
    final bool isReality = securityValue == 'reality' ||
        (data['public_key'] ?? data['pbk']) != null;
    final bool isTls =
        isReality || securityValue == 'tls' || securityValue == 'reality';

    if (!isTls) {
      return null;
    }

    final String sni =
        (data['sni'] ?? data['serverName'] ?? server).toString();

    final Map<String, dynamic> tls = <String, dynamic>{
      'enabled': true,
      'server_name': sni,
      'insecure': _asBool(data['insecure']) ?? _asBool(data['allowInsecure']) ??
          false,
    };

    if (data['alpn'] != null) {
      tls['alpn'] = _asStringList(data['alpn']);
    }

    final Object? fingerprint = data['fp'] ?? data['fingerprint'];
    if (fingerprint != null) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint.toString(),
      };
    }

    if (isReality) {
      final Object? publicKey = data['public_key'] ?? data['pbk'];
      tls['reality'] = <String, dynamic>{
        'enabled': true,
        'public_key': _require(publicKey, 'Reality public_key').toString(),
        'short_id': (data['short_id'] ?? data['sid'] ?? '').toString(),
      };
      tls['insecure'] = false;
    }

    return tls;
  }

  Map<String, dynamic>? _buildTransport(Map<String, dynamic> data) {
    final String network =
        (data['network'] ?? data['net'] ?? data['type'] ?? '')
            .toString()
            .toLowerCase();

    switch (network) {
      case 'ws':
      case 'websocket':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'ws',
          'path': (data['path'] ?? '/').toString(),
        };
        final Object? host = data['host'] ?? data['headerHost'];
        if (host != null && host.toString().isNotEmpty) {
          transport['headers'] = <String, dynamic>{
            'Host': host.toString(),
          };
        }
        if (data['max_early_data'] != null) {
          transport['max_early_data'] = _asInt(data['max_early_data']);
        }
        if (data['early_data_header_name'] != null) {
          transport['early_data_header_name'] =
              data['early_data_header_name'].toString();
        }
        return transport;
      case 'grpc':
        return <String, dynamic>{
          'type': 'grpc',
          'service_name':
              (data['service_name'] ?? data['serviceName'] ?? data['path'] ?? '')
                  .toString(),
        };
      case 'http':
      case 'h2':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'http',
          'path': (data['path'] ?? '/').toString(),
        };
        final Object? host = data['host'];
        if (host != null && host.toString().isNotEmpty) {
          transport['host'] = _asStringList(host);
        }
        return transport;
      case 'httpupgrade':
        return <String, dynamic>{
          'type': 'httpupgrade',
          'path': (data['path'] ?? '/').toString(),
          if (data['host'] != null) 'host': data['host'].toString(),
        };
      case 'quic':
        return <String, dynamic>{'type': 'quic'};
      default:
        return null;
    }
  }

  // ------------------------------------------------------------------ helpers

  Map<String, dynamic> _adoptSingBoxConfig(Map<String, dynamic> json) {
    final Map<String, dynamic> config = Map<String, dynamic>.from(json);

    config['inbounds'] = <Map<String, dynamic>>[_tunInbound()];

    final Object? outbounds = config['outbounds'];
    if (outbounds is List && outbounds.isNotEmpty) {
      for (int i = 0; i < outbounds.length; i++) {
        final Object? item = outbounds[i];
        if (item is Map) {
          final Map<String, dynamic> outbound = Map<String, dynamic>.from(item);
          final String type = (outbound['type'] ?? '').toString();
          if (!_helperOutboundTypes.contains(type)) {
            outbound['tag'] = proxyTag;
            outbounds[i] = outbound;
            break;
          }
        }
      }
    }

    config['experimental'] = _experimental();
    return config;
  }

  bool _looksLikeSingBoxConfig(Map<String, dynamic> json) {
    return json.containsKey('outbounds') || json.containsKey('inbounds');
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String raw) {
    try {
      final dynamic decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decodeRawConfig(String raw) {
    try {
      return Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (e) {
      throw SingBoxConfigException('Invalid profile raw config: $e');
    }
  }

  String _requireServer(Profile profile) {
    final String? server = profile.server;
    if (server == null || server.trim().isEmpty) {
      throw const SingBoxConfigException('Server address is required');
    }
    return server.trim();
  }

  int _requirePort(Profile profile) {
    final int? port = profile.port;
    if (port == null || port <= 0 || port > 65535) {
      throw const SingBoxConfigException('Server port is required');
    }
    return port;
  }

  Object _require(Object? value, String name) {
    if (value == null) {
      throw SingBoxConfigException('$name is required');
    }
    return value;
  }

  List<String> _asStringList(Object? value) {
    if (value == null) {
      return <String>[];
    }
    if (value is List) {
      return value.map((Object? e) => e.toString()).toList();
    }
    return value
        .toString()
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool? _asBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    final String s = value.toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return null;
  }
}
