import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// رگرسیون نشتی نام دامنه در حالت Tor.
/// در حالت Tor: دامنه باید override شود و محلی resolve نشود.
/// در حالت غیرتور: رفتار قدیمی حفظ شود (ipv4_only + override=false).
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  Map<String, dynamic> tunInbound(Profile profile) {
    final config = generator.generate(profile).value;
    final inbounds = (config['inbounds'] as List).cast<Map>();
    final tun = inbounds.firstWhere((inbound) => inbound['type'] == 'tun');
    return Map<String, dynamic>.from(tun);
  }

  final torProfile = Profile(
    id: 'tor-sniff-1',
    name: 'Tor Local SOCKS',
    type: ProfileType.socks,
    rawConfig: 'socks://127.0.0.1:9050',
    createdAt: now,
    server: '127.0.0.1',
    port: 9050,
  );

  final vlessProfile = Profile(
    id: 'vless-sniff-1',
    name: 'Reality Node',
    type: ProfileType.vless,
    rawConfig:
        'vless://11111111-2222-3333-4444-555555555555@example.com:443'
        '?security=reality&pbk=abcdef123456&sni=example.com&sid=ab&fp=chrome',
    createdAt: now,
    server: 'example.com',
    port: 443,
  );

  group('حالت Tor: نام دامنه لو نمی‌رود', () {
    test('sniff فعال است', () {
      expect(tunInbound(torProfile)['sniff'], isTrue);
    });

    test('دامنه‌ی sniff‌شده جایگزین مقصد می‌شود', () {
      expect(tunInbound(torProfile)['sniff_override_destination'], isTrue,
          reason: 'اگر false باشد فقط IP خام به تور می‌رسد');
    });

    test('domain_strategy محلی وجود ندارد', () {
      final inbound = tunInbound(torProfile);
      expect(inbound.containsKey('domain_strategy'), isFalse,
          reason: 'ipv4_only باعث resolve محلی قبل از تور می‌شود');
    });
  });

  group('حالت غیرتور: رفتار قبلی حفظ می‌شود', () {
    test('override خاموش می‌ماند تا قوانین ip_cidr نشکنند', () {
      expect(tunInbound(vlessProfile)['sniff_override_destination'], isFalse);
    });

    test('domain_strategy همان ipv4_only است', () {
      expect(tunInbound(vlessProfile)['domain_strategy'], 'ipv4_only');
    });
  });
}
