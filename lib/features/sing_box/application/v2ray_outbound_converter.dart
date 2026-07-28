import '../domain/sing_box_config_exception.dart';

/// کانفیگ JSON مربوط به v2ray/Xray یا sing-box را به یک outbound استاندارد
/// sing-box تبدیل می‌کند. ورودی می‌تواند کل کانفیگ (با آرایه‌ی outbounds) یا
/// فقط یک outbound تنها باشد.
class V2rayOutboundConverter {
  const V2rayOutboundConverter();

  /// پورت پیش‌فرض SOCKS کلاینت محلی Tor.
  static const int torSocksPort = 9050;

  static const Set<String> _ignoredProtocols = <String>{
    'freedom',
    'blackhole',
    'dns',
    'direct',
    'block',
    'selector',
    'urltest',
  };

  Map<String, dynamic> convert(
    Map<String, dynamic> source, {
    required String tag,
  }) {
    final Map<String, dynamic> outbound = pickOutbound(source);
    final String protocol = (outbound['protocol'] ?? outbound['type'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_]'), '');
    final Map<String, dynamic> settings = _asMap(outbound['settings']);
    final Map<String, dynamic> stream = _asMap(outbound['streamSettings']);

    switch (protocol) {
      // ---- پروتکل‌های سبک v2ray/Xray -------------------------------------
      case 'vmess':
        return _vmess(tag, settings, stream, outbound);
      case 'vless':
        return _vless(tag, settings, stream, outbound);
      case 'trojan':
        return _trojan(tag, settings, stream, outbound);
      case 'shadowsocks':
      case 'ss':
        return _shadowsocks(tag, settings, stream, outbound);
      case 'socks':
      case 'socks5':
        return _socks(tag, settings, outbound, 'socks');
      case 'http':
      case 'https':
        return _socks(tag, settings, outbound, 'http');

      // ---- پروتکل‌های بومی sing-box --------------------------------------
      case 'hysteria2':
      case 'hy2':
        return _hysteria2(tag, outbound);
      case 'hysteria':
      case 'hy':
        return _hysteria(tag, outbound);
      case 'tuic':
        return _tuic(tag, outbound);
      case 'wireguard':
      case 'wg':
      case 'nordlynx':
        return _wireguard(tag, outbound, settings);
      case 'shadowtls':
        return _shadowTls(tag, outbound);
      case 'anytls':
        return _anyTls(tag, outbound);
      case 'naive':
      case 'naiveproxy':
        return _naive(tag, outbound, settings);
      case 'tor':
        return _tor(tag, outbound);
      case 'ssh':
        return _ssh(tag, outbound);

      case 'shadowsocksr':
      case 'ssr':
        throw const SingBoxConfigException(
          'ShadowsocksR is not supported by the sing-box core.',
        );
      default:
        throw SingBoxConfigException(
          'Protocol "$protocol" is not supported yet.',
        );
    }
  }

  /// اولین outbound قابل استفاده را پیدا می‌کند و outboundهای
  /// کمکی مثل freedom/blackhole/dns را رد می‌کند.
  Map<String, dynamic> pickOutbound(Map<String, dynamic> source) {
    final Object? raw = source['outbounds'];

    if (raw is List) {
      for (final Object? item in raw) {
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> candidate = Map<String, dynamic>.from(item);
        final String protocol =
            (candidate['protocol'] ?? candidate['type'] ?? '')
                .toString()
                .toLowerCase();
        if (protocol.isEmpty || _ignoredProtocols.contains(protocol)) {
          continue;
        }
        return candidate;
      }
    }

    // کانفیگ‌های جدید sing-box ممکن است endpoints داشته باشند (WireGuard).
    final Object? endpoints = source['endpoints'];
    if (endpoints is List && endpoints.isNotEmpty && endpoints.first is Map) {
      return Map<String, dynamic>.from(endpoints.first as Map);
    }

    if (source['protocol'] != null ||
        source['settings'] != null ||
        source['type'] != null) {
      return source;
    }

    throw const SingBoxConfigException(
        'No usable outbound found in JSON config.');
  }

  // ---------------------------------------------------------------- protocols

  Map<String, dynamic> _vmess(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
    Map<String, dynamic> node,
  ) {
    final Map<String, dynamic> vnext =
        _firstOfOrEmpty(settings['vnext']) ?? node;
    final Map<String, dynamic> user =
        _firstOfOrEmpty(vnext['users']) ?? _firstOfOrEmpty(node['users']) ?? node;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': _requireString(
        _pick(vnext, <String>['address', 'server', 'host']),
        'VMess address',
      ),
      'server_port': _requirePort(
        _pick(vnext, <String>['port', 'server_port', 'serverPort']),
        'VMess port',
      ),
      'uuid': _requireString(
        _pick(user, <String>['id', 'uuid']),
        'VMess uuid',
      ),
      'security': (_pick(user, <String>['security', 'cipher']) ?? 'auto')
          .toString(),
    };

