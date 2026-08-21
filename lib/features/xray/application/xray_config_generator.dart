import 'dart:convert';

import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';

/// XRAY_GEN_V1
///
/// از `rawConfig` یک پروفایل، کانفیگ استاندارد هسته Xray می‌سازد.
///
/// معماری: Xray یک inbound از نوع socks روی [socksPort] باز می‌کند و
/// sing-box کل ترافیک tun را به همان پورت تحویل می‌دهد. پس Xray فقط
/// نقش «هسته خروجی» را دارد و مسیریابی/DNS/tun دست sing-box می‌ماند.
class XrayConfigGenerator {
  const XrayConfigGenerator._();

  /// پورت SOCKS داخلی که sing-box به آن وصل می‌شود.
  static const int socksPort = 10808;

  /// transport هایی که sing-box پشتیبانی نمی‌کند و حتماً Xray لازم دارند.
  static const Set<String> _xrayOnlyNetworks = <String>{
    'xhttp',
    'splithttp',
  };

  /// آیا این پروفایل باید با هسته Xray اجرا شود؟
  ///
  /// NEEDS_XRAY_V2: علاوه بر xhttp/splithttp، پروتکل‌های Reality و
  /// XTLS Vision هم فقط روی Xray کار می‌کنند و باید اینجا تشخیص داده شوند
  /// وگرنه به sing-box می‌روند و خطای unsupported xhttp transport می‌دهند.
  static bool needsXray(Profile profile) {
    final String raw = profile.rawConfig.toLowerCase();

    // نشانگر صریح در لینک
    if (raw.contains('xray=1')) {
      return true;
    }

    // transport هایی که فقط Xray دارد (xhttp / splithttp)
    // هم شکل type= و هم شکل net= را پوشش می‌دهیم
    for (final String net in _xrayOnlyNetworks) {
      if (raw.contains('type=$net') || raw.contains('net=$net')) {
        return true;
      }
    }

    // XTLS Vision فقط روی هسته Xray اجرا می‌شود
    if (raw.contains('xtls-rprx-vision') || raw.contains('flow=xtls')) {
      return true;
    }

    // Reality: هم پارامتر security=reality و هم فیلدهای اختصاصی
    if (raw.contains('security=reality') ||
        raw.contains('realitysettings') ||
        raw.contains('reality_opts')) {
      return true;
    }

    // لینک Reality معمولاً pbk (publicKey) و sid (shortId) دارد
    if (raw.contains('pbk=') && raw.contains('sid=')) {
      return true;
    }

    return false;
  }

  /// خروجی JSON کانفیگ Xray؛ رشته خالی یعنی «Xray لازم نیست».
  ///
  /// هیچ‌وقت throw نمی‌کند تا یک لینک معیوب کل اتصال را نخواباند.
  static String tryBuild(Profile profile) {
    if (!needsXray(profile)) {
      return '';
    }
    try {
      return jsonEncode(build(profile));
    } catch (_) {
      return '';
    }
  }

