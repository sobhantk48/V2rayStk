import '../../admin/domain/admin_settings.dart';

/// تنظیمات پنل ادمین را روی کانفیگ تولیدشدهٔ sing-box اعمال می‌کند.
/// generator اصلی دست‌نخورده می‌ماند تا پارس پروتکل‌ها خراب نشود.
class AdminConfigPatcher {
  const AdminConfigPatcher();

  static const int minMtu = 576;
  static const int maxMtu = 9000;

  Map<String, dynamic> apply(
    Map<String, dynamic> config,
    AdminSettings settings,
  ) {
    final Map<String, dynamic> out = Map<String, dynamic>.from(config);
    _patchLog(out, settings);
    _patchTunMtu(out, settings);
    _patchDns(out, settings);
    _patchClashApi(out, settings);
    return out;
  }

  void _patchLog(Map<String, dynamic> config, AdminSettings settings) {
    const Set<String> allowed = <String>{
      'trace',
      'debug',
      'info',
      'warn',
      'error',
      'fatal',
      'panic',
    };
    final String level = settings.logLevel.trim().toLowerCase();
    config['log'] = <String, dynamic>{
      'level': allowed.contains(level) ? level : 'warn',
      'timestamp': true,
    };
  }

  void _patchTunMtu(Map<String, dynamic> config, AdminSettings settings) {
    final dynamic inbounds = config['inbounds'];
    if (inbounds is! List) {
      return;
    }
    final int mtu = settings.mtu.clamp(minMtu, maxMtu);
    for (final dynamic item in inbounds) {
      if (item is Map && item['type'] == 'tun') {
        item['mtu'] = mtu;
      }
    }
  }

  void _patchDns(Map<String, dynamic> config, AdminSettings settings) {
    final String address = _dnsAddress(settings);
    if (address.isEmpty) {
      return;
    }

    final dynamic existing = config['dns'];
    if (existing is Map) {
      final Map<String, dynamic> dns = Map<String, dynamic>.from(existing);
      final dynamic servers = dns['servers'];
      if (servers is List && servers.isNotEmpty && servers.first is Map) {
        final Map<String, dynamic> first =
            Map<String, dynamic>.from(servers.first as Map);
        first['address'] = address;
        servers[0] = first;
      } else {
        dns['servers'] = <Map<String, dynamic>>[
          <String, dynamic>{'tag': 'dns-remote', 'address': address},
        ];
      }
      if (settings.splitDns) {
        dns['strategy'] = 'prefer_ipv4';
        dns['independent_cache'] = true;
      }
      config['dns'] = dns;
      return;
    }

    config['dns'] = <String, dynamic>{
      'servers': <Map<String, dynamic>>[
        <String, dynamic>{'tag': 'dns-remote', 'address': address},
      ],
      if (settings.splitDns) 'strategy': 'prefer_ipv4',
      if (settings.splitDns) 'independent_cache': true,
    };
  }

  /// حالت DNS را به قالب آدرس قابل‌فهم برای sing-box تبدیل می‌کند.
  String _dnsAddress(AdminSettings settings) {
    final String server = settings.dnsServer.trim();
    if (server.isEmpty) {
      return '';
    }
    final String mode = settings.dnsMode.trim().toLowerCase();
    final bool hasScheme = server.contains('://');

    switch (mode) {
      case 'doh':
        if (hasScheme) {
          return server;
        }
        return 'https://$server/dns-query';
      case 'dot':
        if (hasScheme) {
          return server;
        }
        return 'tls://$server';
      case 'tcp':
        if (hasScheme) {
          return server;
        }
        return 'tcp://$server';
      default:
        if (hasScheme) {
          return server;
        }
        return server;
    }
  }

  void _patchClashApi(Map<String, dynamic> config, AdminSettings settings) {
    final dynamic existing = config['experimental'];
    final Map<String, dynamic> experimental = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};

    final int port = settings.clashApiPort;
    final bool validPort = port > 0 && port < 65536;

    if (!settings.clashApiEnabled || !validPort) {
      experimental.remove('clash_api');
    } else {
      final dynamic current = experimental['clash_api'];
      final Map<String, dynamic> api = current is Map
          ? Map<String, dynamic>.from(current)
          : <String, dynamic>{};
      api['external_controller'] = '127.0.0.1:$port';
      experimental['clash_api'] = api;
    }

    if (experimental.isEmpty) {
      config.remove('experimental');
    } else {
      config['experimental'] = experimental;
    }
  }
}