    final int alterId =
        _toInt(_pick(user, <String>['alterId', 'alter_id', 'aid'])) ?? 0;
    if (alterId > 0) {
      outbound['alter_id'] = alterId;
    }

    if (_isTrue(_pick(node, <String>['global_padding', 'globalPadding']))) {
      outbound['global_padding'] = true;
    }
    if (_isTrue(
        _pick(node, <String>['authenticated_length', 'authenticatedLength']))) {
      outbound['authenticated_length'] = true;
    }

    _applyStream(outbound, stream);
    _applyMultiplexAndPacket(outbound, node);
    return outbound;
  }

  Map<String, dynamic> _vless(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
    Map<String, dynamic> node,
  ) {
    final Map<String, dynamic> vnext =
        _firstOfOrEmpty(settings['vnext']) ?? node;
    final Map<String, dynamic> user =
        _firstOfOrEmpty(vnext['users']) ?? _firstOfOrEmpty(node['users']) ?? node;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': _requireString(
        _pick(vnext, <String>['address', 'server', 'host']),
        'VLESS address',
      ),
      'server_port': _requirePort(
        _pick(vnext, <String>['port', 'server_port', 'serverPort']),
        'VLESS port',
      ),
      'uuid': _requireString(
        _pick(user, <String>['id', 'uuid']),
        'VLESS uuid',
      ),
    };

    final String flow = (_pick(user, <String>['flow']) ?? '').toString().trim();
    if (flow.isNotEmpty && flow != 'none') {
      // sing-box فقط xtls-rprx-vision را می‌پذیرد.
      outbound['flow'] = flow.contains('vision') ? 'xtls-rprx-vision' : flow;
    }

    _applyStream(outbound, stream);
    // اگر کانفیگ به سبک sing-box بود، tls را از سطح بالا بخوان.
    if (!outbound.containsKey('tls')) {
      final Map<String, dynamic>? tls = _nativeTls(node);
      if (tls != null) {
        outbound['tls'] = tls;
      }
    }
    if (!outbound.containsKey('transport') && node['transport'] is Map) {
      outbound['transport'] = _asMap(node['transport']);
    }
    _applyMultiplexAndPacket(outbound, node);
    return outbound;
  }

  Map<String, dynamic> _trojan(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
    Map<String, dynamic> node,
  ) {
    final Map<String, dynamic> server =
        _firstOfOrEmpty(settings['servers']) ?? node;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': _requireString(
        _pick(server, <String>['address', 'server', 'host']),
        'Trojan address',
      ),
      'server_port': _requirePort(
        _pick(server, <String>['port', 'server_port', 'serverPort']),
        'Trojan port',
      ),
      'password': _requireString(
        _pick(server, <String>['password', 'pass']),
        'Trojan password',
      ),
    };

    _applyStream(outbound, stream);

    // Trojan بدون TLS معنا ندارد.
    outbound['tls'] ??=
        _nativeTls(node, forceEnabled: true) ?? <String, dynamic>{
          'enabled': true,
          if ((_pick(node, <String>['sni', 'server_name']) ?? '')
              .toString()
              .isNotEmpty)
            'server_name': _pick(node, <String>['sni', 'server_name']).toString(),
        };
    if (!outbound.containsKey('transport') && node['transport'] is Map) {
      outbound['transport'] = _asMap(node['transport']);
    }
    _applyMultiplexAndPacket(outbound, node);
    return outbound;
  }

  Map<String, dynamic> _shadowsocks(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
    Map<String, dynamic> node,
  ) {
    final Map<String, dynamic> server =
        _firstOfOrEmpty(settings['servers']) ?? node;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': tag,
      'server': _requireString(
        _pick(server, <String>['address', 'server', 'host']),
        'Shadowsocks address',
      ),
      'server_port': _requirePort(
        _pick(server, <String>['port', 'server_port', 'serverPort']),
        'Shadowsocks port',
      ),
      'method': _requireString(
        _pick(server, <String>['method', 'cipher', 'encryption']),
        'Shadowsocks method',
      ),
      'password': _requireString(
        _pick(server, <String>['password', 'pass']),
        'Shadowsocks password',
      ),
    };

    // پلاگین‌های obfs/v2ray-plugin در sing-box مستقیم پشتیبانی می‌شوند.
    final String plugin = (_pick(server, <String>['plugin']) ??
            _pick(node, <String>['plugin']) ??
            '')
        .toString()
        .trim();
    if (plugin.isNotEmpty) {
      outbound['plugin'] = plugin;
      final String opts = (_pick(server, <String>[
                'plugin_opts',
                'pluginOpts',
                'plugin-opts',
              ]) ??
              _pick(node, <String>['plugin_opts', 'pluginOpts']) ??
              '')
          .toString();
      if (opts.isNotEmpty) {
        outbound['plugin_opts'] = opts;
      }
    }

    // زنجیره‌ی ShadowTLS: ss از طریق detour به outbound اول می‌رود.
    final String detour =
        (_pick(node, <String>['detour']) ?? '').toString().trim();
    if (detour.isNotEmpty) {
      outbound['detour'] = detour;
    }

    _applyStream(outbound, stream);
    _applyMultiplexAndPacket(outbound, node);
    return outbound;
  }

  Map<String, dynamic> _socks(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> node,
    String type,
  ) {
    final Map<String, dynamic> server =
        _firstOfOrEmpty(settings['servers']) ?? node;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': type,
      'tag': tag,
      'server': _requireString(
        _pick(server, <String>['address', 'server', 'host']),
        '$type address',
      ),
      'server_port': _requirePort(
        _pick(server, <String>['port', 'server_port', 'serverPort']),
        '$type port',
      ),
    };

    if (type == 'socks') {
      final String version =
          (_pick(server, <String>['version']) ?? '5').toString();
      outbound['version'] = version == '4' || version == '4a' ? version : '5';
    }

    final Map<String, dynamic>? user = _firstOfOrEmpty(server['users']);
    final String username = (_pick(user ?? server, <String>[
              'user',
              'username',
            ]) ??
            '')
        .toString();
    if (username.isNotEmpty) {
      outbound['username'] = username;
      outbound['password'] = (_pick(user ?? server, <String>[
                'pass',
                'password',
              ]) ??
              '')
          .toString();
    }

    // HTTP over TLS (مثل کانفیگ‌های naive-style).
    if (type == 'http') {
      final Map<String, dynamic>? tls = _nativeTls(node);
      if (tls != null) {
        outbound['tls'] = tls;
      }
    }

    return outbound;
  }

  Map<String, dynamic> _hysteria2(String tag, Map<String, dynamic> node) {
    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'hysteria2',
      'tag': tag,
      'server': _requireString(
        _pick(node, <String>['server', 'address', 'host']),
        'Hysteria2 server',
      ),
      'server_port': _requirePort(
        _pick(node, <String>['server_port', 'serverPort', 'port']),
        'Hysteria2 port',
      ),
    };

    final String password = (_pick(node, <String>[
              'password',
              'auth',
              'auth_str',
              'authStr',
            ]) ??
            '')
        .toString();
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }

    final int up = _toInt(_pick(node, <String>['up_mbps', 'upMbps', 'up'])) ?? 0;
    final int down =
        _toInt(_pick(node, <String>['down_mbps', 'downMbps', 'down'])) ?? 0;
    if (up > 0) {
      outbound['up_mbps'] = up;
    }
    if (down > 0) {
      outbound['down_mbps'] = down;
    }

    final Map<String, dynamic>? obfs = _hysteriaObfs(node, salamander: true);
    if (obfs != null) {
      outbound['obfs'] = obfs;
    }

    // چند پورتی (port hopping) در sing-box 1.12+
    final String hopPorts = (_pick(node, <String>[
              'server_ports',
              'serverPorts',
              'hop_ports',
              'mport',
            ]) ??
            '')
        .toString();
    if (hopPorts.isNotEmpty) {
      outbound['server_ports'] = _stringList(hopPorts);
    }

    final int hopInterval = _toInt(
            _pick(node, <String>['hop_interval', 'hopInterval'])) ??
        0;
    if (hopInterval > 0) {
      outbound['hop_interval'] = '${hopInterval}s';
    }

    if (_isTrue(_pick(node, <String>['brutal_debug', 'brutalDebug']))) {
      outbound['brutal_debug'] = true;
    }

    outbound['tls'] = _nativeTls(
      node,
      forceEnabled: true,
      defaultAlpn: <String>['h3'],
    )!;

    return outbound;
  }

  Map<String, dynamic> _hysteria(String tag, Map<String, dynamic> node) {
    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'hysteria',
      'tag': tag,
      'server': _requireString(
        _pick(node, <String>['server', 'address', 'host']),
        'Hysteria server',
      ),
      'server_port': _requirePort(
        _pick(node, <String>['server_port', 'serverPort', 'port']),
        'Hysteria port',
      ),
      // hysteria v1 در sing-box بدون پهنای باند کار نمی‌کند؛ مقادیر
      // پیش‌فرض محافظه‌کارانه می‌گذاریم.
      'up_mbps': _toInt(_pick(node, <String>['up_mbps', 'upMbps', 'up'])) ?? 100,
      'down_mbps':
          _toInt(_pick(node, <String>['down_mbps', 'downMbps', 'down'])) ?? 100,
    };

    final String authStr = (_pick(node, <String>[
              'auth_str',
              'authStr',
              'auth',
              'password',
            ]) ??
            '')
        .toString();
    if (authStr.isNotEmpty) {
      outbound['auth_str'] = authStr;
    }

    final Map<String, dynamic>? obfs = _hysteriaObfs(node, salamander: false);
    if (obfs != null) {
      outbound['obfs'] = obfs['password'];
    }

    final int recvWindowConn = _toInt(_pick(node, <String>[
          'recv_window_conn',
          'recvWindowConn',
        ])) ??
        0;
    if (recvWindowConn > 0) {
      outbound['recv_window_conn'] = recvWindowConn;
    }

    final int recvWindow =
        _toInt(_pick(node, <String>['recv_window', 'recvWindow'])) ?? 0;
    if (recvWindow > 0) {
      outbound['recv_window'] = recvWindow;
    }

    if (_isTrue(_pick(node, <String>['disable_mtu_discovery']))) {
      outbound['disable_mtu_discovery'] = true;
    }

    outbound['tls'] = _nativeTls(
      node,
      forceEnabled: true,
      defaultAlpn: <String>['hysteria'],
    )!;

    return outbound;
  }

  Map<String, dynamic> _tuic(String tag, Map<String, dynamic> node) {
    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'tuic',
      'tag': tag,
      'server': _requireString(
        _pick(node, <String>['server', 'address', 'host']),
        'TUIC server',
      ),
      'server_port': _requirePort(
        _pick(node, <String>['server_port', 'serverPort', 'port']),
        'TUIC port',
      ),
      'uuid': _requireString(
        _pick(node, <String>['uuid', 'uid', 'id']),
        'TUIC uuid',
      ),
    };

    final String password =
        (_pick(node, <String>['password', 'token', 'pass']) ?? '').toString();
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }

    outbound['congestion_control'] = (_pick(node, <String>[
              'congestion_control',
              'congestionControl',
              'congestion',
            ]) ??
            'bbr')
        .toString();
    outbound['udp_relay_mode'] = (_pick(node, <String>[
              'udp_relay_mode',
              'udpRelayMode',
            ]) ??
            'native')
        .toString();

    if (_isTrue(_pick(node, <String>['zero_rtt_handshake', 'reduce_rtt']))) {
      outbound['zero_rtt_handshake'] = true;
    }
    if (_isTrue(_pick(node, <String>['udp_over_stream', 'udpOverStream']))) {
      outbound['udp_over_stream'] = true;
    }

    final String heartbeat =
        (_pick(node, <String>['heartbeat', 'heartbeat_interval']) ?? '')
            .toString();
    if (heartbeat.isNotEmpty) {
      outbound['heartbeat'] =
          RegExp(r'^\d+$').hasMatch(heartbeat) ? '${heartbeat}s' : heartbeat;
    }

    outbound['tls'] = _nativeTls(
      node,
      forceEnabled: true,
      defaultAlpn: <String>['h3'],
    )!;

    return outbound;
  }

  /// WireGuard (و NordLynx که همان WireGuard با تنظیمات بهینه است).
  ///
  /// از فرمت outbound نسخه‌ی 1.11 استفاده می‌کنیم که در libbox فعلی
  /// پشتیبانی می‌شود. اگر هسته به 1.13 ارتقا یافت باید به `endpoints`
  /// منتقل شود.
  Map<String, dynamic> _wireguard(
    String tag,
    Map<String, dynamic> node,
    Map<String, dynamic> settings,
  ) {
    final Map<String, dynamic> source = settings.isNotEmpty ? settings : node;
    final Map<String, dynamic>? peer = _firstOfOrEmpty(source['peers']);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'wireguard',
      'tag': tag,
      'server': _requireString(
        _pick(peer ?? source, <String>['server', 'address', 'endpoint', 'host']),
        'WireGuard endpoint',
      ),
      'server_port': _requirePort(
        _pick(peer ?? source,
            <String>['server_port', 'serverPort', 'port', 'endpoint_port']),
        'WireGuard port',
      ),
      'private_key': _requireString(
        _pick(source, <String>['private_key', 'privateKey', 'secretKey']),
        'WireGuard private key',
      ),
    };

    final List<String> localAddress = _stringList(
      _pick(source, <String>[
        'local_address',
        'localAddress',
        'address',
        'addresses',
      ]),
    );
    outbound['local_address'] = localAddress.isEmpty
        ? <String>['172.16.0.2/32', 'fd00::2/128']
        : localAddress;

    final String peerPublicKey = (_pick(peer ?? source, <String>[
              'peer_public_key',
              'peerPublicKey',
              'public_key',
              'publicKey',
            ]) ??
            '')
        .toString();
    if (peerPublicKey.isNotEmpty) {
      outbound['peer_public_key'] = peerPublicKey;
    }

    final String preSharedKey = (_pick(peer ?? source, <String>[
              'pre_shared_key',
              'preSharedKey',
              'psk',
            ]) ??
            '')
        .toString();
    if (preSharedKey.isNotEmpty) {
      outbound['pre_shared_key'] = preSharedKey;
    }

    final int mtu = _toInt(_pick(source, <String>['mtu'])) ?? 0;
    outbound['mtu'] = mtu > 0 ? mtu : 1408;

    final List<int> reserved =
        _intList(_pick(peer ?? source, <String>['reserved']));
    if (reserved.length == 3) {
      outbound['reserved'] = reserved;
    }

    final int workers = _toInt(_pick(source, <String>['workers'])) ?? 0;
    if (workers > 0) {
      outbound['workers'] = workers;
    }

    return outbound;
  }

  Map<String, dynamic> _shadowTls(String tag, Map<String, dynamic> node) {
    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'shadowtls',
      'tag': tag,
      'server': _requireString(
        _pick(node, <String>['server', 'address', 'host']),
        'ShadowTLS server',
      ),
      'server_port': _requirePort(
        _pick(node, <String>['server_port', 'serverPort', 'port']),
        'ShadowTLS port',
      ),
    };

    final int version = _toInt(_pick(node, <String>['version'])) ?? 3;
    outbound['version'] = version >= 1 && version <= 3 ? version : 3;

    final String password =
        (_pick(node, <String>['password', 'pass']) ?? '').toString();
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }

    outbound['tls'] = _nativeTls(node, forceEnabled: true)!;
    return outbound;
  }

  Map<String, dynamic> _anyTls(String tag, Map<String, dynamic> node) {
    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'anytls',
      'tag': tag,
      'server': _requireString(
        _pick(node, <String>['server', 'address', 'host']),
        'AnyTLS server',
      ),
      'server_port': _requirePort(
        _pick(node, <String>['server_port', 'serverPort', 'port']),
        'AnyTLS port',
      ),
      'password': _requireString(
        _pick(node, <String>['password', 'pass']),
        'AnyTLS password',
      ),
    };

    final int minIdle =
        _toInt(_pick(node, <String>['min_idle_session', 'minIdleSession'])) ?? 0;
    if (minIdle > 0) {
      outbound['min_idle_session'] = minIdle;
    }

    final String idleTimeout = (_pick(node, <String>[
              'idle_session_timeout',
              'idleSessionTimeout',
            ]) ??
            '')
        .toString();
    if (idleTimeout.isNotEmpty) {
      outbound['idle_session_timeout'] = _duration(idleTimeout);
    }

    final String checkInterval = (_pick(node, <String>[
              'idle_session_check_interval',
              'idleSessionCheckInterval',
            ]) ??
            '')
        .toString();
    if (checkInterval.isNotEmpty) {
      outbound['idle_session_check_interval'] = _duration(checkInterval);
    }

    outbound['tls'] = _nativeTls(node, forceEnabled: true)!;
    return outbound;
  }

  /// NaïveProxy: هسته‌ی sing-box outbound اختصاصی naive ندارد؛ پروتکل آن
  /// عملاً HTTP/2 CONNECT روی TLS است، پس روی outbound نوع `http`
  /// با TLS و ALPN مناسب نگاشت می‌شود.
  Map<String, dynamic> _naive(
    String tag,
    Map<String, dynamic> node,
    Map<String, dynamic> settings,
  ) {
    final Map<String, dynamic> source = settings.isNotEmpty ? settings : node;
    final Map<String, dynamic>? server = _firstOfOrEmpty(source['servers']);
    final Map<String, dynamic> host = server ?? source;

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'http',
      'tag': tag,
      'server': _requireString(
        _pick(host, <String>['server', 'address', 'host']),
        'Naive server',
      ),
      'server_port': _requirePort(
        _pick(host, <String>['server_port', 'serverPort', 'port']),
        'Naive port',
      ),
    };

    final String username =
        (_pick(host, <String>['username', 'user']) ?? '').toString();
    if (username.isNotEmpty) {
      outbound['username'] = username;
      outbound['password'] =
          (_pick(host, <String>['password', 'pass']) ?? '').toString();
    }

    outbound['tls'] = _nativeTls(
      node,
      forceEnabled: true,
      defaultAlpn: <String>['h2', 'http/1.1'],
    )!;

    return outbound;
  }

  /// Tor: از طریق SOCKS به کلاینت محلی Tor (tor-android/Arti) وصل می‌شویم.
  Map<String, dynamic> _tor(String tag, Map<String, dynamic> node) {
    final String server =
        (_pick(node, <String>['server', 'address', 'host']) ?? '127.0.0.1')
            .toString();
    final int port = _toInt(_pick(node, <String>[
          'server_port',
          'serverPort',
          'port',
          'socks_port',
        ])) ??
        torSocksPort;

    return <String, dynamic>{
      'type': 'socks',
      'tag': tag,
      'server': server,
      'server_port': port,
      'version': '5',
      // Tor فقط TCP و DNS را عبور می‌دهد؛ UDP در روتینگ باید مسدود شود.
      'udp_over_tcp': false,
    };
  }

  Map<String, dynamic> _ssh(String tag, Map<String, dynamic> node) {
    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'ssh',
      'tag': tag,
      'server': _requireString(
        _pick(node, <String>['server', 'address', 'host']),
        'SSH server',
      ),
      'server_port':
          _toInt(_pick(node, <String>['server_port', 'serverPort', 'port'])) ??
              22,
      'user': (_pick(node, <String>['user', 'username']) ?? 'root').toString(),
    };

    final String password =
        (_pick(node, <String>['password', 'pass']) ?? '').toString();
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }

    final Object? privateKey =
        _pick(node, <String>['private_key', 'privateKey']);
    if (privateKey != null) {
      final List<String> lines = _stringList(privateKey);
      outbound['private_key'] = lines.length == 1 ? lines.first : lines;
    }

    final String keyPath = (_pick(node, <String>[
              'private_key_path',
              'privateKeyPath',
            ]) ??
            '')
        .toString();
    if (keyPath.isNotEmpty) {
      outbound['private_key_path'] = keyPath;
    }

    final String passphrase = (_pick(node, <String>[
              'private_key_passphrase',
              'passphrase',
            ]) ??
            '')
        .toString();
    if (passphrase.isNotEmpty) {
      outbound['private_key_passphrase'] = passphrase;
    }

    final List<String> hostKey = _stringList(_pick(node, <String>['host_key']));
    if (hostKey.isNotEmpty) {
      outbound['host_key'] = hostKey;
    }

    final String clientVersion = (_pick(node, <String>[
              'client_version',
              'clientVersion',
            ]) ??
            '')
        .toString();
    if (clientVersion.isNotEmpty) {
      outbound['client_version'] = clientVersion;
    }

    return outbound;
  }

  // ------------------------------------------------------------------ stream

  void _applyStream(
      Map<String, dynamic> outbound, Map<String, dynamic> stream) {
    if (stream.isEmpty) {
      return;
    }

    final Map<String, dynamic>? tls = _tls(stream);
    if (tls != null) {
      outbound['tls'] = tls;
    }

    final Map<String, dynamic>? transport = _transport(stream);
    if (transport != null) {
      outbound['transport'] = transport;
    }
  }

  /// multiplex و packet encoding را از کانفیگ‌های سبک sing-box می‌خواند.
  void _applyMultiplexAndPacket(
    Map<String, dynamic> outbound,
    Map<String, dynamic> node,
  ) {
    final Object? mux = node['multiplex'];
    if (mux is Map) {
      final Map<String, dynamic> value = _asMap(mux);
      if (_isTrue(value['enabled'])) {
        outbound['multiplex'] = value;
      }
    }

    final String packet =
        (_pick(node, <String>['packet_encoding', 'packetEncoding']) ?? '')
            .toString();
    if (packet.isNotEmpty) {
      outbound['packet_encoding'] = packet;
    }
  }

  Map<String, dynamic>? _tls(Map<String, dynamic> stream) {
    final String security =
        (stream['security'] ?? 'none').toString().toLowerCase();

    if (security != 'tls' && security != 'xtls' && security != 'reality') {
      return null;
    }

    final Map<String, dynamic> reality = _asMap(stream['realitySettings']);
    final Map<String, dynamic> tlsSettings = _asMap(
      stream['tlsSettings'] ?? stream['xtlsSettings'],
    );
    final Map<String, dynamic> source =
        security == 'reality' && reality.isNotEmpty ? reality : tlsSettings;

    final Map<String, dynamic> tls = <String, dynamic>{'enabled': true};

    final String serverName =
        (source['serverName'] ?? tlsSettings['serverName'] ?? '')
            .toString()
            .trim();
    if (serverName.isNotEmpty) {
      tls['server_name'] = serverName;
    }

    if (source['allowInsecure'] == true ||
        tlsSettings['allowInsecure'] == true) {
      tls['insecure'] = true;
    }

    final Object? alpn = source['alpn'] ?? tlsSettings['alpn'];
    final List<String> alpnList = _stringList(alpn);
    if (alpnList.isNotEmpty) {
      tls['alpn'] = alpnList;
    }

    final String fingerprint =
        (source['fingerprint'] ?? tlsSettings['fingerprint'] ?? '')
            .toString()
            .trim();

    if (security == 'reality') {
      // Reality در sing-box بدون uTLS کار نمی‌کند.
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint.isEmpty ? 'chrome' : fingerprint,
      };
      tls['reality'] = <String, dynamic>{
        'enabled': true,
        'public_key': _requireString(
          reality['publicKey'] ?? reality['public_key'],
          'Reality publicKey',
        ),
        'short_id':
            (reality['shortId'] ?? reality['short_id'] ?? '').toString(),
      };
    } else if (fingerprint.isNotEmpty) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint,
      };
    }

    return tls;
  }

  /// TLS برای کانفیگ‌های بومی sing-box (یا لینک‌هایی که مستقیم sni/alpn دارند).
  Map<String, dynamic>? _nativeTls(
    Map<String, dynamic> node, {
    bool forceEnabled = false,
    List<String>? defaultAlpn,
  }) {
    final Map<String, dynamic> raw = _asMap(node['tls']);
    final bool enabled = forceEnabled ||
        _isTrue(raw['enabled']) ||
        _isTrue(_pick(node, <String>['tls_enabled']));

    final String serverName = (raw['server_name'] ??
            raw['serverName'] ??
            _pick(node, <String>['sni', 'server_name', 'serverName', 'peer']) ??
            '')
        .toString()
        .trim();

    final bool insecure = _isTrue(raw['insecure']) ||
        _isTrue(_pick(node, <String>[
          'insecure',
          'allowInsecure',
          'allow_insecure',
          'skip_cert_verify',
        ]));

    final List<String> alpn = _stringList(
      raw['alpn'] ?? _pick(node, <String>['alpn']),
    );

    final String fingerprint = (raw['utls'] is Map
            ? (_asMap(raw['utls'])['fingerprint'] ?? '')
            : (_pick(node, <String>['fp', 'fingerprint']) ?? ''))
        .toString()
        .trim();

    final Map<String, dynamic> reality = raw['reality'] is Map
        ? _asMap(raw['reality'])
        : <String, dynamic>{};
    final String publicKey = (reality['public_key'] ??
            reality['publicKey'] ??
            _pick(node, <String>['pbk', 'public_key']) ??
            '')
        .toString()
        .trim();

    if (!enabled &&
        serverName.isEmpty &&
        alpn.isEmpty &&
        publicKey.isEmpty &&
        !insecure) {
      return null;
    }

    final Map<String, dynamic> tls = <String, dynamic>{'enabled': true};
    if (serverName.isNotEmpty) {
      tls['server_name'] = serverName;
    }
    if (insecure) {
      tls['insecure'] = true;
    }
    if (alpn.isNotEmpty) {
      tls['alpn'] = alpn;
    } else if (defaultAlpn != null && defaultAlpn.isNotEmpty) {
      tls['alpn'] = defaultAlpn;
    }

    final List<String> certificate =
        _stringList(raw['certificate'] ?? node['certificate']);
    if (certificate.isNotEmpty) {
      tls['certificate'] = certificate;
    }

    if (publicKey.isNotEmpty) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint.isEmpty ? 'chrome' : fingerprint,
      };
      tls['reality'] = <String, dynamic>{
        'enabled': true,
        'public_key': publicKey,
        'short_id': (reality['short_id'] ??
                reality['shortId'] ??
                _pick(node, <String>['sid', 'short_id']) ??
                '')
            .toString(),
      };
    } else if (fingerprint.isNotEmpty) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint,
      };
    }

    return tls;
  }

  Map<String, dynamic>? _hysteriaObfs(
    Map<String, dynamic> node, {
    required bool salamander,
  }) {
    final Object? raw = node['obfs'];

    if (raw is Map) {
      final Map<String, dynamic> value = _asMap(raw);
      final String password = (value['password'] ??
              value['obfs-password'] ??
              value['obfs_password'] ??
              '')
          .toString()
          .trim();
      if (password.isEmpty) {
        return null;
      }
      return <String, dynamic>{
        'type': (value['type'] ?? 'salamander').toString(),
        'password': password,
      };
    }

    final String password = (raw ??
            _pick(node, <String>['obfs_password', 'obfsPassword']) ??
            '')
        .toString()
        .trim();
    if (password.isEmpty) {
      return null;
    }

    return <String, dynamic>{
      if (salamander) 'type': 'salamander',
      'password': password,
    };
  }

  Map<String, dynamic>? _transport(Map<String, dynamic> stream) {
    final String network =
        (stream['network'] ?? 'tcp').toString().toLowerCase();

    switch (network) {
      case 'ws':
      case 'websocket':
        return _wsTransport(_asMap(stream['wsSettings']), 'ws');
      case 'httpupgrade':
        return _wsTransport(
          _asMap(stream['httpupgradeSettings'] ?? stream['wsSettings']),
          'httpupgrade',
        );
      case 'grpc':
        final Map<String, dynamic> grpc = _asMap(stream['grpcSettings']);
        return <String, dynamic>{
          'type': 'grpc',
          'service_name':
              (grpc['serviceName'] ?? grpc['service_name'] ?? '').toString(),
        };
      case 'h2':
      case 'http':
        final Map<String, dynamic> http = _asMap(stream['httpSettings']);
        final Object? host = http['host'];
        return <String, dynamic>{
          'type': 'http',
          if (_stringList(host).isNotEmpty) 'host': _stringList(host),
          if ((http['path'] ?? '').toString().isNotEmpty)
            'path': http['path'].toString(),
        };
      case 'quic':
        // sing-box برای QUIC خالص transport جدا ندارد.
        return null;
      case 'tcp':
      case 'raw':
      case '':
        return _tcpHeaderTransport(
          _asMap(stream['tcpSettings'] ?? stream['rawSettings']),
        );
      default:
        return null;
    }
  }

  Map<String, dynamic> _wsTransport(Map<String, dynamic> ws, String type) {
    final Map<String, dynamic> headers = _asMap(ws['headers']);
    final String host =
        (headers['Host'] ?? headers['host'] ?? ws['host'] ?? '').toString();
    final String path = (ws['path'] ?? '').toString();

    if (type == 'httpupgrade') {
      return <String, dynamic>{
        'type': 'httpupgrade',
        if (host.isNotEmpty) 'host': host,
        if (path.isNotEmpty) 'path': path,
      };
    }

    final Map<String, dynamic> transport = <String, dynamic>{
      'type': 'ws',
      if (path.isNotEmpty) 'path': path,
      if (host.isNotEmpty)
        'headers': <String, dynamic>{
          'Host': host,
        },
    };

    final int earlyData = _toInt(ws['maxEarlyData']) ?? 0;
    if (earlyData > 0) {
      transport['max_early_data'] = earlyData;
      transport['early_data_header_name'] =
          (ws['earlyDataHeaderName'] ?? 'Sec-WebSocket-Protocol').toString();
    }

    return transport;
  }

  /// حالت `tcp` با هدر جعلی http در v2ray معادل transport نوع http است.
  Map<String, dynamic>? _tcpHeaderTransport(Map<String, dynamic> tcp) {
    final Map<String, dynamic> header = _asMap(tcp['header']);
    if ((header['type'] ?? '').toString().toLowerCase() != 'http') {
      return null;
    }

    final Map<String, dynamic> request = _asMap(header['request']);
    final Map<String, dynamic> headers = _asMap(request['headers']);
    final Object? host = headers['Host'] ?? headers['host'];
    final Object? path = request['path'];

    return <String, dynamic>{
      'type': 'http',
      if (_stringList(host).isNotEmpty) 'host': _stringList(host),
      if (path is List && path.isNotEmpty) 'path': path.first.toString(),
      if (path is String && path.isNotEmpty) 'path': path,
    };
  }

  // ------------------------------------------------------------------ helpers

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _firstOfOrEmpty(Object? value) {
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Object? _pick(Map<String, dynamic> node, List<String> keys) {
    for (final String key in keys) {
      final Object? value = node[key];
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      return value;
    }
    return null;
  }

  List<String> _stringList(Object? value) {
    if (value == null) {
      return <String>[];
    }
    if (value is List) {
      return value
          .map((Object? item) => (item ?? '').toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    final String raw = value.toString().trim();
    if (raw.isEmpty) {
      return <String>[];
    }
    return raw
        .split(RegExp(r'[,\n]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  List<int> _intList(Object? value) {
    return _stringList(value)
        .map((String item) => int.tryParse(item))
        .whereType<int>()
        .toList();
  }

  String _duration(String value) {
    final String raw = value.trim();
    return RegExp(r'^\d+$').hasMatch(raw) ? '${raw}s' : raw;
  }

  bool _isTrue(Object? value) {
    if (value is bool) {
      return value;
    }
    final String raw = (value ?? '').toString().toLowerCase().trim();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  String _requireString(Object? value, String field) {
    final String result = (value ?? '').toString().trim();
    if (result.isEmpty) {
      throw SingBoxConfigException('$field is missing in JSON config.');
    }
    return result;
  }

  int _requirePort(Object? value, String field) {
    final int port = _toInt(value) ?? 0;
    if (port <= 0 || port > 65535) {
      throw SingBoxConfigException('$field is invalid in JSON config.');
    }
    return port;
  }

  int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '').toString().trim());
  }
}