  /// ساخت نقشه کانفیگ Xray. در صورت لینک نامعتبر throw می‌کند.
  static Map<String, dynamic> build(Profile profile) {
    final Map<String, dynamic> outbound = _outbound(profile);
    return <String, dynamic>{
      'log': <String, dynamic>{'loglevel': 'warning'},
      // XRAY_DNS_V2: بدون این بلوک، Xray هیچ resolver ای ندارد و
      // دامنه‌های sniff شده (youtube.com و ...) حل نمی‌شوند.
      'dns': <String, dynamic>{
        'servers': <dynamic>[
          <String, dynamic>{
            'address': 'https://1.1.1.1/dns-query',
            'domains': <String>['geosite:geolocation-!cn'],
          },
          'https://1.0.0.1/dns-query',
          'localhost',
        ],
        'queryStrategy': 'UseIPv4',
        'disableCache': false,
        'tag': 'dns-in',
      },
      'inbounds': <Map<String, dynamic>>[
        <String, dynamic>{
          'tag': 'socks-in',
          'listen': '127.0.0.1',
          'port': socksPort,
          'protocol': 'socks',
          'settings': <String, dynamic>{
            'auth': 'noauth',
            'udp': true,
          },
          'sniffing': <String, dynamic>{
            'enabled': true,
            'destOverride': <String>['http', 'tls', 'quic'],
            'routeOnly': true,
          },
        },
      ],
      // XRAY_LOOP_FIX_V1: مسیریابی صریح تا ترافیک لوکال
      // و شبکه خصوصی وارد تونل نشود.
      'routing': <String, dynamic>{
        // XRAY_DNS_V2: IPIfNonMatch لازم است تا دامنه sniff شده
        // به IP تبدیل و درست مسیریابی شود.
        'domainStrategy': 'IPIfNonMatch',
        'rules': <Map<String, dynamic>>[
          // پرس‌وجوهای DNS خود Xray مستقیم بروند (نه داخل تونل)
          <String, dynamic>{
            'type': 'field',
            'inboundTag': <String>['dns-in'],
            'outboundTag': 'direct',
          },
          <String, dynamic>{
            'type': 'field',
            'port': 53,
            'network': 'udp',
            'outboundTag': 'proxy',
          },
          // XRAY_DNS_V2: شبکه خصوصی باید direct باشد نه block،
          // وگرنه ارتباط لوکال با sing-box قطع می‌شود.
          <String, dynamic>{
            'type': 'field',
            'ip': <String>['geoip:private'],
            'outboundTag': 'direct',
          },
          <String, dynamic>{
            'type': 'field',
            'network': 'tcp,udp',
            'outboundTag': 'proxy',
          },
        ],
      },
      'outbounds': <Map<String, dynamic>>[
        outbound,
        <String, dynamic>{'tag': 'direct', 'protocol': 'freedom'},
        <String, dynamic>{'tag': 'block', 'protocol': 'blackhole'},
      ],
    };
  }

  // ---------------------------------------------------------------- outbound

  static Map<String, dynamic> _outbound(Profile profile) {
    final String raw = profile.rawConfig.trim();
    final int sep = raw.indexOf('://');
    if (sep <= 0) {
      throw FormatException('Xray: invalid link "${profile.name}"');
    }
    final String scheme = raw.substring(0, sep).toLowerCase();

    switch (scheme) {
      case 'vless':
        return _vless(raw);
      case 'trojan':
        return _trojan(raw);
      case 'vmess':
        return _vmess(raw);
      default:
        throw FormatException('Xray: protocol "$scheme" not supported');
    }
  }

