import 'dart:convert';

import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../domain/sing_box_config.dart';
import '../domain/sing_box_config_exception.dart';
import 'v2ray_outbound_converter.dart';

/// جفت host/port برای تجزیه‌ی آدرس خام (با پشتیبانی IPv6 داخل [] )
class _HostPort {
  const _HostPort(this.host, this.port);
  final String host;
  final int port;
}

class SingBoxConfigGenerator {
  final V2rayOutboundConverter _v2rayConverter = const V2rayOutboundConverter();

  const SingBoxConfigGenerator();

  /// outbound هایی که پروکسی واقعی نیستند و نباید به عنوان proxy انتخاب شوند
  static const Set<String> _nonProxyTypes = <String>{
    'direct',
    'block',
    'dns',
    'selector',
    'urltest',
    'freedom',
    'blackhole',
  };

  /// نام‌های قدیمی رمزنگاری shadowsocks که sing-box شکل دیگری می‌خواهد
  static const Map<String, String> _ssMethodAliases = <String, String>{
    'chacha20-poly1305': 'chacha20-ietf-poly1305',
    'xchacha20-poly1305': 'xchacha20-ietf-poly1305',
  };

  SingBoxConfig generate(Profile profile) {
    final bool isTor = _isTorProfile(profile);
    try {
      final Map<String, dynamic>? json =
          _tryDecodeJsonObject(profile.rawConfig);

      if (json != null) {
        if (_looksLikeSingBoxConfig(json)) {
          return SingBoxConfig(_wrap(_adoptSingBoxConfig(json), isTor: isTor));
        }
        return SingBoxConfig(
          _wrap(_v2rayConverter.convert(json, tag: 'proxy'), isTor: isTor),
        );
      }

      // اگر لینک URI بود (مثل vless://)
      return SingBoxConfig(_wrap(_buildOutboundFromUri(profile), isTor: isTor));
    } catch (e) {
      throw SingBoxConfigException('خطا در تولید کانفیگ: $e');
    }
  }

  /// نسخهٔ زنجیره‌ای generate: پروفایل اصلی به‌عنوان exit و بقیه به‌عنوان هاپ.
  SingBoxConfig generateChain(Profile profile, List<Profile> hops) {
    final bool isTor = _isTorProfile(profile);
    try {
      final Map<String, dynamic> head = _outboundOf(profile, 'proxy');
      final List<Map<String, dynamic>> hopOutbounds = <Map<String, dynamic>>[];

      if (!isTor) {
        for (int i = 0; i < hops.length; i++) {
          final Profile hop = hops[i];
          if (hop.id == profile.id) {
            continue;
          }
          if (_isTorProfile(hop)) {
            continue;
          }
          hopOutbounds.add(_outboundOf(hop, 'hop-$i'));
        }
      }

      return SingBoxConfig(
        _wrap(head, isTor: isTor, hops: hopOutbounds),
      );
    } catch (e) {
      throw SingBoxConfigException('خطا در تولید کانفیگ زنجیره‌ای: $e');
    }
  }

  /// یک پروفایل را فقط به outbound تبدیل می‌کند (بدون wrap کردن).
  Map<String, dynamic> _outboundOf(Profile profile, String tag) {
    final Map<String, dynamic>? json = _tryDecodeJsonObject(profile.rawConfig);
    if (json != null) {
      if (_looksLikeSingBoxConfig(json)) {
        final Map<String, dynamic> out = _adoptSingBoxConfig(json);
        out['tag'] = tag;
        return out;
      }
      return _v2rayConverter.convert(json, tag: tag);
    }
    final Map<String, dynamic> out = _buildOutboundFromUri(profile);
    out['tag'] = tag;
    return out;
  }

  Map<String, dynamic> _buildOutboundFromUri(Profile profile) {
    const String tag = 'proxy';
    final String raw = profile.rawConfig.trim();

    // این دو ممکن است base64 باشند و با Uri.parse قابل تجزیه نیستند.
    if (profile.type == ProfileType.vmess) {
      return _buildVmessOutbound(profile, tag);
    }
    if (profile.type == ProfileType.shadowsocks) {
      return _buildShadowsocksOutbound(raw, tag);
    }

    final Uri uri = Uri.parse(raw);
    final Map<String, String> params = uri.queryParameters;

    switch (profile.type) {
      case ProfileType.tor:
        // Tor داخلی یک SOCKS محلی روی 9050 است -> مثل SOCKS ساخته می‌شود.
        return _buildSocksOutbound(uri, params, tag);
      case ProfileType.socks:
        return _buildSocksOutbound(uri, params, tag);
      case ProfileType.vless:
      case ProfileType.reality:
        return _buildVlessOutbound(uri, params, tag);
      case ProfileType.trojan:
        return _buildTrojanOutbound(uri, params, tag);
      case ProfileType.http:
        return _buildHttpOutbound(uri, params, tag);
      default:
        throw SingBoxConfigException(
            'پروتکل ${profile.type} هنوز به صورت کامل پشتیبانی نمی‌شود.');
    }
  }

