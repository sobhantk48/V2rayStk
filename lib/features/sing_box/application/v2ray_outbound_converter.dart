import '../domain/sing_box_config_exception.dart';

/// کانفیگ JSON مربوط به v2ray/Xray را به یک outbound استاندارد sing-box
/// تبدیل می‌کند. ورودی می‌تواند کل کانفیگ (با آرایه‌ی outbounds) یا
/// فقط یک outbound تنها باشد.
class V2rayOutboundConverter {
  const V2rayOutboundConverter();

  static const Set<String> _ignoredProtocols = <String>{
    'freedom',
    'blackhole',
    'dns',
    'direct',
    'block',
  };

  Map<String, dynamic> convert(
    Map<String, dynamic> source, {
    required String tag,
  }) {
    final Map<String, dynamic> outbound = pickOutbound(source);
    final String protocol =
        (outbound['protocol'] ?? outbound['type'] ?? '').toString().toLowerCase();
    final Map<String, dynamic> settings = _asMap(outbound['settings']);
    final Map<String, dynamic> stream = _asMap(outbound['streamSettings']);

    switch (protocol) {
      case 'vmess':
        return _vmess(tag, settings, stream);
      case 'vless':
        return _vless(tag, settings, stream);
      case 'trojan':
        return _trojan(tag, settings, stream);
      case 'shadowsocks':
        return _shadowsocks(tag, settings, stream);
      case 'socks':
        return _socks(tag, settings, 'socks');
      case 'http':
      case 'https':
        return _socks(tag, settings, 'http');
      default:
        throw SingBoxConfigException(
          'v2ray protocol "$protocol" is not supported yet.',
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

    if (source['protocol'] != null || source['settings'] != null) {
      return source;
    }

    throw SingBoxConfigException('No usable outbound found in JSON config.');
  }

  // ---------------------------------------------------------------- protocols

  Map<String, dynamic> _vmess(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final Map<String, dynamic> node = _firstOf(settings['vnext'], 'vnext');
    final Map<String, dynamic> user = _firstOf(node['users'], 'users');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': _requireString(node['address'], 'VMess address'),
      'server_port': _requirePort(node['port'], 'VMess port'),
      'uuid': _requireString(user['id'], 'VMess uuid'),
      'security': (user['security'] ?? 'auto').toString(),
    };

    final int alterId = _toInt(user['alterId']) ?? 0;
    if (alterId > 0) {
      outbound['alter_id'] = alterId;
    }

    _applyStream(outbound, stream);
    return outbound;
  }

  Map<String, dynamic> _vless(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final Map<String, dynamic> node = _firstOf(settings['vnext'], 'vnext');
    final Map<String, dynamic> user = _firstOf(node['users'], 'users');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': _requireString(node['address'], 'VLESS address'),
      'server_port': _requirePort(node['port'], 'VLESS port'),
      'uuid': _requireString(user['id'], 'VLESS uuid'),
    };

    final String flow = (user['flow'] ?? '').toString().trim();
    if (flow.isNotEmpty && flow != 'none') {
      outbound['flow'] = flow;
    }

    _applyStream(outbound, stream);
    return outbound;
  }

  Map<String, dynamic> _trojan(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final Map<String, dynamic> node = _firstOf(settings['servers'], 'servers');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': _requireString(node['address'], 'Trojan address'),
      'server_port': _requirePort(node['port'], 'Trojan port'),
      'password': _requireString(node['password'], 'Trojan password'),
    };

    _applyStream(outbound, stream);

    // Trojan بدون TLS معنا ندارد؛ اگر streamSettings خالی بود TLS را
    // به صورت پیش‌فرض روشن می‌کنیم.
    outbound['tls'] ??= <String, dynamic>{'enabled': true};
    return outbound;
  }

  Map<String, dynamic> _shadowsocks(
    String tag,
    Map<String, dynamic> settings,
    Map<String, dynamic> stream,
  ) {
    final Map<String, dynamic> node = _firstOf(settings['servers'], 'servers');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': tag,
      'server': _requireString(node['address'], 'Shadowsocks address'),
      'server_port': _requirePort(node['port'], 'Shadowsocks port'),
      'method': _requireString(node['method'], 'Shadowsocks method'),
      'password': _requireString(node['password'], 'Shadowsocks password'),
    };

    _applyStream(outbound, stream);
    return outbound;
  }

  Map<String, dynamic> _socks(
    String tag,
    Map<String, dynamic> settings,
    String type,
  ) {
    final Map<String, dynamic> node = _firstOf(settings['servers'], 'servers');
    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': type,
      'tag': tag,
      'server': _requireString(node['address'], '$type address'),
      'server_port': _requirePort(node['port'], '$type port'),
    };

    final Object? users = node['users'];
    if (users is List && users.isNotEmpty && users.first is Map) {
      final Map<String, dynamic> user =
          Map<String, dynamic>.from(users.first as Map);
      final String username = (user['user'] ?? user['username'] ?? '').toString();
      if (username.isNotEmpty) {
        outbound['username'] = username;
        outbound['password'] = (user['pass'] ?? user['password'] ?? '').toString();
      }
    }

    return outbound;
  }

  // ------------------------------------------------------------------ stream

  void _applyStream(Map<String, dynamic> outbound, Map<String, dynamic> stream) {
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

    if (source['allowInsecure'] == true || tlsSettings['allowInsecure'] == true) {
      tls['insecure'] = true;
    }

    final Object? alpn = source['alpn'] ?? tlsSettings['alpn'];
    if (alpn is List && alpn.isNotEmpty) {
      tls['alpn'] = alpn.map((Object? item) => item.toString()).toList();
    } else if (alpn is String && alpn.trim().isNotEmpty) {
      tls['alpn'] = alpn.split(',').map((String item) => item.trim()).toList();
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
          if (host is List && host.isNotEmpty)
            'host': host.map((Object? item) => item.toString()).toList(),
          if (host is String && host.trim().isNotEmpty) 'host': <String>[host],
          if ((http['path'] ?? '').toString().isNotEmpty)
            'path': http['path'].toString(),
        };
      case 'quic':
        // sing-box برای QUIC خالص transport جدا ندارد.
        return null;
      case 'tcp':
      case '':
        return _tcpHeaderTransport(_asMap(stream['tcpSettings']));
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
      if (host is List && host.isNotEmpty)
        'host': host.map((Object? item) => item.toString()).toList(),
      if (host is String && host.isNotEmpty) 'host': <String>[host],
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

  Map<String, dynamic> _firstOf(Object? value, String field) {
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    throw SingBoxConfigException('JSON config field "$field" is empty.');
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
    return int.tryParse((value ?? '').toString());
  }
}
