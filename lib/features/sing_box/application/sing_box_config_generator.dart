import 'dart:convert';
import 'package:riverpod/riverpod.dart';
import '../domain/sing_box_config.dart';
import '../domain/sing_box_config_exception.dart';
import '../../admin/domain/admin_settings.dart';

// ==================== CONFIG GENERATOR ====================

class SingBoxConfigGenerator {
  final AdminSettings? adminSettings;

  const SingBoxConfigGenerator({this.adminSettings});

  String generate(SingBoxConfig config) {
    final routeRules = <Map<String, dynamic>>[
      {'protocol': 'dns', 'outbound': 'dns-out'},
      {'ip_is_private': true, 'outbound': 'direct'},
    ];

    // حذف قاعده مسدودسازی UDP/443 (دقیقاً همان چیزی که باعث می‌شه یوتیوب و QUIC کار نکنه)
    // final route = { 'rules': routeRules, 'final': 'proxy', 'auto_detect_interface': true };

    final route = {
      'rules': routeRules,
      'final': 'proxy',
      'auto_detect_interface': true
    };

    final dns = _buildDns(config);
    final outbounds = [
      _buildProxyOutbound(config),
      const {'type': 'direct', 'tag': 'direct'},
      const {'type': 'block', 'tag': 'block'},
      {'type': 'dns', 'tag': 'dns-out'},
    ];

    final configJson = {
      'log': {'level': 'info', 'output': 'none'},
      'inbounds': _buildInbounds(config),
      'outbounds': outbounds,
      'route': route,
      'dns': dns,
      'experimental': {'cache_file': {'enabled': true, 'store_fakeip': true}},
    };

    return jsonEncode(configJson);
  }

  Map<String, dynamic> _buildDns(SingBoxConfig config) {
    final servers = <Map<String, dynamic>>[
      {
        'tag': 'proxy-dns',
        'address': 'tls://8.8.8.8',
        'detour': 'proxy',
        'address_resolver': 'local-dns',
        'address_strategy': 'prefer_ipv4'
      },
      {
        'tag': 'local-dns',
        'address': '223.5.5.5',
        'detour': 'direct'
      },
      {
        'tag': 'block-dns',
        'address': 'rcode://success'
      },
    ];

    final rules = <Map<String, dynamic>>[
      {'outbound': 'any', 'server': 'local-dns'},
    ];

    if (adminSettings?.dnsMode == 'doh' && config.dohUrl != null) {
      servers.add({
        'tag': 'doh-dns',
        'address': config.dohUrl!,
        'detour': 'proxy',
        'address_resolver': 'local-dns'
      });
      rules.add({'outbound': 'any', 'server': 'doh-dns'});
    }

    return {
      'servers': servers,
      'rules': rules,
      'final': 'proxy-dns',
      'strategy': 'prefer_ipv4',
      'disable_cache': false,
    };
  }

  Map<String, dynamic> _buildProxyOutbound(SingBoxConfig config) {
    final type = config.protocol.toLowerCase();

    final base = <String, dynamic>{
      'type': type,
      'tag': 'proxy',
      'server': config.server,
      'server_port': config.port,
    };

    switch (type) {
      case 'vless':
        return _buildVlessOutbound(base, config);
      case 'vmess':
        return _buildVmessOutbound(base, config);
      case 'trojan':
        return _buildTrojanOutbound(base, config);
      case 'shadowsocks':
        return _buildShadowsocksOutbound(base, config);
      case 'hysteria2':
        return _buildHysteria2Outbound(base, config);
      case 'tuic':
        return _buildTuicOutbound(base, config);
      case 'wireguard':
        return _buildWireguardOutbound(base, config);
      case 'shadowtls':
        return _buildShadowtlsOutbound(base, config);
      case 'anytls':
        return _buildAnytlsOutbound(base, config);
      case 'naiveproxy':
        return _buildNaiveOutbound(base, config);
      case 'socks':
        return _buildSocksOutbound(base, config);
      case 'http':
        return _buildHttpOutbound(base, config);
      case 'hysteria':
        return _buildHysteriaOutbound(base, config);
      case 'reality':
        return _buildRealityOutbound(base, config);
      case 'tor':
        return _buildTorOutbound(base, config);
      case 'ssh':
        return _buildSshOutbound(base, config);
      default:
        throw SingBoxConfigException('protocol_not_supported', 'پروتکل $type پشتیبانی نمی‌شود');
    }
  }

