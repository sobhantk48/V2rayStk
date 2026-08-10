import '../../admin/domain/admin_settings.dart';

/// تنظیمات پنل ادمین را روی کانفیگ تولیدشدهٔ sing-box اعمال می‌کند.
class AdminConfigPatcher {
  const AdminConfigPatcher();

  static const int minMtu = 576;
  static const int maxMtu = 9000;
  static const String bootstrapTag = 'dns-bootstrap';

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
    const Set<String> allowed = <String>{'trace', 'debug', 'info', 'warn', 'error', 'fatal', 'panic'};
    final String level = settings.logLevel.trim().toLowerCase();
    config['log'] = <String, dynamic>{
      'level': allowed.contains(level) ? level : 'warn',
      'timestamp': true,
    };
  }

  void _patchTunMtu(Map<String, dynamic> config, AdminSettings settings) {
    final dynamic inbounds = config['inbounds'];
    if (inbounds is! List) return;
    final int mtu = settings.mtu.clamp(minMtu, maxMtu);
    for (final dynamic item in inbounds) {
      if (item is Map && item['type'] == 'tun') {
        item['mtu'] = mtu;
      }
    }
  }

  void _patchDns(Map<String, dynamic> config, AdminSettings settings) {
    // در حالت Tor، DNS محلی (127.0.0.1:5353) نباید بازنویسی شود.
    if (_usesTorDns(config)) return;
    final String address = _dnsAddress(settings);
    if (address.isEmpty) return;

    final dynamic existing = config['dns'];
    final Map<String, dynamic> dns = existing is Map ? Map<String, dynamic>.from(existing) : <String, dynamic>{};
    
    final List<Map<String, dynamic>> servers = _serversOf(dns);
    
    // اگر سروری نداریم یا باید جایگزین کنیم
    if (servers.isEmpty) {
      servers.add(<String, dynamic>{'tag': 'dns-remote', 'address': address});
    } else {
      final int index = _targetIndex(servers);
      servers[index]['address'] = address;
    }

    // اضافه کردن Bootstrap DNS برای جلوگیری از missing address_resolver
    final bool needsResolver = address.contains('://');
    if (needsResolver) {
      bool hasBootstrap = false;
      for (final Map<String, dynamic> s in servers) {
        if (s['tag'] == bootstrapTag) hasBootstrap = true;
      }
      if (!hasBootstrap) {
        servers.add( <String, dynamic>{
          'tag': bootstrapTag,
          'address': '8.8.8.8',
          'detour': 'direct'
        });
      }
      
      // لینک کردن resolver به سرور اصلی
      final int targetIdx = _targetIndex(servers);
      servers[targetIdx]['address_resolver'] = bootstrapTag;
    }

    dns['servers'] = servers;
    if (settings.splitDns) {
      dns['strategy'] = 'prefer_ipv4';
      dns['independent_cache'] = true;
    }
    config['dns'] = dns;
  }

  List<Map<String, dynamic>> _serversOf(Map<String, dynamic> dns) {
    final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
    final dynamic raw = dns['servers'];
    if (raw is List) {
      for (final dynamic item in raw) {
        if (item is Map) out.add(Map<String, dynamic>.from(item));
      }
    }
    return out;
  }

  int _targetIndex(List<Map<String, dynamic>> servers) {
    const List<String> preferred = <String>['proxy-dns', 'dns-remote', 'remote', 'dns-proxy'];
    for (final String tag in preferred) {
      for (int i = 0; i < servers.length; i++) {
        if ('${servers[i]['tag']}'.trim().toLowerCase() == tag) return i;
      }
    }
    return 0;
  }

  /// آیا DNS محلی Tor در کانفیگ فعال است؟
  bool _usesTorDns(Map<String, dynamic> config) {
    final Object? dns = config['dns'];
    if (dns is! Map) {
      return false;
    }
    final Object? servers = dns['servers'];
    if (servers is! List) {
      return false;
    }
    for (final Object? server in servers) {
      if (server is Map &&
          (server['address'] ?? '').toString().contains('127.0.0.1:5353')) {
        return true;
      }
    }
    return false;
  }

  String _dnsAddress(AdminSettings settings) {
    final String server = settings.dnsServer.trim();
    if (server.isEmpty) return '';
    final String mode = settings.dnsMode.trim().toLowerCase();
    final bool hasScheme = server.contains('://');
    switch (mode) {
      case 'doh': return hasScheme ? server : 'https://$server/dns-query';
      case 'dot': return hasScheme ? server : 'tls://$server';
      case 'tcp': return hasScheme ? server : 'tcp://$server';
      default: return server;
    }
  }

  void _patchClashApi(Map<String, dynamic> config, AdminSettings settings) {
    final dynamic existing = config['experimental'];
    final Map<String, dynamic> experimental = existing is Map ? Map<String, dynamic>.from(existing) : <String, dynamic>{};
    final int port = settings.clashApiPort;
    final bool validPort = port > 0 && port < 65536;
    if (!settings.clashApiEnabled || !validPort) {
      experimental.remove('clash_api');
    } else {
      final dynamic current = experimental['clash_api'];
      final Map<String, dynamic> api = current is Map ? Map<String, dynamic>.from(current) : <String, dynamic>{};
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