  static Map<String, dynamic> _vless(String raw) {
    final Uri uri = Uri.parse(raw);
    final Map<String, String> q = uri.queryParameters;
    final String uuid = Uri.decodeComponent(uri.userInfo);
    if (uuid.isEmpty) {
      throw const FormatException('Xray: VLESS uuid is missing');
    }

    final Map<String, dynamic> user = <String, dynamic>{
      'id': uuid,
      'encryption': _orDefault(q['encryption'], 'none'),
    };
    final String flow = (q['flow'] ?? '').trim();
    if (flow.isNotEmpty && flow != 'none') {
      user['flow'] = flow;
    }

    return <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': <String, dynamic>{
        'vnext': <Map<String, dynamic>>[
          <String, dynamic>{
            'address': _host(uri),
            'port': _port(uri, ProfileType.vless.defaultPort),
            'users': <Map<String, dynamic>>[user],
          },
        ],
      },
      'streamSettings': _stream(q, _host(uri)),
    };
  }

  static Map<String, dynamic> _trojan(String raw) {
    final Uri uri = Uri.parse(raw);
    final Map<String, String> q = uri.queryParameters;
    final String password = Uri.decodeComponent(uri.userInfo);
    if (password.isEmpty) {
      throw const FormatException('Xray: Trojan password is missing');
    }

    return <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': <String, dynamic>{
        'servers': <Map<String, dynamic>>[
          <String, dynamic>{
            'address': _host(uri),
            'port': _port(uri, ProfileType.trojan.defaultPort),
            'password': password,
          },
        ],
      },
      'streamSettings': _stream(q, _host(uri), defaultSecurity: 'tls'),
    };
  }

  static Map<String, dynamic> _vmess(String raw) {
    final String body = raw.substring(raw.indexOf('://') + 3).trim();

    // نسخه لینک استاندارد vmess: base64(json)
    Map<String, dynamic>? node;
    try {
      final String decoded = utf8.decode(base64.decode(_padBase64(body)));
      final Object? parsed = jsonDecode(decoded);
      if (parsed is Map) {
        node = Map<String, dynamic>.from(parsed);
      }
    } catch (_) {
      node = null;
    }

    if (node == null) {
      // نسخه URI مانند: vmess://uuid@host:port?...
      final Uri uri = Uri.parse(raw);
      final Map<String, String> q = uri.queryParameters;
      return <String, dynamic>{
        'tag': 'proxy',
        'protocol': 'vmess',
        'settings': <String, dynamic>{
          'vnext': <Map<String, dynamic>>[
            <String, dynamic>{
              'address': _host(uri),
              'port': _port(uri, ProfileType.vmess.defaultPort),
              'users': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': Uri.decodeComponent(uri.userInfo),
                  'alterId': int.tryParse(q['alterId'] ?? '0') ?? 0,
                  'security': _orDefault(q['security'], 'auto'),
                },
              ],
            },
          ],
        },
        'streamSettings': _stream(q, _host(uri)),
      };
    }

    final Map<String, String> q = <String, String>{
      'type': _str(node['net'], 'tcp'),
      'headerType': _str(node['type'], ''),
      'host': _str(node['host'], ''),
      'path': _str(node['path'], ''),
      'sni': _str(node['sni'], ''),
      'alpn': _str(node['alpn'], ''),
      'fp': _str(node['fp'], ''),
      'security': _str(node['tls'], ''),
      'serviceName': _str(node['path'], ''),
    };
    final String address = _str(node['add'], '');
    if (address.isEmpty) {
      throw const FormatException('Xray: VMess address is missing');
    }

    return <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vmess',
      'settings': <String, dynamic>{
        'vnext': <Map<String, dynamic>>[
          <String, dynamic>{
            'address': address,
            'port': int.tryParse(_str(node['port'], '443')) ?? 443,
            'users': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': _str(node['id'], ''),
                'alterId': int.tryParse(_str(node['aid'], '0')) ?? 0,
                'security': _orDefault(_str(node['scy'], ''), 'auto'),
              },
            ],
          },
        ],
      },
      'streamSettings': _stream(q, address),
    };
  }

  // ------------------------------------------------------------ stream/tls

  static Map<String, dynamic> _stream(
    Map<String, String> q,
    String fallbackSni, {
    String defaultSecurity = 'none',
  }) {
    final String rawNet = (q['type'] ?? q['net'] ?? 'tcp').toLowerCase();
    final String network = _normalizeNetwork(rawNet);
    final String security =
        _normalizeSecurity(q['security'] ?? defaultSecurity);

    final Map<String, dynamic> stream = <String, dynamic>{
      'network': network,
      'security': security,
    };

    final String sni = _firstNonEmpty(<String?>[
      q['sni'],
      q['peer'],
      q['host'],
      fallbackSni,
    ]);

    if (security == 'reality') {
      final Map<String, dynamic> reality = <String, dynamic>{
        'serverName': sni,
        'publicKey': _orDefault(q['pbk'], ''),
        'shortId': _orDefault(q['sid'], ''),
        'spiderX': _orDefault(q['spx'], '/'),
      };
      final String fp = _orDefault(q['fp'], 'chrome');
      if (fp.isNotEmpty) {
        reality['fingerprint'] = fp;
      }
      stream['realitySettings'] = reality;
    } else if (security == 'tls') {
      final Map<String, dynamic> tls = <String, dynamic>{
        'serverName': sni,
        'allowInsecure': _isTrue(q['allowInsecure']) || _isTrue(q['insecure']),
      };
      final String fp = (q['fp'] ?? '').trim();
      if (fp.isNotEmpty) {
        tls['fingerprint'] = fp;
      }
      final List<String> alpn = _splitList(q['alpn']);
      if (alpn.isNotEmpty) {
        tls['alpn'] = alpn;
      }
      stream['tlsSettings'] = tls;
    }

    switch (network) {
      case 'ws':
        stream['wsSettings'] = <String, dynamic>{
          'path': _orDefault(q['path'], '/'),
          if ((q['host'] ?? '').trim().isNotEmpty)
            'headers': <String, dynamic>{'Host': q['host']!.trim()},
        };
        break;
      case 'httpupgrade':
        stream['httpupgradeSettings'] = <String, dynamic>{
          'path': _orDefault(q['path'], '/'),
          'host': _orDefault(q['host'], sni),
        };
        break;
      case 'xhttp':
        stream['xhttpSettings'] = <String, dynamic>{
          'path': _orDefault(q['path'], '/'),
          'host': _orDefault(q['host'], sni),
          'mode': _orDefault(q['mode'], 'auto'),
        };
        break;
      case 'grpc':
        stream['grpcSettings'] = <String, dynamic>{
          'serviceName': _orDefault(q['serviceName'], _orDefault(q['path'], '')),
          'multiMode': _isTrue(q['mode']) || (q['mode'] ?? '') == 'multi',
        };
        break;
      case 'http':
        stream['httpSettings'] = <String, dynamic>{
          'path': _orDefault(q['path'], '/'),
          if ((q['host'] ?? '').trim().isNotEmpty)
            'host': _splitList(q['host']),
        };
        break;
      case 'tcp':
        if ((q['headerType'] ?? '').toLowerCase() == 'http') {
          stream['tcpSettings'] = <String, dynamic>{
            'header': <String, dynamic>{
              'type': 'http',
              'request': <String, dynamic>{
                'path': <String>[_orDefault(q['path'], '/')],
                'headers': <String, dynamic>{
                  'Host': _splitList(q['host']).isEmpty
                      ? <String>[sni]
                      : _splitList(q['host']),
                },
              },
            },
          };
        }
        break;
      default:
        break;
    }

    return stream;
  }

  // ----------------------------------------------------------------- utils

  static String _normalizeNetwork(String value) {
    switch (value) {
      case 'splithttp':
      case 'xhttp':
        return 'xhttp';
      case 'h2':
      case 'http':
        return 'http';
      case 'websocket':
      case 'ws':
        return 'ws';
      case 'httpupgrade':
        return 'httpupgrade';
      case 'grpc':
        return 'grpc';
      case 'kcp':
      case 'mkcp':
        return 'kcp';
      case '':
        return 'tcp';
      default:
        return value;
    }
  }

  static String _normalizeSecurity(String value) {
    final String key = value.trim().toLowerCase();
    if (key == 'reality' || key == 'xtls-reality') {
      return 'reality';
    }
    if (key == 'tls' || key == 'true' || key == '1' || key == 'xtls') {
      return 'tls';
    }
    return 'none';
  }

  static String _host(Uri uri) {
    final String host = uri.host;
    if (host.isEmpty) {
      throw const FormatException('Xray: server host is missing');
    }
    return host;
  }

  static int _port(Uri uri, int fallback) {
    return uri.hasPort && uri.port > 0 ? uri.port : fallback;
  }

  static String _orDefault(String? value, String fallback) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? fallback : text;
  }

  static String _str(Object? value, String fallback) {
    if (value == null) {
      return fallback;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String text = (value ?? '').trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static List<String> _splitList(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return <String>[];
    }
    return text
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  static bool _isTrue(String? value) {
    final String key = (value ?? '').trim().toLowerCase();
    return key == '1' || key == 'true' || key == 'yes';
  }

  static String _padBase64(String value) {
    final String clean =
        value.replaceAll('-', '+').replaceAll('_', '/').split('#').first.trim();
    final int mod = clean.length % 4;
    return mod == 0 ? clean : clean + '=' * (4 - mod);
  }

  /// XRAY_LOOP_FIX_V1
  /// آدرس سرور واقعی پروفایل را برمی گرداند تا sing-box بتواند آن را
  /// مستقیم (direct) بفرستد و ترافیک Xray داخل TUN حلقه نزند.
  static String serverHostOf(Profile profile) {
    final String raw = (profile.server ?? '').trim();
    if (raw.isEmpty) {
      return '';
    }
    return raw;
  }

  /// پورت سرور واقعی پروفایل.
  static int serverPortOf(Profile profile) {
    return profile.port ?? 0;
  }
}
