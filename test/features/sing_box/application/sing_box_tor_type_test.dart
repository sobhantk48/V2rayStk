import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';

/// رگرسیون: ProfileType.tor باید حالت Tor را فعال کند.
/// قبل از پچ، _isTorProfile فقط ProfileType.socks را قبول می‌کرد و
/// پروفایل tor به DoH خارجی می‌افتاد (نشتی DNS).
void main() {
  const generator = SingBoxConfigGenerator();
  final now = DateTime.now();

  Map<String, dynamic>? proxyDns(Profile profile) {
    final config = generator.generate(profile).value;
    final dns = config['dns'] as Map<String, dynamic>;
    final servers = (dns['servers'] as List).cast<Map<String, dynamic>>();
    for (final server in servers) {
      if (server['tag'] == 'proxy-dns') return server;
    }
    return null;
  }

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

  test('ProfileType.tor -> DNS محلی 5353', () {
    final server = proxyDns(torTyped);
    expect(server, isNotNull);
    expect(server!['address'], 'udp://127.0.0.1:5353');
    expect(server['detour'], 'direct');
  });

  test('ProfileType.tor هرگز به DoH عمومی نمی‌افتد', () {
    final server = proxyDns(torTyped)!;
    expect((server['address'] as String).startsWith('https://'), isFalse);
    expect(server.containsKey('address_resolver'), isFalse);
  });

  test('socks لوکال همچنان Tor شناخته می‌شود (رفتار قبلی حفظ شده)', () {
    expect(proxyDns(torSocks)!['address'], 'udp://127.0.0.1:5353');
  });

  test('socks ریموت تحت تأثیر پچ قرار نگرفته', () {
    final server = proxyDns(remoteSocks)!;
    expect(server['address'], isNot('udp://127.0.0.1:5353'));
    expect(server['detour'], 'proxy');
  });
}