  Map<String, dynamic> _buildVlessOutbound(
      Uri uri, Map<String, String> params, String tag) {
    final String uuid = _safeDecode(uri.userInfo);
    if (uuid.isEmpty) {
      throw const SingBoxConfigException('UUID در لینک vless خالی است.');
    }

    final String security = (params['security'] ?? '').toLowerCase();
    final String pbk = (params['pbk'] ?? params['publicKey'] ?? '').trim();
    final String sid = (params['sid'] ?? params['shortId'] ?? '').trim();
    final String flow = (params['flow'] ?? '').trim();

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': uri.host,
      'server_port': _requirePort(uri.hasPort ? uri.port : 0, 'vless'),
      'uuid': uuid,
    };

    // flow فقط وقتی اضافه شود که واقعا مقدار دارد (خالی باعث خطا می‌شود)
    if (flow.isNotEmpty) {
      outbound['flow'] = flow;
    }

    if (security == 'reality' || pbk.isNotEmpty) {
      if (pbk.isEmpty) {
        throw const SingBoxConfigException(
            'Public Key (pbk) برای Reality الزامی است');
      }
      outbound['tls'] = _buildTls(
        params,
        uri.host,
        reality: true,
        publicKey: pbk,
        shortId: sid,
      );
    } else if (security == 'tls' || security == 'xtls') {
      outbound['tls'] = _buildTls(params, uri.host);
    }

