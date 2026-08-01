import 'dart:convert';

import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../domain/sing_box_config.dart';
import '../domain/sing_box_config_exception.dart';
import 'v2ray_outbound_converter.dart';

class SingBoxConfigGenerator {
  final V2rayOutboundConverter _v2rayConverter = const V2rayOutboundConverter();

  const SingBoxConfigGenerator();

  SingBoxConfig generate(Profile profile) {
    try {
      final Map<String, dynamic>? json =
          _tryDecodeJsonObject(profile.rawConfig);

      if (json != null) {
        if (_looksLikeSingBoxConfig(json)) {
          return SingBoxConfig(_wrap(_adoptSingBoxConfig(json)));
        }
        return SingBoxConfig(
          _wrap(_v2rayConverter.convert(json, tag: 'proxy')),
        );
      }

      // اگر لینک URI بود (مثل vless://)
      return SingBoxConfig(_wrap(_buildOutboundFromUri(profile)));
    } catch (e) {
      throw SingBoxConfigException('خطا در تولید کانفیگ: $e');
    }
  }

  Map<String, dynamic> _buildOutboundFromUri(Profile profile) {
    final uri = Uri.parse(profile.rawConfig);
    final params = uri.queryParameters;
    const tag = 'proxy';

    switch (profile.type) {
      case ProfileType.vless:
      case ProfileType.reality:
        return _buildVlessOutbound(uri, params, tag);
      case ProfileType.trojan:
        return _buildTrojanOutbound(uri, params, tag);
      case ProfileType.shadowsocks:
        return _buildShadowsocksOutbound(uri, params, tag);
      default:
        throw SingBoxConfigException(
            'پروتکل ${profile.type} هنوز به صورت کامل پشتیبانی نمی‌شود.');
    }
  }

  Map<String, dynamic> _buildVlessOutbound(
      Uri uri, Map<String, String> params, String tag) {
    final String uuid = uri.userInfo;
    final String security = (params['security'] ?? '').toLowerCase();
    final String pbk = params['pbk'] ?? '';
    final String sni = params['sni'] ?? params['host'] ?? '';
    final String sid = params['sid'] ?? '';
    final String fp = params['fp'] ?? 'chrome';
    final String flow = params['flow'] ?? '';

    final Map<String, dynamic> outbound = {
      'type': 'vless',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'uuid': uuid};

    // flow فقط وقتی اضافه شود که واقعا مقدار دارد (خالی باعث خطا می‌شود)
    if (flow.isNotEmpty) {
      outbound['flow'] = flow;
    }

    if (security == 'reality' || pbk.isNotEmpty) {
      if (pbk.isEmpty) {
        throw const SingBoxConfigException(
            'Public Key (pbk) برای Reality الزامی است');
      }
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni,
        'utls': {
          'enabled': true,
          'fingerprint': fp},
        'reality': {
          'enabled': true,
          'public_key': pbk,
          'short_id': sid}
      };
    } else if (security == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni,
        'utls': {
          'enabled': true,
          'fingerprint': fp}};
    }

    _addTransport(outbound, params);
    return outbound;
  }

  void _addTransport(Map<String, dynamic> outbound, Map<String, String> params) {
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
    if (!cleanPath.startsWith('/')) cleanPath = '/\$cleanPath';

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
        throw const SingBoxConfigException('ترنسپورت پشتیبانی‌نشده: \$type');
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
    return {
      'type': 'trojan',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'password': uri.userInfo,
      'tls': {
        'enabled': true,
        'server_name': params['sni'] ?? params['host'] ?? '',
        'utls': {
          'enabled': true,
          'fingerprint': params['fp'] ?? 'chrome'}}
    };
  }

  Map<String, dynamic> _buildShadowsocksOutbound(
      Uri uri, Map<String, String> params, String tag) {
    return {
      'type': 'shadowsocks',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'method': 'aes-256-gcm',
      'password': uri.userInfo};
  }

  Map<String, dynamic> _wrap(Map<String, dynamic> outbound) {
    return {
      'log': {'level': 'info', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:9090',
          'access_control_allow_origin': '*',
        },
        'cache_file': {'enabled': true},
      },
      'dns': {
        'servers': [
          {
            'tag': 'proxy-dns',
            'address': 'tls://8.8.8.8',
            'detour': 'proxy',
          },
          {
            'tag': 'local-dns',
            'address': 'local',
            'detour': 'direct',
          },
          {'tag': 'block-dns', 'address': 'rcode://success'},
        ],
        'rules': [
          // فقط آدرس سرورهای خروجی با DNS سیستم حل شود تا لوپ ایجاد نشود
          {
            'outbound': ['any'],
            'server': 'local-dns',
          },
        ],
        'final': 'proxy-dns',
        'strategy': 'ipv4_only',
        'independent_cache': true,
        'disable_cache': false,
      },
      'inbounds': [
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': 'tun0',
          'inet4_address': '172.19.0.1/28',
          'auto_route': true,
          'strict_route': true,
          'stack': 'gvisor',
          'sniff': true,
          'sniff_override_destination': true,
          'domain_strategy': 'ipv4_only',
        }
      ],
      'outbounds': [
        outbound,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
        {'type': 'dns', 'tag': 'dns-out'}
      ],
      'route': {
        'rules': [
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {'ip_is_private': true, 'outbound': 'direct'},
        ],
        'final': 'proxy',
        'auto_detect_interface': true,
      }
    };
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

  Map<String, dynamic> _adoptSingBoxConfig(Map<String, dynamic> json) {
    if (json.containsKey('outbounds') &&
        (json['outbounds'] as List).isNotEmpty) {
      return json['outbounds'][0];
    }
    return json;
  }
}
