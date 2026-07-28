import 'dart:convert';

import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../domain/sing_box_config.dart';
import '../domain/sing_box_config_exception.dart';
import 'v2ray_outbound_converter.dart';

/// Builds a complete sing-box configuration from a [Profile].
class SingBoxConfigGenerator {
  const SingBoxConfigGenerator();

  static const int tunMtu = 1500;
  static const String tunAddress = '172.19.0.1/28';
  static const String tunInterfaceName = 'tun0';
  static const String dnsRemoteAddress = 'https://1.1.1.1/dns-query';
  static const String dnsDirectAddress = '1.1.1.1';
  static const String proxyTag = 'proxy';
  static const String clashApiAddress = '127.0.0.1:9090';

  static const V2rayOutboundConverter _v2rayConverter =
      V2rayOutboundConverter();

  static const Set<String> _helperOutboundTypes = <String>{
    'direct',
    'block',
    'dns',
  };

  /// Types that must live inside `endpoints` in modern sing-box versions.
  static const Set<String> _endpointTypes = <String>{
    'wireguard',
    'tailscale',
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

    return SingBoxConfig(_wrapAll(_buildNodes(profile)));
  }

  // ---------------------------------------------------------------------------
  // Outbound dispatch
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _buildNodes(Profile profile) {
    final String raw = profile.rawConfig.trim();

    switch (profile.type) {
      case ProfileType.vmess:
        return <Map<String, dynamic>>[_buildVmess(raw)];
      case ProfileType.vless:
      case ProfileType.reality:
        return <Map<String, dynamic>>[_buildVless(raw)];
      case ProfileType.trojan:
        return <Map<String, dynamic>>[_buildTrojan(raw)];
      case ProfileType.shadowsocks:
        return <Map<String, dynamic>>[_buildShadowsocks(raw)];
      case ProfileType.socks:
        return <Map<String, dynamic>>[_buildSocks(raw)];
      case ProfileType.http:
        return <Map<String, dynamic>>[_buildHttp(raw, forceTls: false)];
      case ProfileType.naive:
        return <Map<String, dynamic>>[_buildHttp(raw, forceTls: true)];
      case ProfileType.wireguard:
        return <Map<String, dynamic>>[_buildWireGuard(raw)];
      case ProfileType.hysteria:
        return <Map<String, dynamic>>[_buildHysteria(raw)];
      case ProfileType.hysteria2:
        return <Map<String, dynamic>>[_buildHysteria2(raw)];
      case ProfileType.tuic:
        return <Map<String, dynamic>>[_buildTuic(raw)];
      case ProfileType.anytls:
        return <Map<String, dynamic>>[_buildAnyTls(raw)];
      case ProfileType.shadowtls:
        return _buildShadowTlsChain(raw);
      case ProfileType.tor:
        return <Map<String, dynamic>>[_buildTor(raw)];
      case ProfileType.ssh:
        return <Map<String, dynamic>>[_buildSsh(raw)];
      case ProfileType.unknown:
        throw const SingBoxConfigException(
          'Unsupported or unrecognized profile link.',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Protocol builders
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildVmess(String raw) {
    final String payload = _stripScheme(raw, 'vmess');
    final Map<String, dynamic>? json = _tryDecodeJsonObject(payload) ??
        _tryDecodeJsonObject(_decodeBase64(payload) ?? '');

    if (json == null) {
      // vmess://uuid@host:port?... (rare, "v2rayN style 2" links)
      final _Link link = _parseLink(raw);
      final Map<String, dynamic> outbound = <String, dynamic>{
        'type': 'vmess',
        'tag': proxyTag,
        'server': _requireHost(link.host),
        'server_port': link.port ?? 443,
        'uuid': _requireValue(link.userInfo, 'uuid'),
        'security': link.query['scy'] ?? 'auto',
        'alter_id': _asInt(link.query['aid']) ?? 0,
      };
      _attachTls(outbound, link, defaultEnabled: false);
      _attachTransport(outbound, link);
      return outbound;
    }

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': proxyTag,
      'server': _requireHost(_asString(json['add'])),
      'server_port': _asInt(json['port']) ?? 443,
      'uuid': _requireValue(_asString(json['id']), 'uuid'),
      'security': _blankToNull(_asString(json['scy'])) ?? 'auto',
      'alter_id': _asInt(json['aid']) ?? 0,
    };

    final String tls = (_asString(json['tls']) ?? '').toLowerCase();
    final String? sni = _blankToNull(_asString(json['sni'])) ??
        _blankToNull(_asString(json['host']));

    if (tls == 'tls' || tls == 'reality') {
      outbound['tls'] = _tlsBlock(
        serverName: sni ?? _asString(json['add']),
        alpn: _splitList(_asString(json['alpn'])),
        fingerprint: _blankToNull(_asString(json['fp'])),
        insecure: _asBool(json['allowInsecure']) ?? false,
      );
    }

    final Map<String, dynamic>? transport = _transportBlock(
      network: _blankToNull(_asString(json['net'])),
      host: _blankToNull(_asString(json['host'])),
      path: _blankToNull(_asString(json['path'])),
      serviceName: _blankToNull(_asString(json['path'])),
    );

    if (transport != null) {
      outbound['transport'] = transport;
    }

    return outbound;
  }

  Map<String, dynamic> _buildVless(String raw) {
    final _Link link = _parseLink(raw);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vless',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 443,
      'uuid': _requireValue(link.userInfo, 'uuid'),
    };

    final String? flow = _blankToNull(link.query['flow']);
    if (flow != null && flow != 'none') {
      outbound['flow'] = flow;
    }

    final String? encryption = _blankToNull(link.query['encryption']);
    if (encryption != null && encryption != 'none') {
      outbound['packet_encoding'] = 'xudp';
    }

    _attachTls(outbound, link, defaultEnabled: false);
    _attachTransport(outbound, link);

    return outbound;
  }

  Map<String, dynamic> _buildTrojan(String raw) {
    final _Link link = _parseLink(raw);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 443,
      'password': _requireValue(link.userInfo, 'password'),
    };

    _attachTls(outbound, link, defaultEnabled: true);
    _attachTransport(outbound, link);

    return outbound;
  }

