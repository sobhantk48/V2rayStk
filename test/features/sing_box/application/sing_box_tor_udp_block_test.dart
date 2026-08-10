import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// رگرسیون: SOCKS5 تور از UDP ASSOCIATE پشتیبانی نمی‌کند.
/// هر تلاش UDP (QUIC روی 443) خطای «code=7 command not supported» می‌سازد،
/// پس در حالت Tor باید UDP بلاک شود تا کلاینت به TCP/TLS سقوط کند.
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  List<Map<String, dynamic>> routeRules(Profile profile) {
    final config = generator.generate(profile).value;
    final route = config['route'] as Map<String, dynamic>;
    return (route['rules'] as List).cast<Map<String, dynamic>>();
  }

  bool hasUdpBlock(Profile profile) => routeRules(profile).any(
        (rule) => rule['network'] == 'udp' && rule['outbound'] == 'block',
      );

  final torTyped = Profile(
    id: 'tor-typed',
    name: 'Tor (typed)',
    type: ProfileType.tor,
    rawConfig: 'tor://127.0.0.1:9050',
    createdAt: now,
    server: '127.0.0.1',
    port: 9050,
  );

  final torSocks = Profile(
    id: 'tor-socks',
    name: 'Tor (socks)',
    type: ProfileType.socks,
    rawConfig: 'socks://127.0.0.1:9050',
    createdAt: now,
    server: '127.0.0.1',
    port: 9050,
  );

  final remoteSocks = Profile(
    id: 'remote-socks',
    name: 'Remote SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://198.51.100.10:1080',
    createdAt: now,
    server: '198.51.100.10',
    port: 1080,
  );

  group('بلاک UDP در حالت Tor', () {
    test('ProfileType.tor قانون udp->block دارد', () {
      expect(hasUdpBlock(torTyped), isTrue);
    });

    test('socks لوکال هم قانون udp->block دارد', () {
      expect(hasUdpBlock(torSocks), isTrue);
    });

    test('socks ریموت هرگز UDP بلاک نمی‌شود', () {
      expect(hasUdpBlock(remoteSocks), isFalse,
          reason: 'پروکسی معمولی UDP دارد و نباید محدود شود');
    });
  });

  group('ترتیب قوانین حفظ شده', () {
    test('بلاک UDP آخرین قانون است', () {
      final rules = routeRules(torTyped);
      expect(rules.last['network'], 'udp');
      expect(rules.last['outbound'], 'block');
    });

    test('hijack پورت 53 بالاتر از بلاک UDP است', () {
      final rules = routeRules(torTyped);
      final dnsIndex = rules.indexWhere((r) => r['outbound'] == 'dns-out');
      final udpIndex = rules.indexWhere((r) => r['network'] == 'udp');

      expect(dnsIndex, greaterThanOrEqualTo(0));
      expect(dnsIndex, lessThan(udpIndex),
          reason: 'اگر UDP بالاتر باشد DNS تور روی 5353 قطع می‌شود');
    });

    test('loopback direct بالاتر از بلاک UDP است', () {
      final rules = routeRules(torTyped);
      final loopIndex = rules.indexWhere((r) {
        final cidrs = (r['ip_cidr'] as List?)?.cast<String>() ?? const [];
        return r['outbound'] == 'direct' &&
            cidrs.any((cidr) => cidr.startsWith('127.'));
      });
      final udpIndex = rules.indexWhere((r) => r['network'] == 'udp');

      expect(loopIndex, greaterThanOrEqualTo(0));
      expect(loopIndex, lessThan(udpIndex));
    });

    test('DNS تور همچنان روی 5353 محلی است', () {
      final config = generator.generate(torTyped).value;
      final dns = config['dns'] as Map<String, dynamic>;
      final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
      final proxyDns =
          servers.firstWhere((server) => server['tag'] == 'proxy-dns');

      expect(proxyDns['address'], 'udp://127.0.0.1:5353');
      expect(proxyDns['detour'], 'direct');
    });
  });
}
