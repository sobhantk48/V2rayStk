import os, textwrap

os.makedirs("tool", exist_ok=True)
path = "tool/dump_admin_config.dart"

code = r'''
// ابزار توسعه: خروجی نهایی sing-box را بعد از اعمال تنظیمات ادمین چاپ می‌کند.
// اجرا:  dart run tool/dump_admin_config.dart
import 'dart:convert';

import 'package:v2ray_stk/features/admin/domain/admin_settings.dart';
import 'package:v2ray_stk/features/sing_box/application/admin_config_patcher.dart';

Map<String, dynamic> baseConfig() => <String, dynamic>{
      'log': <String, dynamic>{'level': 'info'},
      'dns': <String, dynamic>{
        'servers': <dynamic>[
          <String, dynamic>{
            'tag': 'proxy-dns',
            'address': '1.1.1.1',
            'detour': 'proxy',
          },
        ],
        'rules': <dynamic>[
          <String, dynamic>{'outbound': 'any', 'server': 'proxy-dns'},
        ],
      },
      'inbounds': <dynamic>[
        <String, dynamic>{
          'type': 'tun',
          'tag': 'tun-in',
          'mtu': 1500,
          'auto_route': true,
        },
      ],
      'outbounds': <dynamic>[
        <String, dynamic>{'type': 'vless', 'tag': 'proxy'},
        <String, dynamic>{'type': 'direct', 'tag': 'direct'},
      ],
    };

void show(String title, AdminSettings s) {
  final Map<String, dynamic> out =
      const AdminConfigPatcher().apply(baseConfig(), s);
  print('');
  print('=========================================================');
  print('  $title');
  print('=========================================================');
  print(const JsonEncoder.withIndent('  ').convert(out['dns']));
}

void main() {
  const AdminSettings base = AdminSettings(passwordHash: 'x', salt: 'y');

  show('۱) پیش‌فرض: DoH کلادفلر، Split DNS خاموش', base);

  show(
    '۲) DoH + Split DNS با DNS سیستم',
    base.copyWith(splitDns: true, splitDnsLocalServer: 'local'),
  );

  show(
    '۳) DoH + Split DNS با DNS محلی شاتل (78.157.42.100)',
    base.copyWith(
      splitDns: true,
      splitDnsLocalServer: '78.157.42.100',
      splitDnsDirectDomains: 'ir, aparat.com, *.digikala.com',
    ),
  );

  show(
    '۴) DoT به جای DoH',
    base.copyWith(dnsMode: 'dot', dnsServer: '1.1.1.1', splitDns: true),
  );

  show(
    '۵) حالت Tor (باید دست‌نخورده بماند)',
    base.copyWith(splitDns: true, dnsMode: 'doh'),
  );
}
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(code.lstrip())

print("ساخته شد:", path)
