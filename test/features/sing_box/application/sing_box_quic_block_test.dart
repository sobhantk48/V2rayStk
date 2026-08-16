import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// در حالت غیرتور فقط UDP/443 و UDP/8443 بلاک می شوند تا مرورگر از QUIC
/// به HTTP/2 روی TCP برگردد. بلاک کامل UDP فقط مخصوص Tor است.
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  List<Map<String, dynamic>> routeRules(Profile profile) {
    final config = generator.generate(profile).value;
    final route = Map<String, dynamic>.from(config['route'] as Map);
    return (route['rules'] as List)
        .cast<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  final vlessProfile = Profile(
    id: 'vless-quic-1',
    name: 'WS Node',
    type: ProfileType.vless,
    rawConfig: 'vless://11111111-2222-3333-4444-555555555555@example.com:443'
        '?security=tls&type=ws&host=example.com&path=%2Fws',
    createdAt: now,
    server: 'example.com',
    port: 443,
  );

  final torProfile = Profile(
    id: 'tor-quic-1',
    name: 'Tor Local SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://127.0.0.1:9050',
    createdAt: now,
    server: '127.0.0.1',
    port: 9050,
  );

  Map<String, dynamic>? quicRule(Profile profile) {
    for (final rule in routeRules(profile)) {
      if (rule['network'] != 'udp' || rule['outbound'] != 'block') continue;
      final ports = (rule['port'] as List?)?.cast<int>();
      if (ports != null && ports.contains(443)) return rule;
    }
    return null;
  }

  bool hasFullUdpBlock(Profile profile) => routeRules(profile).any(
        (rule) =>
            rule['network'] == 'udp' &&
            rule['outbound'] == 'block' &&
            rule['port'] == null,
      );

  group('بلاک QUIC در حالت غیرتور', () {
    test('UDP/443 بلاک است', () {
      expect(quicRule(vlessProfile), isNotNull,
          reason: 'بدون این قانون یوتیوب روی QUIC معلق می ماند');
    });

    test('UDP/8443 هم در همان قانون هست', () {
      final ports = (quicRule(vlessProfile)?['port'] as List?)?.cast<int>();
      expect(ports, contains(8443));
    });

    test('کل UDP بلاک نمی شود', () {
      expect(hasFullUdpBlock(vlessProfile), isFalse,
          reason: 'پروکسی معمولی باید UDP غیر QUIC را داشته باشد');
    });

    test('هیچ قانون بلاکی روی TCP نیست', () {
      final blocked = routeRules(vlessProfile).any(
          (rule) => rule['outbound'] == 'block' && rule['network'] == 'tcp');
      expect(blocked, isFalse);
    });
  });

  group('حالت Tor دست نخورده می ماند', () {
    test('بلاک کامل UDP باقی است', () {
      expect(hasFullUdpBlock(torProfile), isTrue);
    });
  });

  List<Map<String, dynamic>> dnsRules(Profile profile) {
    final config = generator.generate(profile).value;
    final dns = Map<String, dynamic>.from(config['dns'] as Map);
    return (dns['rules'] as List)
        .cast<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  }

  Map<String, dynamic>? svcbRule(Profile profile) {
    for (final rule in dnsRules(profile)) {
      final types = (rule['query_type'] as List?)?.cast<int>();
      if (types != null && types.contains(65)) return rule;
    }
    return null;
  }

  group('مسدودسازی رکورد HTTPS/SVCB', () {
    test('قانون query_type برای هر دو نوع 64 و 65 وجود دارد', () {
      final types =
          (svcbRule(vlessProfile)?['query_type'] as List?)?.cast<int>();
      expect(types, isNotNull,
          reason: 'بدون این قانون مرورگر باز هم HTTP/3 را امتحان می کند');
      expect(types, containsAll(<int>[64, 65]));
    });

    test('پاسخ این رکوردها از block-dns می آید', () {
      expect(svcbRule(vlessProfile)?['server'], 'block-dns');
    });

    test('این قانون اولین قانون DNS است تا بر بقیه اولویت بگیرد', () {
      final first = dnsRules(vlessProfile).first;
      expect(first['query_type'], isNotNull);
    });

    test('در حالت Tor هم همین قانون برقرار است', () {
      expect(svcbRule(torProfile)?['server'], 'block-dns');
    });

    test('سرور block-dns با rcode success تعریف شده است', () {
      final config = generator.generate(vlessProfile).value;
      final dns = Map<String, dynamic>.from(config['dns'] as Map);
      final servers = (dns['servers'] as List)
          .cast<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      final block = servers.firstWhere((s) => s['tag'] == 'block-dns');
      expect(block['address'], 'rcode://success');
    });
  });
}
