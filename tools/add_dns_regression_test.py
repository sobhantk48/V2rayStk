#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ساخت تست رگرسیون برای DNS/TUN تا باگ حلقه DNS دوباره برنگردد."""
import io, os

os.makedirs("test/features/sing_box/application", exist_ok=True)
PATH = "test/features/sing_box/application/sing_box_dns_route_test.dart"

CODE = r'''import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

void main() {
  final generator = SingBoxConfigGenerator();

  Profile mkProfile() => Profile(
        id: 'test-1',
        name: 'DNS Regression',
        type: ProfileType.vless,
        rawUri:
            'vless://11111111-2222-3333-4444-555555555555@example.com:443?security=tls&sni=example.com#dnstest',
      );

  Map<String, dynamic> gen() =>
      generator.generate(mkProfile()).value as Map<String, dynamic>;

  group('TUN inbound', () {
    test('stack باید system باشد نه gvisor', () {
      final tun = (gen()['inbounds'] as List).first as Map<String, dynamic>;
      expect(tun['stack'], 'system',
          reason: 'gvisor روی اندروید ناپایدار است');
      expect(tun['auto_route'], isTrue);
    });
  });

  group('DNS', () {
    test('bootstrap-dns باید وجود داشته باشد و detour=direct باشد', () {
      final dns = gen()['dns'] as Map<String, dynamic>;
      final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
      final bootstrap =
          servers.firstWhere((s) => s['tag'] == 'bootstrap-dns');
      expect(bootstrap['detour'], 'direct',
          reason: 'bootstrap نباید از تونل عبور کند');
    });

    test('proxy-dns نباید بدون address_resolver از detour=proxy استفاده کند',
        () {
      final dns = gen()['dns'] as Map<String, dynamic>;
      final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
      final proxyDns = servers.firstWhere((s) => s['tag'] == 'proxy-dns');
      if (proxyDns['detour'] == 'proxy') {
        expect(proxyDns['address_resolver'], isNotNull,
            reason: 'بدون resolver حلقه DNS ایجاد می‌شود');
      }
    });

    test('final باید proxy-dns باشد', () {
      expect((gen()['dns'] as Map<String, dynamic>)['final'], 'proxy-dns');
    });
  });

  group('Route', () {
    test('لوکال‌هاست و شبکه‌های خصوصی باید direct باشند', () {
      final route = gen()['route'] as Map<String, dynamic>;
      final rules = (route['rules'] as List).cast<Map<String, dynamic>>();
      final localRule = rules.firstWhere(
        (r) => r['ip_cidr'] != null && r['outbound'] == 'direct',
        orElse: () => <String, dynamic>{},
      );
      expect(localRule.isNotEmpty, isTrue,
          reason: 'بدون این rule ترافیک SOCKS تور وارد تونل می‌شود');
      expect((localRule['ip_cidr'] as List), contains('127.0.0.0/8'));
    });

    test('ترافیک DNS باید به dns-out هدایت شود', () {
      final route = gen()['route'] as Map<String, dynamic>;
      final rules = (route['rules'] as List).cast<Map<String, dynamic>>();
      expect(rules.any((r) => r['outbound'] == 'dns-out'), isTrue);
    });

    test('final باید proxy باشد', () {
      expect((gen()['route'] as Map<String, dynamic>)['final'], 'proxy');
    });
  });
}
'''

io.open(PATH, "w", encoding="utf-8").write(CODE)
print("[DONE] تست ساخته شد: " + PATH)
