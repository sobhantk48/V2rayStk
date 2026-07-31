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
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni,
        'utls': {
          'enabled': true,
          'fingerprint': fp,
        },
        'reality': {
          'enabled': true,
          'public_key': pbk,
          'short_id': sid,
        }
      };
    } else if (security == 'tls') {
      outbound['tls'] = {
        'enabled': true,
        'server_name': sni,
        'utls': {
          'enabled': true,
          'fingerprint': fp,
        },
      };
    }

    _addTransport(outbound, params);
    return outbound;
  }

  void _addTransport(
      Map<String, dynamic> outbound, Map<String, String> params) {
    final type = params['type'] ?? '';
    if (type == 'ws') {
      outbound['transport'] = {
        'type': 'ws',
        'path': params['path'] ?? '/',
        'headers': {'Host': params['host'] ?? ''}
      };
    } else if (type == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc',
        'service_name': params['serviceName'] ?? ''
      };
    }
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
          'fingerprint': params['fp'] ?? 'chrome',
        },
      }
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
      'password': uri.userInfo,
    };
  }

  Map<String, dynamic> _wrap(Map<String, dynamic> outbound) {
    return {
      'log': {'level': 'info', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:9090',
          'access_control_allow_origin': '*',
        },
        'cache_file': {
          'enabled': true,
          'store_fakeip': true,
        }
      },
      'dns': {
        'servers': [
          {'tag': 'proxy-dns', 'address': 'tls://8.8.8.8', 'detour': 'proxy'},
          {'tag': 'local-dns', 'address': '223.5.5.5', 'detour': 'direct'},
          {'tag': 'block-dns', 'address': 'rcode://success'},
        ],
        'rules': [
          // آدرس خود سرورها همیشه از مسیر مستقیم حل شود (جلوگیری از لوپ)
          {'outbound': 'any', 'server': 'local-dns'},
        ],
        'final': 'proxy-dns',
        'strategy': 'ipv4_only',
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
          {'protocol': 'quic', 'outbound': 'block'},
          {
            'network': 'udp',
            'port': [443],
            'outbound': 'block'
          },
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
