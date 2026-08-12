import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// قفل امنیتی DNS — هر ۵ اصلاحِ ضدنشتی اینجا تثبیت می‌شود.
/// اگر کسی (یا خودِ ما در آینده) این رفتارها را خراب کند، تست قرمز می‌شود.
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  Map<String, dynamic> configFor(Profile profile) =>
      generator.generate(profile).value;

  List<Map<String, dynamic>> dnsServers(Map<String, dynamic> config) {
    final dns = config['dns'] as Map<String, dynamic>;
    return (dns['servers'] as List).cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> dnsRules(Map<String, dynamic> config) {
    final dns = config['dns'] as Map<String, dynamic>;
    final rules = (dns['rules'] as List?) ?? const [];
    return rules.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic>? serverByTag(Map<String, dynamic> config, String tag) {
    for (final server in dnsServers(config)) {
      if (server['tag'] == tag) return server;
    }
    return null;
  }

  List<Map<String, dynamic>> routeRules(Map<String, dynamic> config) {
    final route = config['route'] as Map<String, dynamic>?;
    final rules = (route?['rules'] as List?) ?? const [];
    return rules.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> tunInbound(Map<String, dynamic> config) {
    final inbounds = (config['inbounds'] as List).cast<Map<String, dynamic>>();
    return inbounds.firstWhere((i) => i['type'] == 'tun');
  }

  /// همه‌ی مقادیر رشته‌ایِ یک rule را صاف می‌کند تا جست‌وجو ساده شود.
  List<String> flatStrings(Object? value) {
    if (value == null) return const [];
    if (value is String) return [value];
    if (value is List) return value.expand(flatStrings).toList();
    if (value is Map) return value.values.expand(flatStrings).toList();
    return [value.toString()];
  }

  List<int> flatInts(Object? value) {
    if (value == null) return const [];
    if (value is int) return [value];
    if (value is List) return value.expand(flatInts).toList();
    return const [];
  }

  final torProfile = Profile(
    id: 'tor-hard-1',
    name: 'Tor Local SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://127.0.0.1:9050',
    createdAt: now,
    server: '127.0.0.1',
    port: 9050,
  );

  final plainProfile = Profile(
    id: 'socks-hard-1',
    name: 'Remote SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://198.51.100.10:1080',
    createdAt: now,
    server: '198.51.100.10',
    port: 1080,
  );

  group('1) strict_route', () {
    test('در حالت Tor فعال است', () {
      final tun = tunInbound(configFor(torProfile));
      expect(tun['strict_route'], isTrue,
          reason: 'بدون strict_route ترافیک DNS می‌تواند از tun فرار کند');
    });

    test('در حالت عادی فعال نیست', () {
      final tun = tunInbound(configFor(plainProfile));
      expect(tun['strict_route'], isFalse);
    });
  });

  group('2) دامنه‌های محلی در Tor', () {
    final localMarkers = ['local', 'lan', 'home'];

    test('.local/.lan/.home به block-dns می‌روند', () {
      final config = configFor(torProfile);
      final matched = dnsRules(config).where((rule) {
        final values = flatStrings(rule['domain_suffix']) +
            flatStrings(rule['domain']) +
            flatStrings(rule['domain_keyword']);
        return values.any(
          (v) => localMarkers.any((m) => v.toLowerCase().endsWith(m)),
        );
      }).toList();

      expect(matched, isNotEmpty,
          reason: 'قانون دامنه‌های محلی در حالت Tor پیدا نشد');
      for (final rule in matched) {
        expect(rule['server'], 'block-dns',
            reason: 'دامنه محلی نباید به resolver عمومی برود');
      }
    });

    test('سرور block-dns تعریف شده است', () {
      expect(serverByTag(configFor(torProfile), 'block-dns'), isNotNull);
    });

    test('هیچ قانون محلی به DNS عمومی اشاره نمی‌کند', () {
      final config = configFor(torProfile);
      for (final rule in dnsRules(config)) {
        final values = flatStrings(rule['domain_suffix']) +
            flatStrings(rule['domain']);
        final isLocal = values.any(
          (v) => localMarkers.any((m) => v.toLowerCase().endsWith(m)),
        );
        if (!isLocal) continue;
        expect(rule['server'], isNot('bootstrap-dns'));
        expect(rule['server'], isNot('proxy-dns'));
      }
    });
  });

  group('3+4) اجبار ipv4_only', () {
    test('bootstrap-dns فقط IPv4 است', () {
      final bootstrap = serverByTag(configFor(torProfile), 'bootstrap-dns');
      expect(bootstrap, isNotNull);
      expect(bootstrap!['strategy'], 'ipv4_only');
    });

    test('proxy-dns در حالت Tor فقط IPv4 است', () {
      final proxyDns = serverByTag(configFor(torProfile), 'proxy-dns');
      expect(proxyDns, isNotNull);
      expect(proxyDns!['strategy'], 'ipv4_only',
          reason: 'پاسخ AAAA در مسیر Tor می‌تواند به نشتی منجر شود');
    });

    test('در حالت عادی هم bootstrap-dns روی IPv4 قفل است', () {
      final bootstrap = serverByTag(configFor(plainProfile), 'bootstrap-dns');
      expect(bootstrap!['strategy'], 'ipv4_only');
    });
  });

  group('5) مسدودسازی DoT (پورت 853)', () {
    bool blocksDot(Map<String, dynamic> config) {
      return routeRules(config).any((rule) {
        final ports = flatInts(rule['port']);
        return ports.contains(853) && rule['outbound'] == 'block';
      });
    }

    test('در حالت Tor پورت 853 بلاک است', () {
      expect(blocksDot(configFor(torProfile)), isTrue,
          reason: 'اپ‌ها می‌توانند با DoT مستقیم DNS را دور بزنند');
    });

    test('در حالت عادی هم پورت 853 بلاک است', () {
      expect(blocksDot(configFor(plainProfile)), isTrue);
    });
  });

  group('ضدرگرسیون کلی', () {
    test('در Tor هیچ آدرس DNS عمومیِ UDP باقی نمانده', () {
      final config = configFor(torProfile);
      final proxyDns = serverByTag(config, 'proxy-dns')!;
      expect(proxyDns['address'], 'udp://127.0.0.1:5353');
      expect(proxyDns['detour'], 'direct');
    });
  });
}
