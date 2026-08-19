import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// تست‌های رگرسیون برای جلوگیری از بازگشت باگ‌های:
/// 1) بازگشت stack=system روی tun (خطای set read deadline: invalid argument)
/// 2) حلقهٔ بازگشتی DNS (proxy-dns با detour=proxy)
/// 3) بازگشت ترافیک لوکال (SOCKS محلی Tor) به داخل تونل
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  Map<String, dynamic> configFor(Profile profile) =>
      generator.generate(profile).value;

  List<Map<String, dynamic>> dnsServers(Map<String, dynamic> config) {
    final dns = config['dns'] as Map<String, dynamic>;
    return (dns['servers'] as List).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic>? serverByTag(
    Map<String, dynamic> config,
    String tag,
  ) {
    for (final server in dnsServers(config)) {
      if (server['tag'] == tag) {
        return server;
      }
    }
    return null;
  }

  Map<String, dynamic>? tunInbound(Map<String, dynamic> config) {
    final inbounds = (config['inbounds'] as List?) ?? const [];
    for (final inbound in inbounds.cast<Map<String, dynamic>>()) {
      if (inbound['type'] == 'tun') {
        return inbound;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> routeRules(Map<String, dynamic> config) {
    final route = config['route'] as Map<String, dynamic>?;
    final rules = (route?['rules'] as List?) ?? const [];
    return rules.cast<Map<String, dynamic>>();
  }

  final vlessProfile = Profile(
    id: 'dns-p1',
    name: 'VLESS DNS Test',
    type: ProfileType.vless,
    rawConfig: 'vless://11111111-1111-1111-1111-111111111111@example.com:443'
        '?security=tls&type=ws&host=cdn.example.com&path=%2Fvless'
        '&sni=tls.example.com',
    createdAt: now,
    server: 'example.com',
    port: 443,
  );

  group('tun stack', () {
    test('از gvisor استفاده می‌کند و هرگز system نیست', () {
      final config = configFor(vlessProfile);
      final tun = tunInbound(config);

      expect(tun, isNotNull, reason: 'inbound نوع tun باید وجود داشته باشد');
      expect(tun!['stack'], 'gvisor');
      expect(tun['stack'], isNot('system'));
    });
  });

  group('DNS anti-loop', () {
    test('bootstrap-dns با detour=direct وجود دارد', () {
      final config = configFor(vlessProfile);
      final bootstrap = serverByTag(config, 'bootstrap-dns');

      expect(bootstrap, isNotNull,
          reason: 'برای حل مستقیم دامنهٔ سرور، bootstrap-dns لازم است');
      expect(bootstrap!['detour'], 'direct');
    });

    test('proxy-dns از address_resolver استفاده می‌کند و حلقه نمی‌سازد', () {
      final config = configFor(vlessProfile);
      final proxyDns = serverByTag(config, 'proxy-dns');

      expect(proxyDns, isNotNull);
      expect(proxyDns!['address_resolver'], 'bootstrap-dns');
    });

    test('هیچ سرور DNS با detour=proxy و بدون address_resolver نیست', () {
      final config = configFor(vlessProfile);

      for (final server in dnsServers(config)) {
        if (server['detour'] == 'proxy') {
          expect(
            server['address_resolver'],
            isNotNull,
            reason: 'سرور ${server['tag']} حلقهٔ DNS می‌سازد',
          );
        }
      }
    });
  });

  group('route rules', () {
    test('ترافیک شبکه‌های خصوصی و لوکال‌هاست direct می‌شود', () {
      final config = configFor(vlessProfile);
      final rules = routeRules(config);

      final hasLoopback = rules.any((rule) {
        final cidrs = (rule['ip_cidr'] as List?)?.cast<String>() ?? const [];
        return rule['outbound'] == 'direct' &&
            cidrs.any((cidr) => cidr.startsWith('127.'));
      });

      expect(hasLoopback, isTrue,
          reason: '127.0.0.0/8 باید direct باشد تا SOCKS محلی حلقه نزند');
    });

    test('دامنهٔ سرور پروکسی برای جلوگیری از حلقه direct می‌شود', () {
      final config = configFor(vlessProfile);
      final rules = routeRules(config);

      final hasServerRule = rules.any((rule) {
        final domains = (rule['domain'] as List?)?.cast<String>() ?? const [];
        return domains.contains('example.com');
      });

      expect(hasServerRule, isTrue,
          reason: 'دامنهٔ سرور نباید از داخل تونل حل شود');
    });
  });
}
