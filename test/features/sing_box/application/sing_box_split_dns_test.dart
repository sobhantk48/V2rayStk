import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/sing_box/application/admin_config_patcher.dart';

void main() {
  group('Split DNS', () {
    test('domain parsing normalizes tld and wildcards', () {
      expect(parseSplitDnsDomains('ir'), <String>['.ir']);
      expect(parseSplitDnsDomains('*.digikala.com'), <String>['.digikala.com']);
      expect(
        parseSplitDnsDomains('ir, aparat.com , ir'),
        <String>['.ir', 'aparat.com'],
      );
      expect(parseSplitDnsDomains('   '), <String>[]);
    });

    test('local address falls back to system resolver', () {
      expect(normalizeLocalDnsAddress(''), 'local');
      expect(normalizeLocalDnsAddress('system'), 'local');
      expect(normalizeLocalDnsAddress('8.8.8.8'), '8.8.8.8');
    });

    test('adds local-dns server and a leading rule', () {
      final Map<String, dynamic> dns = <String, dynamic>{
        'servers': <dynamic>[
          <String, dynamic>{'tag': 'proxy-dns', 'address': 'tls://1.1.1.1'},
        ],
        'rules': <dynamic>[
          <String, dynamic>{'outbound': 'any', 'server': 'proxy-dns'},
        ],
      };

      applySplitDnsPatch(dns, localServer: 'local', directDomains: 'ir');

      final List<dynamic> servers = dns['servers'] as List<dynamic>;
      final Map<dynamic, dynamic> local = servers.last as Map<dynamic, dynamic>;
      expect(local['tag'], 'local-dns');
      expect(local['address'], 'local');
      expect(local.containsKey('detour'), isFalse);

      final List<dynamic> rules = dns['rules'] as List<dynamic>;
      final Map<dynamic, dynamic> first = rules.first as Map<dynamic, dynamic>;
      expect(first['server'], 'local-dns');
      expect(first['domain_suffix'], <String>['.ir']);
      expect(rules.length, 2);
      expect(dns['independent_cache'], isTrue);
      expect(dns['strategy'], 'prefer_ipv4');
    });

    test('custom local server gets direct detour and is idempotent', () {
      final Map<String, dynamic> dns = <String, dynamic>{};
      applySplitDnsPatch(dns, localServer: '78.157.42.100', directDomains: 'ir');
      applySplitDnsPatch(dns, localServer: '78.157.42.100', directDomains: 'ir');

      expect((dns['servers'] as List<dynamic>).length, 1);
      expect((dns['rules'] as List<dynamic>).length, 1);
      final Map<dynamic, dynamic> s =
          (dns['servers'] as List<dynamic>).first as Map<dynamic, dynamic>;
      expect(s['detour'], 'direct');
      expect(s['address'], '78.157.42.100');
    });
  });
}
