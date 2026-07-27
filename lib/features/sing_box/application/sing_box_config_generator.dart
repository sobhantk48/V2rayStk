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
      // کانفیگ کامل sing-box: ساختار خودش را نگه می‌داریم و فقط
      // ورودی tun و clash_api را جایگزین/تزریق می‌کنیم.
      if (_looksLikeSingBoxConfig(json)) {
        return SingBoxConfig(_adoptSingBoxConfig(json));
      }

      // کانفیگ v2ray/Xray: outbound را استخراج و ترجمه می‌کنیم.
      return SingBoxConfig(
        _wrap(_v2rayConverter.convert(json, tag: _safeTag(profile))),
      );
    }

    return SingBoxConfig(_wrap(_buildOutbound(profile)));
  }

  // --------------------------------------------------------------- templates

  Map<String, dynamic> _wrap(Map<String, dynamic> outbound) {
    final String proxyTag = outbound['tag'] as String;

    return <String, dynamic>{
      'log': _defaultLog(),
      'dns': _defaultDns(proxyTag),
      'inbounds': <Map<String, dynamic>>[_tunInbound()],
      'outbounds': <Map<String, dynamic>>[
        outbound,
        <String, dynamic>{'type': 'direct', 'tag': 'direct'},
        <String, dynamic>{'type': 'block', 'tag': 'block'},
        <String, dynamic>{'type': 'dns', 'tag': 'dns-out'},
      ],
      'route': <String, dynamic>{
        'rules': _baseRouteRules('dns-out'),
        'final': proxyTag,
        'auto_detect_interface': true,
      },
      'experimental': _experimental(null),
    };
  }

  Map<String, dynamic> _tunInbound() {
    return <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': tunInterfaceName,
      'mtu': tunMtu,
      'address': <String>[tunAddress],
      'auto_route': false,
      'strict_route': false,
      'stack': 'gvisor',
      'sniff': true,
      'sniff_override_destination': false,
      'domain_strategy': 'ipv4_only',
    };
  }

  Map<String, dynamic> _defaultLog() {
    return <String, dynamic>{'level': 'info', 'timestamp': true};
  }

  Map<String, dynamic> _defaultDns(String proxyTag) {
    return <String, dynamic>{
      'servers': <Map<String, dynamic>>[
        <String, dynamic>{
          'tag': 'dns-remote',
          'address': dnsRemoteAddress,
          'address_resolver': 'dns-direct',
          'strategy': 'ipv4_only',
          'detour': proxyTag,
        },
        <String, dynamic>{
          'tag': 'dns-direct',
          'address': dnsDirectAddress,
          'strategy': 'ipv4_only',
          'detour': 'direct',
        },
      ],
      'rules': <Map<String, dynamic>>[
        <String, dynamic>{'outbound': 'any', 'server': 'dns-direct'},
      ],
      'final': 'dns-remote',
      'strategy': 'ipv4_only',
      'independent_cache': true,
    };
  }

  List<Map<String, dynamic>> _dnsRules(String dnsTag) {
    return <Map<String, dynamic>>[
      <String, dynamic>{'protocol': 'dns', 'outbound': dnsTag},
      <String, dynamic>{
        'port': <int>[53],
        'outbound': dnsTag,
      },
    ];
  }

  /// QUIC (UDP/443) را مسدود می‌کند تا گوگل/یوتیوب به TCP برگردند.
  Map<String, dynamic> _blockQuicRule() {
    return <String, dynamic>{
      'network': 'udp',
      'port': <int>[443],
      'outbound': 'block',
    };
  }

  Map<String, dynamic> _experimental(Map<String, dynamic>? existing) {
    final Map<String, dynamic> result = existing == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existing);

    final Map<String, dynamic> cache = result['cache_file'] is Map
        ? Map<String, dynamic>.from(result['cache_file'] as Map)
        : <String, dynamic>{};
    cache['enabled'] = true;
    result['cache_file'] = cache;

    final Map<String, dynamic> clash = result['clash_api'] is Map
        ? Map<String, dynamic>.from(result['clash_api'] as Map)
        : <String, dynamic>{};
    clash['external_controller'] = AppConstants.clashApiListenAddress;
    // بدون secret هر اپ دیگری روی همان دستگاه می‌تواند این API را صدا بزند.
    clash['secret'] = AppConstants.clashApiSecret;
    result['clash_api'] = clash;

    return result;
  }

  // ----------------------------------------------------- sing-box json input

  bool _looksLikeSingBoxConfig(Map<String, dynamic> json) {
    final Object? outbounds = json['outbounds'];

    if (outbounds is List) {
      for (final Object? item in outbounds) {
        if (item is! Map) {
          continue;
        }
        if (item.containsKey('protocol')) {
          return false;
        }
        if (item.containsKey('type')) {
          return true;
        }
      }
    }

    return json.containsKey('experimental') || json.containsKey('endpoints');
  }

  Map<String, dynamic> _adoptSingBoxConfig(Map<String, dynamic> source) {
    final List<Map<String, dynamic>> outbounds = <Map<String, dynamic>>[
      for (final Object? item
          in (source['outbounds'] as List<Object?>? ?? const <Object?>[]))
        if (item is Map) Map<String, dynamic>.from(item),
    ];

    if (outbounds.isEmpty) {
      throw const SingBoxConfigException('sing-box config has no outbounds.');
    }

    final Set<String> tags = outbounds
        .map((Map<String, dynamic> item) => (item['tag'] ?? '').toString())
        .where((String tag) => tag.isNotEmpty)
        .toSet();

    if (!tags.contains('direct')) {
      outbounds.add(<String, dynamic>{'type': 'direct', 'tag': 'direct'});
      tags.add('direct');
    }
    if (!tags.contains('block')) {
      outbounds.add(<String, dynamic>{'type': 'block', 'tag': 'block'});
      tags.add('block');
    }

    String dnsTag = '';
    for (final Map<String, dynamic> item in outbounds) {
      if ((item['type'] ?? '').toString() == 'dns') {
        dnsTag = (item['tag'] ?? '').toString();
        break;
      }
    }
    if (dnsTag.isEmpty) {
      dnsTag = 'dns-out';
      outbounds.add(<String, dynamic>{'type': 'dns', 'tag': dnsTag});
      tags.add(dnsTag);
    }

    final Map<String, dynamic> route = source['route'] is Map
        ? Map<String, dynamic>.from(source['route'] as Map)
        : <String, dynamic>{};

    String proxyTag = (route['final'] ?? '').toString();
    if (proxyTag.isEmpty || !tags.contains(proxyTag)) {
      proxyTag = '';
      for (final Map<String, dynamic> item in outbounds) {
        final String type = (item['type'] ?? '').toString();
        final String tag = (item['tag'] ?? '').toString();
        if (_helperOutboundTypes.contains(type) || tag.isEmpty) {
          continue;
        }
        proxyTag = tag;
        break;
      }
    }
    if (proxyTag.isEmpty) {
      proxyTag = 'proxy';
      outbounds.first['tag'] = proxyTag;
    }

    final List<Map<String, dynamic>> sourceRules = <Map<String, dynamic>>[
      for (final Object? item
          in (route['rules'] as List<Object?>? ?? const <Object?>[]))
        if (item is Map) Map<String, dynamic>.from(item),
    ];

    final List<Map<String, dynamic>> rules = <Map<String, dynamic>>[
      ..._dnsRules(dnsTag),
      _blockQuicRule(),
      ...sourceRules,
      if (sourceRules.isEmpty)
        <String, dynamic>{'ip_is_private': true, 'outbound': 'direct'},
    ];

    route['rules'] = rules;
    route['final'] = proxyTag;
    route['auto_detect_interface'] = true;

    return <String, dynamic>{
      'log': source['log'] is Map
          ? Map<String, dynamic>.from(source['log'] as Map)
          : _defaultLog(),
      'dns': source['dns'] is Map
          ? Map<String, dynamic>.from(source['dns'] as Map)
          : _defaultDns(proxyTag),
      // ورودی‌های کانفیگ کاربر نادیده گرفته می‌شود؛ روی اندروید
      // فقط tun معنا دارد و باید با VpnService هم‌تراز باشد.
      'inbounds': <Map<String, dynamic>>[_tunInbound()],
      'outbounds': outbounds,
      'route': route,
      'experimental': _experimental(
        source['experimental'] is Map
            ? Map<String, dynamic>.from(source['experimental'] as Map)
            : null,
      ),
      if (source['ntp'] != null) 'ntp': source['ntp'],
      if (source['endpoints'] != null) 'endpoints': source['endpoints'],
    };
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String rawConfig) {
    final String value = rawConfig.trim();
    if (!value.startsWith('{')) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  // ------------------------------------------------------------- uri inputs

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
    final String publicKey = (uri.queryParameters['pbk'] ?? '').trim();
    final String shortId = (uri.queryParameters['sid'] ?? '').trim();
    final String fingerprint = (uri.queryParameters['fp'] ?? '').trim();
    final String serviceName =
        (uri.queryParameters['serviceName'] ?? '').trim();

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

    if (flow.isNotEmpty && flow != 'none') {
      outbound['flow'] = flow;
    }

    if (security == 'tls' || security == 'reality') {
      final Map<String, dynamic> tls = <String, dynamic>{
        'enabled': true,
        if (sni.isNotEmpty) 'server_name': sni,
      };

      if (security == 'reality') {
        _require(publicKey.isNotEmpty, 'Reality public key is missing.');
        tls['utls'] = <String, dynamic>{
          'enabled': true,
          'fingerprint': fingerprint.isEmpty ? 'chrome' : fingerprint,
        };
        tls['reality'] = <String, dynamic>{
          'enabled': true,
          'public_key': publicKey,
          'short_id': shortId,
        };
      } else if (fingerprint.isNotEmpty) {
        tls['utls'] = <String, dynamic>{
          'enabled': true,
          'fingerprint': fingerprint,
        };
      }

      outbound['tls'] = tls;
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
    } else if (type == 'grpc') {
      outbound['transport'] = <String, dynamic>{
        'type': 'grpc',
        'service_name': serviceName,
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
    final String security = (uri.queryParameters['security'] ?? 'tls').trim();

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
    final String base = profile.name.trim().isEmpty ? profile.id : profile.name;
    return base.replaceAll(RegExp(r'\s+'), '_');
  }

  void _require(bool condition, String message) {
    if (!condition) {
      throw SingBoxConfigException(message);
    }
  }

  List<Map<String, dynamic>> _baseRouteRules(String dnsTag) {
    return <Map<String, dynamic>>[
      ..._dnsRules(dnsTag),
      _blockQuicRule(),
      <String, dynamic>{
        'network': 'udp',
        'port': <int>[443],
        'outbound': 'block',
      },
      <String, dynamic>{'ip_is_private': true, 'outbound': 'direct'},
    ];
  }
}