  Map<String, dynamic> _buildVlessOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out.addAll({
      'uuid': config.uuid!,
      'flow': config.flow ?? 'xtls-rprx-vision',
    });
    if (config.sni != null) out['server_name'] = config.sni;
    if (config.alpn != null) out['alpn'] = config.alpn.split(',');
    if (config.headerType == 'http') {
      out['transport'] = {'type': 'http', 'host': config.httpHost};
    } else if (config.headerType == 'ws') {
      out['transport'] = {
        'type': 'ws',
        'path': config.wsPath ?? '/',
        'headers': {'Host': config.wsHost ?? config.server}
      };
    }
    if (config.security == 'reality') {
      out['reality'] = {
        'public_key': config.realityPublicKey!,
        'short_id': config.realityShortId ?? '',
        'server_name': config.sni ?? config.server
      };
    }
    return out;
  }

  Map<String, dynamic> _buildVmessOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out.addAll({
      'uuid': config.uuid!,
      'security': config.security ?? 'auto',
      'alter_id': config.alterId ?? 0,
    });
    if (config.sni != null) out['server_name'] = config.sni;
    if (config.alpn != null) out['alpn'] = config.alpn.split(',');
    if (config.headerType == 'http') {
      out['transport'] = {'type': 'http', 'host': config.httpHost};
    } else if (config.headerType == 'ws') {
      out['transport'] = {
        'type': 'ws',
        'path': config.wsPath ?? '/',
        'headers': {'Host': config.wsHost ?? config.server}
      };
    }
    return out;
  }

  Map<String, dynamic> _buildTrojanOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['password'] = config.password!;
    if (config.sni != null) out['server_name'] = config.sni;
    if (config.alpn != null) out['alpn'] = config.alpn.split(',');
    if (config.headerType == 'ws') {
      out['transport'] = {
        'type': 'ws',
        'path': config.wsPath ?? '/',
        'headers': {'Host': config.wsHost ?? config.server}
      };
    }
    return out;
  }

  Map<String, dynamic> _buildShadowsocksOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['method'] = config.method!;
    out['password'] = config.password!;
    out['plugin'] = config.plugin ?? '';
    out['plugin_opts'] = config.pluginOpts ?? '';
    return out;
  }

  Map<String, dynamic> _buildHysteria2Outbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['password'] = config.password;
    out['obfs'] = config.obfs ?? '';
    if (config.obfsPassword != null) out['obfs_password'] = config.obfsPassword;
    return out;
  }

  Map<String, dynamic> _buildTuicOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['uuid'] = config.uuid!;
    out['password'] = config.password!;
    out['congestion_control'] = config.congestionControl ?? 'bbr';
    return out;
  }

  Map<String, dynamic> _buildWireguardOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['private_key'] = config.privateKey!;
    out['peer_public_key'] = config.peerPublicKey!;
    out['pre_shared_key'] = config.preSharedKey ?? '';
    out['addresses'] = config.addresses ?? ['10.0.0.2/32'];
    return out;
  }

  Map<String, dynamic> _buildShadowtlsOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['password'] = config.password!;
    out['handshake'] = {'type': 'none'};
    return out;
  }

  Map<String, dynamic> _buildAnytlsOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['password'] = config.password!;
    return out;
  }

  Map<String, dynamic> _buildNaiveOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['password'] = config.password!;
    return out;
  }

  Map<String, dynamic> _buildSocksOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['username'] = config.username;
    out['password'] = config.password;
    return out;
  }

  Map<String, dynamic> _buildHttpOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['username'] = config.username;
    out['password'] = config.password;
    return out;
  }

  Map<String, dynamic> _buildHysteriaOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['password'] = config.password!;
    return out;
  }

  Map<String, dynamic> _buildRealityOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['public_key'] = config.realityPublicKey!;
    out['short_id'] = config.realityShortId ?? '';
    return out;
  }

  Map<String, dynamic> _buildTorOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    return {
      'type': 'socks',
      'tag': 'proxy',
      'server': '127.0.0.1',
      'server_port': 9050,
      'version': '5',
      'tls': {'enabled': true}
    };
  }

  Map<String, dynamic> _buildSshOutbound(Map<String, dynamic> base, SingBoxConfig config) {
    final out = Map<String, dynamic>.from(base);
    out['username'] = config.username;
    out['password'] = config.password;
    return out;
  }

  List<Map<String, dynamic>> _buildInbounds(SingBoxConfig config) {
    final list = <Map<String, dynamic>>[];

    if (config.enableTun) {
      list.add({
        'type': 'tun',
        'tag': 'tun-in',
        'address': ['172.19.0.1/30'],
        'stack': config.tunStack ?? 'system',
        'sniff': true,
        'sniff_override_destination': true,
        'auto_route': true,
        'strict_route': true,
        'endpoint_independent_nat': true,
        'include_uid': config.includeUid ?? [],
        'exclude_uid': config.excludeUid ?? [],
      });
    }

    list.add({
      'type': 'mixed',
      'tag': 'mixed-in',
      'listen': '127.0.0.1',
      'listen_port': 1080,
      'sniff': true,
      'sniff_override_destination': true,
    });

    if (config.enableSocks) {
      list.add({
        'type': 'socks',
        'tag': 'socks-in',
        'listen': '127.0.0.1',
        'listen_port': 1081,
        'sniff': true,
      });
    }

    return list;
  }
}

final singBoxConfigGeneratorProvider = Provider<SingBoxConfigGenerator>(
  (ref) => SingBoxConfigGenerator(
    adminSettings: ref.read(adminSettingsReaderProvider),
  ),
);