    _addTransport(outbound, params);
    return outbound;
  }

  /// ساخت بلوک TLS مشترک برای vless/trojan/http
  Map<String, dynamic> _buildTls(
    Map<String, String> params,
    String fallbackServerName, {
    bool reality = false,
    String publicKey = '',
    String shortId = '',
  }) {
    String serverName = (params['sni'] ?? params['host'] ?? '').trim();
    if (serverName.isEmpty) {
      // server_name خالی TLS را می‌شکند؛ به آدرس سرور برمی‌گردیم.
      serverName = fallbackServerName.trim();
    }

    String fingerprint = (params['fp'] ?? '').trim();
    if (fingerprint.isEmpty) {
      fingerprint = 'chrome';
    }

    final Map<String, dynamic> tls = <String, dynamic>{
      'enabled': true,
      'server_name': serverName,
      'utls': <String, dynamic>{'enabled': true, 'fingerprint': fingerprint},
    };

    final List<String> alpn = _parseAlpn(params['alpn']);
    if (alpn.isNotEmpty) {
      tls['alpn'] = alpn;
    }

    if (_isTruthy(params['allowInsecure']) ||
        _isTruthy(params['insecure']) ||
        _isTruthy(params['skip-cert-verify'])) {
      tls['insecure'] = true;
    }

    if (reality) {
      tls['reality'] = <String, dynamic>{
        'enabled': true,
        'public_key': publicKey,
        'short_id': shortId,
      };
    }
    return tls;
  }

  List<String> _parseAlpn(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String>[];
    }
    return _safeDecode(raw)
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  bool _isTruthy(String? value) {
    final String v = (value ?? '').trim().toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }

  /// پورت باید معتبر باشد؛ ۰ یعنی لینک پورت نداشته است.
  int _requirePort(int port, String protocol) {
    if (port <= 0 || port > 65535) {
      throw SingBoxConfigException(
          'پورت در لینک $protocol نامعتبر یا مشخص نشده است.');
    }
    return port;
  }

  void _addTransport(
      Map<String, dynamic> outbound, Map<String, String> params) {
    final String type = (params['type'] ?? '').toLowerCase();
    if (type.isEmpty || type == 'tcp' || type == 'raw' || type == 'none') {
      return; // ترنسپورت خام؛ چیزی اضافه نمی‌شود
    }

    final String decoded = _decodeOnce(params['path'] ?? '/');
    String cleanPath = decoded;
    int maxEarlyData = int.tryParse(params['ed'] ?? '') ?? 0;
    final int qm = decoded.indexOf('?');
    if (qm >= 0) {
      cleanPath = decoded.substring(0, qm);
      final q = Uri.splitQueryString(decoded.substring(qm + 1));
      maxEarlyData = int.tryParse(q['ed'] ?? '') ?? maxEarlyData;
    }
    if (cleanPath.isEmpty) cleanPath = '/';
    if (!cleanPath.startsWith('/')) cleanPath = '/$cleanPath';

    final String host = _transportHost(outbound, params);

    switch (type) {
      case 'ws':
      case 'websocket':
        final Map<String, dynamic> ws = {'type': 'ws', 'path': cleanPath};
        if (host.isNotEmpty) ws['headers'] = {'Host': host};
        if (maxEarlyData > 0) {
          ws['max_early_data'] = maxEarlyData;
          ws['early_data_header_name'] = 'Sec-WebSocket-Protocol';
        }
        outbound['transport'] = ws;
        break;

      case 'httpupgrade':
        final Map<String, dynamic> hu = {
          'type': 'httpupgrade',
          'path': cleanPath,
        };
        if (host.isNotEmpty) hu['host'] = host;
        outbound['transport'] = hu;
        break;

      case 'grpc':
        outbound['transport'] = {
          'type': 'grpc',
          'service_name': params['serviceName'] ?? params['servicename'] ?? '',
        };
        break;

      case 'http':
      case 'h2':
        final Map<String, dynamic> h = {'type': 'http', 'path': cleanPath};
        if (host.isNotEmpty) h['host'] = [host];
        final String method = params['method'] ?? '';
        if (method.isNotEmpty) h['method'] = method;
        outbound['transport'] = h;
        break;

      case 'quic':
        outbound['transport'] = {'type': 'quic'};
        break;

      default:
        throw SingBoxConfigException('ترنسپورت پشتیبانی‌نشده: $type');
    }
  }

  /// یک مرحله percent-decode با محافظت از ورودی نامعتبر
  String _decodeOnce(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  /// انتخاب Host برای ترنسپورت: host → sni → server_name → آدرس سرور
  String _transportHost(
      Map<String, dynamic> outbound, Map<String, String> params) {
    final String host = (params['host'] ?? '').trim();
    if (host.isNotEmpty) return host;
    final String sni = (params['sni'] ?? '').trim();
    if (sni.isNotEmpty) return sni;
    final tls = outbound['tls'];
    if (tls is Map && tls['server_name'] is String) {
      final String sn = (tls['server_name'] as String).trim();
      if (sn.isNotEmpty) return sn;
    }
    final server = outbound['server'];
    return server is String ? server : '';
  }

  Map<String, dynamic> _buildTrojanOutbound(
      Uri uri, Map<String, String> params, String tag) {
    final String password = _safeDecode(uri.userInfo);
    if (password.isEmpty) {
      throw const SingBoxConfigException('رمز عبور در لینک trojan خالی است.');
    }

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': uri.host,
      'server_port': _requirePort(uri.hasPort ? uri.port : 0, 'trojan'),
      'password': password,
      // Trojan همیشه روی TLS سوار است.
      'tls': _buildTls(params, uri.host),
    };

    // باگ قبلی: ترنسپورت trojan (ws/grpc/...) اعمال نمی‌شد.
    _addTransport(outbound, params);
    return outbound;
  }

  /// shadowsocks با پشتیبانی هر دو فرم استاندارد:
  ///   SIP002 : ss://base64(method:password)@host:port?plugin=...#tag
  ///   قدیمی  : ss://base64(method:password@host:port)#tag
  Map<String, dynamic> _buildShadowsocksOutbound(String rawConfig, String tag) {
    String body = rawConfig
        .trim()
        .replaceFirst(RegExp(r'^ss://', caseSensitive: false), '')
        .trim();

    final int hash = body.indexOf('#');
    if (hash >= 0) {
      body = body.substring(0, hash);
    }

    Map<String, String> params = const <String, String>{};
    final int qm = body.indexOf('?');
    if (qm >= 0) {
      params = Uri.splitQueryString(body.substring(qm + 1));
      body = body.substring(0, qm);
    }
    while (body.endsWith('/')) {
      body = body.substring(0, body.length - 1);
    }
    if (body.isEmpty) {
      throw const SingBoxConfigException('محتوای لینک shadowsocks خالی است.');
    }

    String method;
    String password;
    _HostPort address;

    final int at = body.lastIndexOf('@');
    if (at > 0) {
      final String creds = _decodeCredentials(body.substring(0, at));
      final List<String> pair = _splitCredentials(creds);
      method = pair[0];
      password = pair[1];
      address = _splitHostPort(body.substring(at + 1));
    } else {
      final String? decoded = _tryBase64(body);
      if (decoded == null) {
        throw const SingBoxConfigException(
            'لینک shadowsocks قابل decode نیست.');
      }
      final int at2 = decoded.lastIndexOf('@');
      if (at2 <= 0) {
        throw const SingBoxConfigException(
            'ساختار لینک shadowsocks نامعتبر است.');
      }
      final List<String> pair = _splitCredentials(decoded.substring(0, at2));
      method = pair[0];
      password = pair[1];
      address = _splitHostPort(decoded.substring(at2 + 1));
    }

    if (address.host.isEmpty) {
      throw const SingBoxConfigException('آدرس سرور shadowsocks خالی است.');
    }
    if (method.isEmpty) {
      throw const SingBoxConfigException(
          'روش رمزنگاری (method) در لینک shadowsocks پیدا نشد.');
    }

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': tag,
      'server': address.host,
      'server_port': _requirePort(address.port, 'shadowsocks'),
      'method': _ssMethodAliases[method] ?? method,
      'password': password,
    };

    final String plugin = (params['plugin'] ?? '').trim();
    if (plugin.isNotEmpty) {
      final String decodedPlugin = _safeDecode(plugin);
      final int semi = decodedPlugin.indexOf(';');
      if (semi >= 0) {
        outbound['plugin'] = decodedPlugin.substring(0, semi);
        outbound['plugin_opts'] = decodedPlugin.substring(semi + 1);
      } else {
        outbound['plugin'] = decodedPlugin;
      }
    }

    return outbound;
  }

  /// بخش اعتبارنامه ممکن است base64 یا percent-encoded باشد.
  String _decodeCredentials(String value) {
    final String raw = value.trim();
    if (raw.contains(':')) {
      return _safeDecode(raw);
    }
    return _tryBase64(raw) ?? _safeDecode(raw);
  }

  List<String> _splitCredentials(String creds) {
    final int c = creds.indexOf(':');
    if (c <= 0) {
      throw const SingBoxConfigException(
          'بخش method:password در لینک shadowsocks نامعتبر است.');
    }
    return <String>[
      creds.substring(0, c).trim().toLowerCase(),
      creds.substring(c + 1),
    ];
  }

  /// جدا کردن host و port با پشتیبانی از IPv6 به شکل [::1]:8388
  _HostPort _splitHostPort(String value) {
    final String v = value.trim();
    if (v.startsWith('[')) {
      final int close = v.indexOf(']');
      if (close > 0) {
        final String host = v.substring(1, close);
        final String rest = v.substring(close + 1);
        final int port = rest.startsWith(':')
            ? (int.tryParse(rest.substring(1).trim()) ?? 0)
            : 0;
        return _HostPort(host, port);
      }
    }
    final int idx = v.lastIndexOf(':');
    if (idx > 0) {
      return _HostPort(
        v.substring(0, idx).trim(),
        int.tryParse(v.substring(idx + 1).trim()) ?? 0,
      );
    }
    return _HostPort(v, 0);
  }

  String? _tryBase64(String value) {
    try {
      final String normalized =
          value.trim().replaceAll('-', '+').replaceAll('_', '/');
      final int missing = (4 - normalized.length % 4) % 4;
      return utf8.decode(base64.decode(normalized + ('=' * missing)));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _wrap(
    Map<String, dynamic> outbound, {
    bool isTor = false,
    List<Map<String, dynamic>> hops = const <Map<String, dynamic>>[],
  }) {
    final Object? srv = outbound['server'];
    final String proxyServer = srv is String ? srv.trim() : '';

    // زنجیرهٔ Multi-Hop؛ اگر هاپی نباشد فقط خودِ proxy برمی‌گردد.
    final List<Map<String, dynamic>> chain =
        _buildHopChain(outbound, hops, isTor: isTor);
    final List<String> hopServers =
        isTor ? const <String>[] : _collectHopServers(hops);

    // sing-box قاعدهٔ domain را روی IP خام تطبیق نمی‌دهد. پس برای
    // سرورهایی که IP هستند باید ip_cidr بدهیم تا از تونل بیرون بمانند.
    final List<String> directCidrs = <String>[
      for (final String s in <String>[proxyServer, ...hopServers])
        if (s.isNotEmpty && _isIpLiteral(s))
          _bareHost(s).contains(':')
              ? '${_bareHost(s)}/128'
              : '${_bareHost(s)}/32',
    ];

    return {
      'log': {'level': 'info', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:9090',
          'access_control_allow_origin': '*',
        },
        'cache_file': {'enabled': true},
      },
      'dns': _buildDns(isTor, proxyServer, hopServers: hopServers),
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'inet4_address': '172.19.0.1/28',
          'mtu': 1412,
          'auto_route': true,
          'strict_route': isTor,
          'stack': 'gvisor',
          'endpoint_independent_nat': true,
          'sniff': true,
          'sniff_timeout': '300ms',
          // دامنه‌ی sniff‌شده جای IP مقصد را می‌گیرد تا خودِ سرور پروکسی
          // (یا تور) نام را resolve کند. مقاوم‌ترین حالت در برابر DNS آلوده
          // و لازم برای باز شدن گوگل/یوتیوب.
          'sniff_override_destination': true,
        }
      ],
      'outbounds': <Map<String, dynamic>>[
        ...chain,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
        {'type': 'dns', 'tag': 'dns-out'}
      ],
      'route': {
        'rules': <Map<String, dynamic>>[
          // ۱) هر چیزی که DNS است -> hijack به dns-out
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {
            'port': <int>[53],
            'outbound': 'dns-out'
          },
          // DoT/853 مسدود می‌شود تا اپ‌ها مجبور به استفاده از DNS داخلی شوند
          {
            'port': <int>[853],
            'outbound': 'block'
          },
          // ۲) لوکال‌هاست و شبکه‌های خصوصی هرگز نباید وارد تونل شوند
          {
            'ip_cidr': <String>[
              '127.0.0.0/8',
              '10.0.0.0/8',
              '172.16.0.0/12',
              '192.168.0.0/16',
              '169.254.0.0/16',
              '::1/128',
              'fc00::/7',
              'fe80::/10',
            ],
            'outbound': 'direct',
          },
          {
            'domain': <String>['localhost'],
            'outbound': 'direct',
          },
          // ۳) خودِ سرور پروکسی نباید از داخل تونل عبور کند
          if (proxyServer.isNotEmpty)
            {
              'domain': <String>[proxyServer],
              'outbound': 'direct',
            },
          // سرور هر هاپ باید مستقیم حل و وصل شود، وگرنه sing-box
          // می‌خواهد آدرس هاپ را از داخل همان تونل پیدا کند => حلقه.
          if (hopServers.isNotEmpty)
            {
              'domain': hopServers,
              'outbound': 'direct',
            },
          if (directCidrs.isNotEmpty)
            {
              'ip_cidr': directCidrs,
              'outbound': 'direct',
            },
          // ۴) در حالت Tor هیچ UDP نداریم (SOCKS5 تور UDP ندارد).
          //    پورت ۵۳ و loopback بالاتر هندل شده‌اند، پس DNS سالم می‌ماند.
          if (isTor)
            {
              'network': 'udp',
              'outbound': 'block',
            },
          // ۵) در حالت عادی QUIC مسدود می‌شود. سرورهای ws/CDN اغلب فقط
          //    TCP عبور می‌دهند و بسته‌های UDP/443 بی‌پاسخ گم می‌شوند؛
          //    نتیجه‌اش گیر کردن یوتیوب/گوگل است. با block، مرورگر فوراً
          //    به HTTP/2 روی TCP برمی‌گردد.
          if (!isTor)
            {
              'network': 'udp',
              'port': <int>[443, 8443],
              'outbound': 'block',
            },
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
      }
    };
  }

  /// زنجیرهٔ Multi-Hop را می‌سازد.
  ///
  /// خروجی: [proxy, hop-0, hop-1, ...]
  /// proxy.detour = hop-0 و hop-0.detour = hop-1 و آخرین هاپ بدون detour.
  /// یعنی مسیر واقعی بسته‌ها: device -> آخرین هاپ -> ... -> hop-0 -> proxy.
  /// پس پروفایل فعال همیشه نود خروجی (exit) باقی می‌ماند.
  List<Map<String, dynamic>> _buildHopChain(
    Map<String, dynamic> outbound,
    List<Map<String, dynamic>> hops, {
    bool isTor = false,
  }) {
    final Map<String, dynamic> head = Map<String, dynamic>.from(outbound);

    // در حالت Tor زنجیره‌سازی معنا ندارد: SOCKS محلی خودش مسیر پیازی دارد.
    if (isTor || hops.isEmpty) {
      return <Map<String, dynamic>>[head];
    }

    head['tag'] = 'proxy';
    final List<Map<String, dynamic>> chain = <Map<String, dynamic>>[head];

    for (int i = 0; i < hops.length; i++) {
      final Map<String, dynamic> hop = Map<String, dynamic>.from(hops[i]);
      hop['tag'] = 'hop-$i';
      hop.remove('detour');
      chain.add(hop);
    }

    for (int i = 0; i < chain.length - 1; i++) {
      chain[i]['detour'] = chain[i + 1]['tag'];
    }
    return chain;
  }

  /// آدرس سرور هاپ‌ها برای ساخت قاعدهٔ direct و جلوگیری از حلقهٔ resolve.
  // [hopdns-v3] robust hop server collection
  List<String> _collectHopServers(List<Map<String, dynamic>> hops) {
    final List<String> out = <String>[];
    for (final Map<String, dynamic> hop in hops) {
      _extractHopHostsInto(hop, out);
    }
    return out;
  }

  /// آدرس سرور را از کلیدهای رایج و ساختارهای تودرتو (مثل peers در
  /// WireGuard) بیرون می‌کشد تا هیچ هاپی از قواعد direct جا نماند.
  void _extractHopHostsInto(Map<String, dynamic> node, List<String> out) {
    void add(Object? v) {
      if (v is String) {
        final String value = v.trim();
        if (value.isNotEmpty && !out.contains(value)) {
          out.add(value);
        }
      }
    }

    for (final String key in const <String>[
      'server',
      'server_address',
      'address',
    ]) {
      final Object? v = node[key];
      if (v is List) {
        for (final Object? item in v) {
          add(item);
        }
      } else {
        add(v);
      }
    }

    final Object? peers = node['peers'];
    if (peers is List) {
      for (final Object? p in peers) {
        if (p is Map) {
          _extractHopHostsInto(Map<String, dynamic>.from(p), out);
        }
      }
    }

    for (final MapEntry<String, dynamic> e in node.entries) {
      if (e.key == 'peers') continue;
      final Object? v = e.value;
      if (v is Map) {
        _extractHopHostsInto(Map<String, dynamic>.from(v), out);
      }
    }
  }


  /// تشخیص پروفایل تور: SOCKS روی لوکال‌هاست
  bool _isTorProfile(Profile profile) {
    // پروفایل صریحاً از نوع tor باشد -> همیشه حالت Tor
    if (profile.type == ProfileType.tor) return true;
    if (profile.type != ProfileType.socks) return false;
    try {
      final uri = Uri.parse(profile.rawConfig.trim());
      final String h = uri.host.toLowerCase();
      return h == '127.0.0.1' || h == 'localhost' || h == '::1';
    } catch (_) {
      return false;
    }
  }

  /// DNS بدون حلقه:
  ///  - bootstrap-dns : مستقیم (direct) برای حل دامنه‌ی سرور پروکسی
  ///  - proxy-dns     : تور -> DNSPort محلی 5353 ، غیرتور -> DNS روی TCP از داخل تونل
  Map<String, dynamic> _buildDns(
    bool isTor,
    String proxyServer, {
    List<String> hopServers = const <String>[],
  }) {
    final List<Map<String, dynamic>> servers = <Map<String, dynamic>>[
      // همیشه یک resolver مستقیم داریم تا آدرس سرور بدون تونل حل شود
      {
        'tag': 'bootstrap-dns',
        // TCP بهجای UDP خام: در شبکههایی که UDP مسدود است،
        // resolver مستقیم همیشه جواب میدهد و دیگر deadline نمیخورد.
        'address': 'local',
        'strategy': 'ipv4_only',
        'detour': 'direct',
      },
      if (isTor)
        {
          'tag': 'proxy-dns',
          'address': 'udp://127.0.0.1:5353',
          'strategy': 'ipv4_only',
          'detour': 'direct',
        }
      else
        {
          'tag': 'proxy-dns',
          // DoH روی پورت 443 از داخل تونل. سرویس‌های ابری مثل Railway
          // پورت 53 خروجی را می‌بندند، ولی 443 همیشه باز است.
          // IP مستقیم استفاده می‌شود تا نیازی به resolve اولیه نباشد.
          'address': 'https://8.8.8.8/dns-query',
          // با اینکه آدرس یک IP خالص است و resolve لازم ندارد،
          // این فیلد به‌عنوان بیمهٔ ضدحلقه باقی می‌ماند.
          'address_resolver': 'bootstrap-dns',
          'strategy': 'ipv4_only',
          'detour': 'proxy',
        },
      {'tag': 'block-dns', 'address': 'rcode://success'},
      // پاسخ‌دهندهٔ FakeIP: بدون هیچ رفت‌وبرگشت شبکه، آنی IP مصنوعی
      // می‌دهد. فقط در حالت تور لازم است.
      if (isTor) {'tag': 'fakeip-dns', 'address': 'fakeip'},
    ];

    final List<Map<String, dynamic>> rules = <Map<String, dynamic>>[
      // رکوردهای HTTPS/SVCB (type 64 و 65) را خالی برگردان تا
      // مرورگر سراغ HTTP/3 روی QUIC نرود و به HTTP/2 روی TCP برگردد.
      {
        'query_type': <int>[64, 65],
        'server': 'block-dns',
      },
      // دامنه‌ی سرور پروکسی حتماً باید با bootstrap حل شود (جلوگیری از حلقه)
      if (proxyServer.isNotEmpty && !_isIpLiteral(proxyServer))
        {
          'domain': <String>[proxyServer],
          'server': 'bootstrap-dns',
        },
      // دامنهٔ سرور هر هاپ هم باید با bootstrap حل شود. وگرنه resolve آن
      // از proxy-dns رد می‌شود که detour=proxy دارد و proxy خودش منتظر
      // همین هاپ است -> بن‌بست و تایم‌اوت در Multi-Hop.
      for (final String hopServer in hopServers)
        if (hopServer.isNotEmpty && !_isIpLiteral(hopServer))
          {
            'domain': <String>[hopServer],
            'server': 'bootstrap-dns',
          },
      {
        'domain_suffix': <String>['.local', '.lan', '.home'],
        'server': isTor ? 'block-dns' : 'bootstrap-dns',
      },
      // تور IPv6 تحویل نمی‌دهد؛ AAAA (type 28) را خالی برگردان تا
      // اپ‌ها منتظر پاسخی نمانند که هرگز نمی‌آید.
      if (isTor)
        {
          'query_type': <int>[28],
          'server': 'block-dns',
        },
      // کل کوئری‌های A از FakeIP جواب می‌گیرند: تأخیر DNS صفر می‌شود و
      // دامنهٔ اصلی (نه IP) به SOCKS تور تحویل داده می‌شود.
      if (isTor)
        {
          'query_type': <int>[1],
          'server': 'fakeip-dns',
        },
    ];

    final Map<String, dynamic> dns = <String, dynamic>{
      'servers': servers,
      'rules': rules,
      'final': 'proxy-dns',
      'strategy': 'ipv4_only',
      'independent_cache': false,
      'disable_cache': false,
      'reverse_mapping': true,
    };
    if (isTor) {
      // محدودهٔ 198.18.0.0/15 توسط auto_route وارد tun می‌شود و
      // sing-box هنگام اتصال، fakeip را به دامنهٔ واقعی برمی‌گرداند.
      dns['fakeip'] = <String, dynamic>{
        'enabled': true,
        'inet4_range': '198.18.0.0/15',
      };
    }
    return dns;
  }

  /// آیا رشته یک IP خام است؟ (برای IP نیازی به DNS rule نیست)
  /// آیا رشته یک IP خام است؟ (براکت IPv6 اول حذف می‌شود)
  bool _isIpLiteral(String host) {
    final h = _bareHost(host);
    if (h.isEmpty) return false;
    if (h.contains(':')) return true; // IPv6
    final parts = h.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  /// '[2001:db8::1]' -> '2001:db8::1' ؛ برای ساخت CIDR معتبر لازم است.
  String _bareHost(String host) {
    var h = host.trim();
    if (h.length > 2 && h.startsWith('[') && h.endsWith(']')) {
      h = h.substring(1, h.length - 1);
    }
    return h;
  }

  Map<String, dynamic> _buildSocksOutbound(
      Uri uri, Map<String, String> params, String tag) {
    final String host = uri.host.isNotEmpty ? uri.host : '127.0.0.1';
    final int port = uri.hasPort ? uri.port : 9050;

    final Map<String, dynamic> out = <String, dynamic>{
      'type': 'socks',
      'tag': tag,
      'server': host,
      'server_port': port,
      'version': '5',
    };

    final String info = uri.userInfo;
    if (info.isNotEmpty && info.contains(':')) {
      final int k = info.indexOf(':');
      out['username'] = _safeDecode(info.substring(0, k));
      out['password'] = _safeDecode(info.substring(k + 1));
    }
    return out;
  }

  /// vmess://BASE64(JSON) را به outbound سازگار با sing-box تبدیل می‌کند.
  Map<String, dynamic> _buildVmessOutbound(Profile profile, String tag) {
    final String payload = profile.rawConfig
        .trim()
        .replaceFirst(RegExp(r'^vmess://', caseSensitive: false), '')
        .trim();
    if (payload.isEmpty) {
      throw const SingBoxConfigException('محتوای لینک vmess خالی است.');
    }

    final Map<String, dynamic> node = _decodeVmessPayload(payload);

    final String server = (node['add'] ?? node['address'] ?? '').toString();
    final int port = _asInt(node['port']);
    final String uuid = (node['id'] ?? node['uuid'] ?? '').toString();
    if (server.isEmpty || port <= 0 || uuid.isEmpty) {
      throw const SingBoxConfigException(
          'لینک vmess ناقص است (add/port/id الزامی هستند).');
    }

    String security = (node['scy'] ?? node['security'] ?? 'auto').toString();
    if (security.isEmpty || security == 'none') {
      security = 'auto';
    }

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'security': security,
      'alter_id': _asInt(node['aid'] ?? node['alterId'] ?? 0),
    };

    final String net = (node['net'] ?? 'tcp').toString().toLowerCase();
    final String host = (node['host'] ?? '').toString();
    final String rawPath = (node['path'] ?? '').toString();
    final String path = rawPath.isEmpty ? '/' : rawPath;
    final String sniValue = (node['sni'] ?? '').toString();
    final String sni = sniValue.isNotEmpty ? sniValue : host;
    final String tls = (node['tls'] ?? '').toString().toLowerCase();

    if (net == 'ws') {
      outbound['transport'] = <String, dynamic>{
        'type': 'ws',
        'path': path,
        if (host.isNotEmpty) 'headers': <String, dynamic>{'Host': host},
      };
    } else if (net == 'httpupgrade') {
      outbound['transport'] = <String, dynamic>{
        'type': 'httpupgrade',
        'path': path,
        if (host.isNotEmpty) 'host': host,
      };
    } else if (net == 'grpc') {
      outbound['transport'] = <String, dynamic>{
        'type': 'grpc',
        'service_name': rawPath,
      };
    } else if (net == 'h2' || net == 'http') {
      outbound['transport'] = <String, dynamic>{
        'type': 'http',
        if (host.isNotEmpty) 'host': <String>[host],
        'path': path,
      };
    }

    if (tls == 'tls' || tls == 'reality') {
      String fingerprint = (node['fp'] ?? '').toString().trim();
      if (fingerprint.isEmpty) {
        fingerprint = 'chrome';
      }
      final Map<String, dynamic> tlsBlock = <String, dynamic>{
        'enabled': true,
        'server_name': sni.isNotEmpty ? sni : server,
        'utls': <String, dynamic>{
          'enabled': true,
          'fingerprint': fingerprint,
        },
      };
      final List<String> alpn = _parseAlpn(node['alpn']?.toString());
      if (alpn.isNotEmpty) {
        tlsBlock['alpn'] = alpn;
      }
      if (_isTruthy(node['allowInsecure']?.toString()) ||
          _isTruthy(node['skip-cert-verify']?.toString())) {
        tlsBlock['insecure'] = true;
      }
      outbound['tls'] = tlsBlock;
    }

    return outbound;
  }

  Map<String, dynamic> _decodeVmessPayload(String payload) {
    final String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
    final int missing = (4 - normalized.length % 4) % 4;
    final String padded = normalized + ('=' * missing);
    final String decoded = utf8.decode(base64.decode(padded));
    final Object? parsed = json.decode(decoded);
    if (parsed is! Map) {
      throw const SingBoxConfigException('ساختار JSON لینک vmess نامعتبر است.');
    }
    return Map<String, dynamic>.from(parsed);
  }

  /// http:// یا https:// با احراز هویت اختیاری.
  Map<String, dynamic> _buildHttpOutbound(
      Uri uri, Map<String, String> params, String tag) {
    final List<String> credentials = uri.userInfo.split(':');
    final String username =
        credentials.isNotEmpty ? _safeDecode(credentials.first) : '';
    final String password =
        credentials.length > 1 ? _safeDecode(credentials[1]) : '';
    final bool useTls = uri.scheme.toLowerCase() == 'https' ||
        (params['security'] ?? '').toLowerCase() == 'tls';

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'http',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.hasPort ? uri.port : (useTls ? 443 : 80),
    };
    if (username.isNotEmpty) {
      outbound['username'] = username;
    }
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }
    if (useTls) {
      outbound['tls'] = _buildTls(params, uri.host);
    }
    return outbound;
  }

  String _safeDecode(String value) {
    try {
      return Uri.decodeComponent(value);
    } catch (_) {
      return value;
    }
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  bool _looksLikeSingBoxConfig(Map<String, dynamic> json) =>
      json.containsKey('outbounds') || json.containsKey('inbounds');

  /// اولین outbound واقعی پروکسی را انتخاب می‌کند (نه direct/block/selector)
  /// و tag آن را روی 'proxy' تنظیم می‌کند، چون route.final روی 'proxy' است.
  Map<String, dynamic> _adoptSingBoxConfig(Map<String, dynamic> json) {
    final Object? rawOutbounds = json['outbounds'];
    if (rawOutbounds is List) {
      for (final Object? item in rawOutbounds) {
        if (item is! Map) continue;
        final Map<String, dynamic> out = Map<String, dynamic>.from(item);
        final String type = (out['type'] ?? '').toString().toLowerCase();
        if (type.isEmpty || _nonProxyTypes.contains(type)) continue;
        out['tag'] = 'proxy';
        return out;
      }
    }

    // فرمت جدید sing-box: WireGuard زیر endpoints می‌آید.
    final Object? endpoints = json['endpoints'];
    if (endpoints is List) {
      for (final Object? item in endpoints) {
        if (item is Map) {
          final Map<String, dynamic> out = Map<String, dynamic>.from(item);
          out['tag'] = 'proxy';
          return out;
        }
      }
    }

    throw const SingBoxConfigException(
        'در کانفیگ sing-box هیچ outbound پروکسی قابل استفاده‌ای پیدا نشد.');
  }
}
