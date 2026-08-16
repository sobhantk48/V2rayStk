#!/usr/bin/env python3
"""رفع باگ‌های sing_box_config_generator.dart"""
import shutil, pathlib, sys

TARGET = pathlib.Path("lib/features/sing_box/application/sing_box_config_generator.dart")

SRC = r'''import 'dart:convert';

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
      final List<String> pair =
          _splitCredentials(decoded.substring(0, at2));
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

  Map<String, dynamic> _wrap(Map<String, dynamic> outbound,
      {bool isTor = false}) {
    final Object? srv = outbound['server'];
    final String proxyServer = srv is String ? srv.trim() : '';

    return {
      'log': {'level': 'info', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:9090',
          'access_control_allow_origin': '*',
        },
        'cache_file': {'enabled': true},
      },
      'dns': _buildDns(isTor, proxyServer),
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'inet4_address': '172.19.0.1/28',
          'mtu': 9000,
          'auto_route': true,
          'strict_route': isTor,
          'stack': 'system',
          'endpoint_independent_nat': true,
          'sniff': true,
          // در حالت Tor دامنه‌ی sniff‌شده باید جایگزین مقصد شود تا نام دامنه
          // (نه IP خام) به SOCKS تور تحویل داده شود.
          'sniff_override_destination': isTor,
          // در حالت Tor دامنه نباید محلی resolve شود؛ حل نام کار خود تور است.
          if (!isTor) 'domain_strategy': 'ipv4_only',
        }
      ],
      'outbounds': [
        outbound,
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
          // ۴) در حالت Tor هیچ UDP نداریم (SOCKS5 تور UDP ندارد).
          //    پورت ۵۳ و loopback بالاتر هندل شده‌اند، پس DNS سالم می‌ماند.
          if (isTor)
            {
              'network': 'udp',
              'outbound': 'block',
            },
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
      }
    };
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
  ///  - proxy-dns     : تور -> DNSPort محلی 5353 ، غیرتور -> DoH از داخل تونل
  Map<String, dynamic> _buildDns(bool isTor, String proxyServer) {
    final List<Map<String, dynamic>> servers = <Map<String, dynamic>>[
      // همیشه یک resolver مستقیم داریم تا آدرس سرور بدون تونل حل شود
      {
        'tag': 'bootstrap-dns',
        'address': '8.8.8.8',
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
          'address': 'https://1.1.1.1/dns-query',
          'address_resolver': 'bootstrap-dns',
          'strategy': 'ipv4_only',
          'detour': 'proxy',
        },
      {'tag': 'block-dns', 'address': 'rcode://success'},
    ];

    final List<Map<String, dynamic>> rules = <Map<String, dynamic>>[
      // دامنه‌ی سرور پروکسی حتماً باید با bootstrap حل شود (جلوگیری از حلقه)
      if (proxyServer.isNotEmpty && !_isIpLiteral(proxyServer))
        {
          'domain': <String>[proxyServer],
          'server': 'bootstrap-dns',
        },
      {
        'domain_suffix': <String>['.local', '.lan', '.home'],
        'server': isTor ? 'block-dns' : 'bootstrap-dns',
      },
    ];

    return <String, dynamic>{
      'servers': servers,
      'rules': rules,
      'final': 'proxy-dns',
      'strategy': 'ipv4_only',
      'independent_cache': true,
      'disable_cache': false,
      'reverse_mapping': true,
    };
  }

  /// آیا رشته یک IP خام است؟ (برای IP نیازی به DNS rule نیست)
  bool _isIpLiteral(String host) {
    if (host.contains(':')) return true; // IPv6
    final parts = host.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
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
'''

def main():
    if not TARGET.exists():
        print("خطا: فایل پیدا نشد ->", TARGET)
        print("مطمئن شو داخل پوشه‌ی ریشه‌ی پروژه هستی.")
        sys.exit(1)

    backup = TARGET.with_suffix(".dart.bugfix.bak")
    shutil.copy2(TARGET, backup)
    print("بکاپ ساخته شد ->", backup)

    TARGET.write_text(SRC, encoding="utf-8")
    print("فایل بازنویسی شد ->", TARGET)
    print("تعداد خطوط جدید:", len(SRC.splitlines()))

if __name__ == "__main__":
    main()