  Map<String, dynamic> _buildShadowsocks(String raw) {
    final _ShadowsocksParts parts = _parseShadowsocks(raw);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': proxyTag,
      'server': _requireHost(parts.host),
      'server_port': parts.port,
      'method': parts.method,
      'password': parts.password,
      'udp_over_tcp': false,
    };

    final String? plugin = _blankToNull(parts.query['plugin']);
    if (plugin != null && !plugin.startsWith('shadow-tls')) {
      final List<String> chunks = plugin.split(';');
      outbound['plugin'] = chunks.first;
      if (chunks.length > 1) {
        outbound['plugin_opts'] = chunks.skip(1).join(';');
      }
    }

    return outbound;
  }

  Map<String, dynamic> _buildSocks(String raw) {
    final _Link link = _parseLink(raw);
    final _Credentials creds = _splitCredentials(link.userInfo);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'socks',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 1080,
      'version': link.scheme == 'socks4' ? '4' : '5',
    };

    if (creds.username != null) {
      outbound['username'] = creds.username;
    }
    if (creds.password != null) {
      outbound['password'] = creds.password;
    }

    return outbound;
  }

  Map<String, dynamic> _buildHttp(String raw, {required bool forceTls}) {
    final _Link link = _parseLink(raw);
    final _Credentials creds = _splitCredentials(link.userInfo);
    final bool tlsEnabled = forceTls ||
        link.scheme == 'https' ||
        link.scheme.endsWith('+https') ||
        _asBool(link.query['tls']) == true;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'http',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? (tlsEnabled ? 443 : 8080),
    };

    if (creds.username != null) {
      outbound['username'] = creds.username;
    }
    if (creds.password != null) {
      outbound['password'] = creds.password;
    }

    if (tlsEnabled) {
      outbound['tls'] = _tlsBlock(
        serverName: _blankToNull(link.query['sni']) ?? link.host,
        alpn: _splitList(link.query['alpn']),
        insecure: _asBool(link.query['insecure']) ?? false,
      );
    }

    return outbound;
  }

  Map<String, dynamic> _buildHysteria2(String raw) {
    final _Link link = _parseLink(raw);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'hysteria2',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 443,
      'password': _blankToNull(link.userInfo) ??
          _blankToNull(link.query['password']) ??
          '',
      'tls': _tlsBlock(
        serverName: _blankToNull(link.query['sni']) ?? link.host,
        alpn: _splitList(link.query['alpn']) ?? const <String>['h3'],
        insecure: _asBool(link.query['insecure']) ?? false,
        enabled: true,
      ),
    };

    final int? up = _asInt(link.query['upmbps'] ?? link.query['up']);
    final int? down = _asInt(link.query['downmbps'] ?? link.query['down']);
    if (up != null) {
      outbound['up_mbps'] = up;
    }
    if (down != null) {
      outbound['down_mbps'] = down;
    }

    final String? obfs = _blankToNull(link.query['obfs']);
    final String? obfsPassword = _blankToNull(
      link.query['obfs-password'] ?? link.query['obfs_password'],
    );
    if (obfs != null && obfsPassword != null) {
      outbound['obfs'] = <String, dynamic>{
        'type': obfs,
        'password': obfsPassword,
      };
    }

    return outbound;
  }

  Map<String, dynamic> _buildHysteria(String raw) {
    final _Link link = _parseLink(raw);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'hysteria',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 443,
      'up_mbps': _asInt(link.query['upmbps'] ?? link.query['up']) ?? 100,
      'down_mbps': _asInt(link.query['downmbps'] ?? link.query['down']) ?? 100,
      'tls': _tlsBlock(
        serverName: _blankToNull(link.query['peer']) ??
            _blankToNull(link.query['sni']) ??
            link.host,
        alpn: _splitList(link.query['alpn']),
        insecure: _asBool(link.query['insecure']) ?? false,
        enabled: true,
      ),
    };

    final String? auth = _blankToNull(link.query['auth']) ??
        _blankToNull(link.query['auth_str']) ??
        _blankToNull(link.userInfo);
    if (auth != null) {
      outbound['auth_str'] = auth;
    }

    final String? obfs = _blankToNull(link.query['obfs']);
    if (obfs != null) {
      outbound['obfs'] = obfs;
    }

    return outbound;
  }

  Map<String, dynamic> _buildTuic(String raw) {
    final _Link link = _parseLink(raw);
    final _Credentials creds = _splitCredentials(link.userInfo);

    return <String, dynamic>{
      'type': 'tuic',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 443,
      'uuid': creds.username ?? '',
      'password': creds.password ?? '',
      'congestion_control':
          _blankToNull(link.query['congestion_control']) ?? 'bbr',
      'udp_relay_mode': _blankToNull(link.query['udp_relay_mode']) ?? 'native',
      'zero_rtt_handshake':
          _asBool(link.query['zero_rtt_handshake']) ?? false,
      'tls': _tlsBlock(
        serverName: _blankToNull(link.query['sni']) ?? link.host,
        alpn: _splitList(link.query['alpn']) ?? const <String>['h3'],
        insecure: _asBool(link.query['insecure'] ??
                link.query['allow_insecure']) ??
            false,
        enabled: true,
      ),
    };
  }

  Map<String, dynamic> _buildWireGuard(String raw) {
    final _Link link = _parseLink(raw);

    final List<String> addresses = _splitList(
          link.query['address'] ??
              link.query['ip'] ??
              link.query['local_address'],
        ) ??
        const <String>['172.16.0.2/32'];

    final Map<String, dynamic> peer = <String, dynamic>{
      'address': _requireHost(link.host),
      'port': link.port ?? 51820,
      'public_key': _blankToNull(
            link.query['publickey'] ??
                link.query['public_key'] ??
                link.query['peer_public_key'],
          ) ??
          '',
      'allowed_ips': <String>['0.0.0.0/0', '::/0'],
    };

    final String? preSharedKey = _blankToNull(
      link.query['presharedkey'] ?? link.query['pre_shared_key'],
    );
    if (preSharedKey != null) {
      peer['pre_shared_key'] = preSharedKey;
    }

    final List<String>? reservedRaw = _splitList(link.query['reserved']);
    if (reservedRaw != null && reservedRaw.length == 3) {
      final List<int> reserved = <int>[];
      for (final String item in reservedRaw) {
        reserved.add(_asInt(item) ?? 0);
      }
      peer['reserved'] = reserved;
    }

    return <String, dynamic>{
      'type': 'wireguard',
      'tag': proxyTag,
      'mtu': _asInt(link.query['mtu']) ?? 1408,
      'address': addresses,
      'private_key': _blankToNull(link.userInfo) ??
          _blankToNull(link.query['privatekey']) ??
          _blankToNull(link.query['private_key']) ??
          '',
      'peers': <Map<String, dynamic>>[peer],
    };
  }

  Map<String, dynamic> _buildAnyTls(String raw) {
    final _Link link = _parseLink(raw);

    return <String, dynamic>{
      'type': 'anytls',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 443,
      'password': _blankToNull(link.userInfo) ??
          _blankToNull(link.query['password']) ??
          '',
      'tls': _tlsBlock(
        serverName: _blankToNull(link.query['sni']) ?? link.host,
        alpn: _splitList(link.query['alpn']),
        insecure: _asBool(link.query['insecure']) ?? false,
        fingerprint: _blankToNull(link.query['fp']),
        enabled: true,
      ),
    };
  }

  /// ShadowTLS is a transport wrapper: the real proxy (Shadowsocks) dials
  /// through a `shadowtls` outbound via `detour`.
  List<Map<String, dynamic>> _buildShadowTlsChain(String raw) {
    final _Link link = _parseLink(raw);
    const String detourTag = 'shadowtls-out';

    final Map<String, dynamic> shadowTls = <String, dynamic>{
      'type': 'shadowtls',
      'tag': detourTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 443,
      'version': _asInt(link.query['version']) ?? 3,
      'password': _blankToNull(link.userInfo) ??
          _blankToNull(link.query['password']) ??
          '',
      'tls': _tlsBlock(
        serverName: _blankToNull(link.query['sni']) ??
            _blankToNull(link.query['host']) ??
            link.host,
        alpn: _splitList(link.query['alpn']),
        insecure: _asBool(link.query['insecure']) ?? false,
        fingerprint: _blankToNull(link.query['fp']),
        enabled: true,
      ),
    };

    final Map<String, dynamic> main = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': proxyTag,
      'method': _blankToNull(link.query['method']) ?? '2022-blake3-aes-128-gcm',
      'password': _blankToNull(
            link.query['ss-password'] ?? link.query['ss_password'],
          ) ??
          '',
      'detour': detourTag,
    };

    return <Map<String, dynamic>>[main, shadowTls];
  }

  /// Tor traffic is relayed to the embedded/local Tor SOCKS listener.
  Map<String, dynamic> _buildTor(String raw) {
    _Link? link;
    try {
      link = _parseLink(raw);
    } on SingBoxConfigException {
      link = null;
    }

    return <String, dynamic>{
      'type': 'socks',
      'tag': proxyTag,
      'server': _blankToNull(link?.host) ?? '127.0.0.1',
      'server_port': link?.port ?? 9050,
      'version': '5',
    };
  }

  Map<String, dynamic> _buildSsh(String raw) {
    final _Link link = _parseLink(raw);
    final _Credentials creds = _splitCredentials(link.userInfo);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'ssh',
      'tag': proxyTag,
      'server': _requireHost(link.host),
      'server_port': link.port ?? 22,
      'user': creds.username ?? _blankToNull(link.query['user']) ?? 'root',
    };

    final String? password = creds.password ?? _blankToNull(link.query['password']);
    if (password != null) {
      outbound['password'] = password;
    }

    final String? privateKey = _blankToNull(link.query['private_key']);
    if (privateKey != null) {
      outbound['private_key'] = privateKey;
    }

    final String? passphrase = _blankToNull(link.query['passphrase']);
    if (passphrase != null) {
      outbound['private_key_passphrase'] = passphrase;
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // TLS / transport helpers
  // ---------------------------------------------------------------------------

  void _attachTls(
    Map<String, dynamic> outbound,
    _Link link, {
    required bool defaultEnabled,
  }) {
    final String security =
        (_blankToNull(link.query['security']) ?? (defaultEnabled ? 'tls' : ''))
            .toLowerCase();

    if (security.isEmpty || security == 'none') {
      return;
    }

    final Map<String, dynamic> tls = _tlsBlock(
      serverName: _blankToNull(link.query['sni']) ??
          _blankToNull(link.query['host']) ??
          link.host,
      alpn: _splitList(link.query['alpn']),
      fingerprint: _blankToNull(link.query['fp']),
      insecure: _asBool(link.query['insecure'] ?? link.query['allowInsecure']) ??
          false,
      enabled: true,
    );

    if (security == 'reality') {
      tls['reality'] = <String, dynamic>{
        'enabled': true,
        'public_key': _blankToNull(link.query['pbk']) ?? '',
        'short_id': _blankToNull(link.query['sid']) ?? '',
      };
      // Reality requires uTLS; Chrome is the safest default.
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': _blankToNull(link.query['fp']) ?? 'chrome',
      };
      tls.remove('alpn');
    }

    outbound['tls'] = tls;
  }

  void _attachTransport(Map<String, dynamic> outbound, _Link link) {
    final Map<String, dynamic>? transport = _transportBlock(
      network: _blankToNull(link.query['type']),
      host: _blankToNull(link.query['host']),
      path: _blankToNull(link.query['path']),
      serviceName: _blankToNull(link.query['serviceName']),
    );

    if (transport != null) {
      outbound['transport'] = transport;
    }
  }

  Map<String, dynamic> _tlsBlock({
    String? serverName,
    List<String>? alpn,
    String? fingerprint,
    bool insecure = false,
    bool enabled = true,
  }) {
    final Map<String, dynamic> tls = <String, dynamic>{
      'enabled': enabled,
      'insecure': insecure,
    };

    final String? name = _blankToNull(serverName);
    if (name != null) {
      tls['server_name'] = name;
    }

    if (alpn != null && alpn.isNotEmpty) {
      tls['alpn'] = alpn;
    }

    if (fingerprint != null) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint,
      };
    }

    return tls;
  }

  Map<String, dynamic>? _transportBlock({
    String? network,
    String? host,
    String? path,
    String? serviceName,
  }) {
    final String type = (network ?? '').toLowerCase();

    switch (type) {
      case '':
      case 'tcp':
      case 'raw':
        return null;
      case 'ws':
      case 'websocket':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'ws',
          'path': path ?? '/',
        };
        if (host != null) {
          transport['headers'] = <String, dynamic>{'Host': host};
        }
        return transport;
      case 'grpc':
        return <String, dynamic>{
          'type': 'grpc',
          'service_name': serviceName ?? path ?? '',
        };
      case 'http':
      case 'h2':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'http',
          'path': path ?? '/',
        };
        if (host != null) {
          transport['host'] = <String>[host];
        }
        return transport;
      case 'httpupgrade':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'httpupgrade',
          'path': path ?? '/',
        };
        if (host != null) {
          transport['host'] = host;
        }
        return transport;
      case 'quic':
        return <String, dynamic>{'type': 'quic'};
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Config skeleton
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _wrap(Map<String, dynamic> outbound) {
    return _wrapAll(<Map<String, dynamic>>[outbound]);
  }

  Map<String, dynamic> _wrapAll(List<Map<String, dynamic>> nodes) {
    if (nodes.isEmpty) {
      throw const SingBoxConfigException('No outbound was generated.');
    }

    final List<Map<String, dynamic>> outbounds = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> endpoints = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> node in nodes) {
      if (_endpointTypes.contains(node['type'])) {
        endpoints.add(node);
      } else {
        outbounds.add(node);
      }
    }

    outbounds.addAll(_helperOutbounds());

    final Map<String, dynamic> config = <String, dynamic>{
      'log': _logBlock(),
      'dns': _dnsBlock(),
      'inbounds': <Map<String, dynamic>>[_tunInbound()],
      'outbounds': outbounds,
      'route': _routeBlock(proxyTag),
      'experimental': _experimentalBlock(),
    };

    if (endpoints.isNotEmpty) {
      config['endpoints'] = endpoints;
    }

    return config;
  }

  Map<String, dynamic> _logBlock() {
    return <String, dynamic>{
      'level': 'info',
      'timestamp': true,
    };
  }

  Map<String, dynamic> _dnsBlock() {
    return <String, dynamic>{
      'servers': <Map<String, dynamic>>[
        <String, dynamic>{
          'tag': 'dns-remote',
          'address': dnsRemoteAddress,
          'address_resolver': 'dns-direct',
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
          'server': 'dns-direct',
        },
      ],
      'final': 'dns-remote',
      'strategy': 'prefer_ipv4',
      'independent_cache': true,
    };
  }

  Map<String, dynamic> _tunInbound() {
    return <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'mtu': tunMtu,
      'address': <String>[tunAddress],
      'interface_name': tunInterfaceName,
      'stack': 'gvisor',
      'domain_strategy': 'ipv4_only',
    };
  }

  List<Map<String, dynamic>> _helperOutbounds() {
    return <Map<String, dynamic>>[
      <String, dynamic>{'type': 'direct', 'tag': 'direct'},
      <String, dynamic>{'type': 'block', 'tag': 'block'},
      <String, dynamic>{'type': 'dns', 'tag': 'dns-out'},
    ];
  }

  Map<String, dynamic> _routeBlock(String finalTag) {
    return <String, dynamic>{
      'rules': <Map<String, dynamic>>[
        <String, dynamic>{'protocol': 'dns', 'outbound': 'dns-out'},
        <String, dynamic>{'ip_is_private': true, 'outbound': 'direct'},
        <String, dynamic>{'protocol': 'quic', 'outbound': 'block'},
      ],
      'final': finalTag,
      'auto_detect_interface': true,
    };
  }

  Map<String, dynamic> _experimentalBlock() {
    return <String, dynamic>{
      'cache_file': <String, dynamic>{
        'enabled': true,
        'store_fakeip': false,
      },
      'clash_api': <String, dynamic>{
        'external_controller': clashApiAddress,
      },
    };
  }

  // ---------------------------------------------------------------------------
  // Raw sing-box config adoption
  // ---------------------------------------------------------------------------

  bool _looksLikeSingBoxConfig(Map<String, dynamic> json) {
    if (json.containsKey('inbounds') || json.containsKey('endpoints')) {
      return true;
    }

    final Object? outbounds = json['outbounds'];
    if (outbounds is! List || outbounds.isEmpty) {
      return false;
    }

    for (final Object? item in outbounds) {
      if (item is Map && item.containsKey('server')) {
        return true;
      }
      if (item is Map && _helperOutboundTypes.contains(item['type'])) {
        return true;
      }
    }

    return json.containsKey('route') || json.containsKey('experimental');
  }

  Map<String, dynamic> _adoptSingBoxConfig(Map<String, dynamic> json) {
    final Map<String, dynamic> config = Map<String, dynamic>.from(json);

    final List<Map<String, dynamic>> outbounds = _asMapList(json['outbounds']);
    final List<Map<String, dynamic>> endpoints = _asMapList(json['endpoints']);

    for (final String type in _helperOutboundTypes) {
      final bool exists = outbounds.any(
        (Map<String, dynamic> item) => item['type'] == type,
      );
      if (!exists) {
        outbounds.add(<String, dynamic>{
          'type': type,
          'tag': type == 'dns' ? 'dns-out' : type,
        });
      }
    }

    String? finalTag;
    for (final Map<String, dynamic> item in <Map<String, dynamic>>[
      ...outbounds,
      ...endpoints,
    ]) {
      final Object? type = item['type'];
      if (type is String && !_helperOutboundTypes.contains(type)) {
        finalTag = _asString(item['tag']);
        if (finalTag != null && finalTag.isNotEmpty) {
          break;
        }
      }
    }

    config['log'] = _logBlock();
    config['inbounds'] = <Map<String, dynamic>>[_tunInbound()];
    config['outbounds'] = outbounds;

    if (endpoints.isNotEmpty) {
      config['endpoints'] = endpoints;
    }

    final Object? dns = json['dns'];
    config['dns'] =
        dns is Map ? Map<String, dynamic>.from(dns) : _dnsBlock();

    final Object? route = json['route'];
    if (route is Map) {
      final Map<String, dynamic> routeMap = Map<String, dynamic>.from(route);
      if (_blankToNull(_asString(routeMap['final'])) == null &&
          finalTag != null) {
        routeMap['final'] = finalTag;
      }
      routeMap['auto_detect_interface'] = true;
      config['route'] = routeMap;
    } else {
      config['route'] = _routeBlock(finalTag ?? 'direct');
    }

    config['experimental'] = _experimentalBlock();

    return config;
  }

  // ---------------------------------------------------------------------------
  // Low level parsing utilities
  // ---------------------------------------------------------------------------

  static final RegExp _linkPattern = RegExp(
    r'^([A-Za-z][A-Za-z0-9+.\-]*):\/\/([^/?#]*)([^?#]*)(?:\?([^#]*))?(?:#(.*))?$',
  );

  _Link _parseLink(String raw) {
    final RegExpMatch? match = _linkPattern.firstMatch(raw.trim());

    if (match == null) {
      throw SingBoxConfigException('Malformed link: $raw');
    }

    final String scheme = (match.group(1) ?? '').toLowerCase();
    final String authority = match.group(2) ?? '';
    final String path = match.group(3) ?? '';
    final String query = match.group(4) ?? '';
    final String fragment = match.group(5) ?? '';

    String userInfo = '';
    String hostPort = authority;
    final int at = authority.lastIndexOf('@');
    if (at >= 0) {
      userInfo = _decodeComponent(authority.substring(0, at));
      hostPort = authority.substring(at + 1);
    }

    String host = hostPort;
    int? port;

    if (hostPort.startsWith('[')) {
      final int close = hostPort.indexOf(']');
      if (close > 0) {
        host = hostPort.substring(1, close);
        final String rest = hostPort.substring(close + 1);
        if (rest.startsWith(':')) {
          port = _asInt(rest.substring(1));
        }
      }
    } else {
      final int colon = hostPort.lastIndexOf(':');
      if (colon > 0) {
        host = hostPort.substring(0, colon);
        port = _asInt(hostPort.substring(colon + 1));
      }
    }

    return _Link(
      scheme: scheme,
      userInfo: userInfo,
      host: host,
      port: port,
      path: path,
      query: _parseQuery(query),
      fragment: _decodeComponent(fragment),
    );
  }

  Map<String, String> _parseQuery(String query) {
    final Map<String, String> result = <String, String>{};

    if (query.isEmpty) {
      return result;
    }

    for (final String pair in query.split('&')) {
      if (pair.isEmpty) {
        continue;
      }
      final int eq = pair.indexOf('=');
      if (eq < 0) {
        result[_decodeComponent(pair)] = '';
      } else {
        result[_decodeComponent(pair.substring(0, eq))] =
            _decodeComponent(pair.substring(eq + 1));
      }
    }

    return result;
  }

  String _decodeComponent(String value) {
    try {
      return Uri.decodeComponent(value.replaceAll('+', '%20'));
    } on Object {
      return value;
    }
  }

  _ShadowsocksParts _parseShadowsocks(String raw) {
    final String body = _stripScheme(raw, 'ss');
    final int hash = body.indexOf('#');
    final String withoutTag = hash >= 0 ? body.substring(0, hash) : body;
    final int questionMark = withoutTag.indexOf('?');
    final String core =
        questionMark >= 0 ? withoutTag.substring(0, questionMark) : withoutTag;
    final Map<String, String> query = questionMark >= 0
        ? _parseQuery(withoutTag.substring(questionMark + 1))
        : <String, String>{};

    // Fully encoded form: ss://base64(method:password@host:port)
    if (!core.contains('@')) {
      final String? decoded = _decodeBase64(core);
      if (decoded == null || !decoded.contains('@')) {
        throw SingBoxConfigException('Malformed shadowsocks link: $raw');
      }
      return _shadowsocksFromPlain(decoded, query);
    }

    final int at = core.lastIndexOf('@');
    final String userPart = core.substring(0, at);
    final String hostPart = core.substring(at + 1);
    final String credentials =
        userPart.contains(':') ? userPart : (_decodeBase64(userPart) ?? '');

    return _shadowsocksFromPlain('$credentials@$hostPart', query);
  }

  _ShadowsocksParts _shadowsocksFromPlain(
    String plain,
    Map<String, String> query,
  ) {
    final int at = plain.lastIndexOf('@');
    final String credentials = plain.substring(0, at);
    final String hostPart = plain.substring(at + 1);

    final int colon = credentials.indexOf(':');
    final String method =
        colon >= 0 ? credentials.substring(0, colon) : 'aes-128-gcm';
    final String password =
        colon >= 0 ? credentials.substring(colon + 1) : credentials;

    String host = hostPart;
    int port = 443;

    if (hostPart.startsWith('[')) {
      final int close = hostPart.indexOf(']');
      if (close > 0) {
        host = hostPart.substring(1, close);
        final String rest = hostPart.substring(close + 1);
        if (rest.startsWith(':')) {
          port = _asInt(rest.substring(1)) ?? 443;
        }
      }
    } else {
      final int hostColon = hostPart.lastIndexOf(':');
      if (hostColon > 0) {
        host = hostPart.substring(0, hostColon);
        port = _asInt(hostPart.substring(hostColon + 1)) ?? 443;
      }
    }

    return _ShadowsocksParts(
      method: method,
      password: _decodeComponent(password),
      host: host,
      port: port,
      query: query,
    );
  }

  _Credentials _splitCredentials(String? userInfo) {
    final String value = userInfo ?? '';
    if (value.isEmpty) {
      return const _Credentials(null, null);
    }

    final int colon = value.indexOf(':');
    if (colon < 0) {
      return _Credentials(value, null);
    }

    return _Credentials(
      _blankToNull(value.substring(0, colon)),
      _blankToNull(value.substring(colon + 1)),
    );
  }

  String _stripScheme(String raw, String scheme) {
    final String trimmed = raw.trim();
    final String prefix = '$scheme://';
    if (trimmed.toLowerCase().startsWith(prefix)) {
      return trimmed.substring(prefix.length);
    }
    return trimmed;
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String? raw) {
    final String value = (raw ?? '').trim();
    if (!value.startsWith('{')) {
      return null;
    }

    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  String? _decodeBase64(String value) {
    String normalized = value.trim().replaceAll('-', '+').replaceAll('_', '/');
    normalized = normalized.replaceAll(RegExp(r'\s'), '');

    if (normalized.isEmpty) {
      return null;
    }

    while (normalized.length % 4 != 0) {
      normalized += '=';
    }

    try {
      return utf8.decode(base64.decode(normalized), allowMalformed: true);
    } on Object {
      return null;
    }
  }

  List<Map<String, dynamic>> _asMapList(Object? value) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];

    if (value is List) {
      for (final Object? item in value) {
        if (item is Map) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return result;
  }

  List<String>? _splitList(String? value) {
    final String? raw = _blankToNull(value);
    if (raw == null) {
      return null;
    }

    final List<String> parts = raw
        .split(RegExp(r'[,\s]+'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();

    return parts.isEmpty ? null : parts;
  }

  String? _asString(Object? value) => value?.toString();

  String? _blankToNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final String? raw = _blankToNull(value?.toString());
    if (raw == null) {
      return null;
    }
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt();
  }

  bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final String? raw = _blankToNull(value?.toString())?.toLowerCase();
    if (raw == null) {
      return null;
    }
    if (raw == '1' || raw == 'true' || raw == 'yes') {
      return true;
    }
    if (raw == '0' || raw == 'false' || raw == 'no') {
      return false;
    }
    return null;
  }

  String _requireHost(String? host) {
    final String? value = _blankToNull(host);
    if (value == null) {
      throw const SingBoxConfigException('Server address is missing.');
    }
    return value;
  }

  String _requireValue(String? value, String field) {
    final String? result = _blankToNull(value);
    if (result == null) {
      throw SingBoxConfigException('Field "$field" is missing in the link.');
    }
    return result;
  }
}

class _Link {
  const _Link({
    required this.scheme,
    required this.userInfo,
    required this.host,
    required this.port,
    required this.path,
    required this.query,
    required this.fragment,
  });

  final String scheme;
  final String userInfo;
  final String host;
  final int? port;
  final String path;
  final Map<String, String> query;
  final String fragment;
}

class _Credentials {
  const _Credentials(this.username, this.password);

  final String? username;
  final String? password;
}

class _ShadowsocksParts {
  const _ShadowsocksParts({
    required this.method,
    required this.password,
    required this.host,
    required this.port,
    required this.query,
  });

  final String method;
  final String password;
  final String host;
  final int port;
  final Map<String, String> query;
}
