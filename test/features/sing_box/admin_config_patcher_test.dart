import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/admin/domain/admin_settings.dart';
import 'package:v2ray_stk/features/sing_box/application/admin_config_patcher.dart';

void main() {
  const AdminConfigPatcher patcher = AdminConfigPatcher();

  Map<String, dynamic> baseConfig() => <String, dynamic>{
        'log': <String, dynamic>{'level': 'info'},
        'inbounds': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'tun', 'mtu': 1500},
        ],
        'outbounds': <Map<String, dynamic>>[
          <String, dynamic>{'type': 'direct', 'tag': 'direct'},
        ],
      };

  test('سطح لاگ و MTU از تنظیمات ادمین اعمال می‌شود', () {
    const AdminSettings settings = AdminSettings(
      passwordHash: '',
      salt: '',
      logLevel: 'debug',
      mtu: 1400,
    );

    final Map<String, dynamic> result = patcher.apply(baseConfig(), settings);

    expect((result['log'] as Map)['level'], 'debug');
    expect((result['inbounds'] as List).first['mtu'], 1400);
  });

  test('MTU خارج از بازه clamp می‌شود', () {
    const AdminSettings settings = AdminSettings(
      passwordHash: '',
      salt: '',
      mtu: 99999,
    );

    final Map<String, dynamic> result = patcher.apply(baseConfig(), settings);

    expect((result['inbounds'] as List).first['mtu'], 9000);
  });

  test('DoT به آدرس tls تبدیل می‌شود', () {
    const AdminSettings settings = AdminSettings(
      passwordHash: '',
      salt: '',
      dnsMode: 'dot',
      dnsServer: '1.1.1.1',
    );

    final Map<String, dynamic> result = patcher.apply(baseConfig(), settings);
    final List<dynamic> servers = (result['dns'] as Map)['servers'] as List;

    expect((servers.first as Map)['address'], 'tls://1.1.1.1');
  });

  test('غیرفعال بودن Clash API بخش experimental را حذف می‌کند', () {
    const AdminSettings settings = AdminSettings(
      passwordHash: '',
      salt: '',
      clashApiEnabled: false,
    );

    final Map<String, dynamic> result = patcher.apply(baseConfig(), settings);

    expect(result.containsKey('experimental'), isFalse);
  });

  test('Clash API فعال پورت درست را ست می‌کند', () {
    const AdminSettings settings = AdminSettings(
      passwordHash: '',
      salt: '',
      clashApiPort: 9091,
    );

    final Map<String, dynamic> result = patcher.apply(baseConfig(), settings);
    final Map<dynamic, dynamic> api =
        (result['experimental'] as Map)['clash_api'] as Map;

    expect(api['external_controller'], '127.0.0.1:9091');
  });
}
