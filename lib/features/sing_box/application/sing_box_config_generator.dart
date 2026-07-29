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
        _wrap(_v2rayConverter.convert(json, tag: _safeTag(profile))),
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
          'detour': 'proxy',
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
    final String tag = _safeTag(profile);

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
      'server': profile.server,
      'server_port': profile.port,
      'system_interface': false,
      'local_address': [
        _require(data['local_address'], 'WireGuard local_address')
      ],
      'private_key': _require(data['private_key'], 'WireGuard private_key'),
      'peer_public_key':
          _require(data['peer_public_key'], 'WireGuard peer_public_key'),
      if (data['pre_shared_key'] != null)
        'pre_shared_key': data['pre_shared_key'],
      'mtu': data['mtu'] ?? 1420,
    };
  }

  Map<String, dynamic> _buildHysteria2Outbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'hysteria2',
      'tag': tag,
      'server': profile.server,
      'server_port': profile.port,
      'password': _require(data['password'], 'Hysteria2 password'),
      if (data['obfs'] != null)
        'obfs': {
          'type': data['obfs_type'] ?? 'salamander',
          'password': data['obfs'],
        },
      'tls': {
        'enabled': true,
        'server_name': data['sni'] ?? profile.server,
        'insecure': data['insecure'] ?? false,
      }
    };
  }

  Map<String, dynamic> _buildTuicOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'tuic',
      'tag': tag,
      'server': profile.server,
      'server_port': profile.port,
      'uuid': _require(data['uuid'], 'TUIC uuid'),
      'password': _require(data['password'], 'TUIC password'),
      'congestion_control': data['congestion_control'] ?? 'bbr',
      'tls': {
        'enabled': true,
        'server_name': data['sni'] ?? profile.server,
        'insecure': data['insecure'] ?? false,
        'alpn': data['alpn'] ?? ['h3'],
      }
    };
  }

  // ... (VMess, VLESS, Trojan, SS implementation remains same or adapted to match project standards)
  Map<String, dynamic> _buildVmessOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': profile.server,
      'server_port': profile.port,
      'uuid': _require(data['uuid'], 'VMess uuid'),
      'security': data['security'] ?? 'auto',
      'alter_id': data['alterId'] ?? 0,
    };
  }

  Map<String, dynamic> _buildVlessOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': profile.server,
      'server_port': profile.port,
      'uuid': _require(data['uuid'], 'VLESS uuid'),
      'flow': data['flow'] ?? '',
    };
  }

  Map<String, dynamic> _buildTrojanOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': profile.server,
      'server_port': profile.port,
      'password': _require(data['password'], 'Trojan password'),
    };
  }

  Map<String, dynamic> _buildShadowsocksOutbound(Profile profile, String tag) {
    final Map<String, dynamic> data = _decodeRawConfig(profile.rawConfig);
    return <String, dynamic>{
      'type': 'shadowsocks',
      'tag': tag,
      'server': profile.server,
      'server_port': profile.port,
      'method': _require(data['method'], 'Shadowsocks method'),
      'password': _require(data['password'], 'Shadowsocks password'),
    };
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
            outbound['tag'] = 'proxy';
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

  String _safeTag(Profile profile) {
    return 'proxy';
  }

  dynamic _require(dynamic value, String name) {
    if (value == null) {
      throw SingBoxConfigException('$name is required');
    }
    return value;
  }
}
