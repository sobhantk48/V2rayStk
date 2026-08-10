import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// رگرسیون نشتی DNS در حالت Tor.
/// پروفایل Tor = ProfileType.socks روی 127.0.0.1 (خروجی TorDaemon: socks 9050 / dns 5353)
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  Map<String, dynamic> configFor(Profile profile) =>
      generator.generate(profile).value;

  List<Map<String, dynamic>> dnsServers(Map<String, dynamic> config) {
    final dns = config['dns'] as Map<String, dynamic>;
    return (dns['servers'] as List).cast<Map<String, dynamic>>();
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

  final torProfile = Profile(
    id: 'tor-p1',
    name: 'Tor Local SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://127.0.0.1:9050',
    createdAt: now,
    server: '127.0.0.1',
    port: 9050,
  );

  final plainSocksProfile = Profile(
    id: 'socks-p1',
    name: 'Remote SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://198.51.100.10:1080',
    createdAt: now,
    server: '198.51.100.10',
    port: 1080,
  );

  group('Tor mode DNS', () {
    test('proxy-dns به resolver محلی 5353 می‌رود', () {
      final config = configFor(torProfile);
      final proxyDns = serverByTag(config, 'proxy-dns');

      expect(proxyDns, isNotNull);
      expect(proxyDns!['address'], 'udp://127.0.0.1:5353');
    });

    test('DNS تور از تونل بیرون نمی‌رود (detour=direct)', () {
      final config = configFor(torProfile);
      final proxyDns = serverByTag(config, 'proxy-dns');

      expect(proxyDns!['detour'], 'direct',
          reason: 'اگر detour=proxy باشد DNS تور حلقه می‌زند');
    });

    test('هیچ DoH عمومی در حالت Tor استفاده نمی‌شود', () {
      final config = configFor(torProfile);

      for (final server in dnsServers(config)) {
        if (server['tag'] == 'proxy-dns') {
          final address = server['address'] as String;
          expect(address.startsWith('https://'), isFalse,
              reason: 'در حالت Tor باید فقط 5353 محلی استفاده شود');
        }
      }
    });

    test('لوپ‌بک direct است تا 9050 و 5353 قابل دسترسی بمانند', () {
      final config = configFor(torProfile);
      final rules = routeRules(config);

      final hasLoopback = rules.any((rule) {
        final cidrs = (rule['ip_cidr'] as List?)?.cast<String>() ?? const [];
        return rule['outbound'] == 'direct' &&
            cidrs.any((cidr) => cidr.startsWith('127.'));
      });

      expect(hasLoopback, isTrue);
    });
  });

  group('SOCKS غیرلوکال نباید Tor تشخیص داده شود', () {
    test('proxy-dns همان مسیر معمول DoH را می‌گیرد', () {
      final config = configFor(plainSocksProfile);
      final proxyDns = serverByTag(config, 'proxy-dns');

      expect(proxyDns, isNotNull);
      expect(proxyDns!['address'], isNot('udp://127.0.0.1:5353'));
      expect(proxyDns['address_resolver'], 'bootstrap-dns');
    });
  });
}
