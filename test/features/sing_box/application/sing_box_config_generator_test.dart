import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:v2ray_stk/features/profiles/domain/profile.dart';
import 'package:v2ray_stk/features/profiles/domain/profile_type.dart';
import 'package:v2ray_stk/features/sing_box/application/sing_box_config_generator.dart';
import 'package:v2ray_stk/features/sing_box/domain/sing_box_config_exception.dart';

void main() {
  const generator = SingBoxConfigGenerator();

  group('SingBoxConfigGenerator', () {
    test('generates vmess outbound from base64 json config', () {
      final vmessJson = <String, dynamic>{
        'v': '2',
        'ps': 'vmess-test',
        'add': 'example.com',
        'port': '443',
        'id': '11111111-1111-1111-1111-111111111111',
        'aid': '0',
        'scy': 'auto',
        'net': 'ws',
        'type': 'none',
        'host': 'cdn.example.com',
        'path': '/ws',
        'tls': 'tls',
        'sni': 'tls.example.com',
      };

      final rawConfig =
          'vmess://${base64Encode(utf8.encode(jsonEncode(vmessJson)))}';

      final profile = Profile(
        id: 'p1',
        name: 'VMess Test',
        address: 'example.com',
        port: 443,
        type: ProfileType.vmess,
        rawConfig: rawConfig,
      );

      final config = generator.generate(profile);
      final outbound =
          (config.value['outbounds'] as List).first as Map<String, dynamic>;

      expect(outbound['type'], 'vmess');
      expect(outbound['tag'], 'VMess_Test');
      expect(outbound['server'], 'example.com');
      expect(outbound['server_port'], 443);
      expect(outbound['uuid'], '11111111-1111-1111-1111-111111111111');
      expect(outbound['security'], 'auto');

      final tls = outbound['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'tls.example.com');

      final transport = outbound['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'ws');
      expect(transport['path'], '/ws');

      final headers = transport['headers'] as Map<String, dynamic>;
      expect(headers['Host'], 'cdn.example.com');
    });

    test('generates vless outbound from uri config', () {
      const rawConfig =
          'vless://11111111-1111-1111-1111-111111111111@example.com:443'
          '?security=tls&type=ws&host=cdn.example.com&path=%2Fvless&sni=tls.example.com';

      final profile = Profile(
        id: 'p2',
        name: 'VLESS Test',
        address: 'example.com',
        port: 443,
        type: ProfileType.vless,
        rawConfig: rawConfig,
      );

      final config = generator.generate(profile);
      final outbound =
          (config.value['outbounds'] as List).first as Map<String, dynamic>;

      expect(outbound['type'], 'vless');
      expect(outbound['server'], 'example.com');
      expect(outbound['server_port'], 443);
      expect(outbound['uuid'], '11111111-1111-1111-1111-111111111111');

      final tls = outbound['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'tls.example.com');

      final transport = outbound['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'ws');
      expect(transport['path'], '/vless');

      final headers = transport['headers'] as Map<String, dynamic>;
      expect(headers['Host'], 'cdn.example.com');
    });

    test('generates trojan outbound from uri config', () {
      const rawConfig =
          'trojan://secret@example.com:443'
          '?security=tls&type=ws&host=cdn.example.com&path=%2Ftrojan&sni=tls.example.com';

      final profile = Profile(
        id: 'p3',
        name: 'Trojan Test',
        address: 'example.com',
        port: 443,
        type: ProfileType.trojan,
        rawConfig: rawConfig,
      );

      final config = generator.generate(profile);
      final outbound =
          (config.value['outbounds'] as List).first as Map<String, dynamic>;

      expect(outbound['type'], 'trojan');
      expect(outbound['server'], 'example.com');
      expect(outbound['server_port'], 443);
      expect(outbound['password'], 'secret');

      final tls = outbound['tls'] as Map<String, dynamic>;
      expect(tls['enabled'], true);
      expect(tls['server_name'], 'tls.example.com');

      final transport = outbound['transport'] as Map<String, dynamic>;
      expect(transport['type'], 'ws');
      expect(transport['path'], '/trojan');

      final headers = transport['headers'] as Map<String, dynamic>;
      expect(headers['Host'], 'cdn.example.com');
    });

    test('generates shadowsocks outbound from plain userinfo', () {
      const rawConfig = 'ss://aes-256-gcm:secret@example.com:8388';

      final profile = Profile(
        id: 'p4',
        name: 'SS Test',
        address: 'example.com',
        port: 8388,
        type: ProfileType.shadowsocks,
        rawConfig: rawConfig,
      );

      final config = generator.generate(profile);
      final outbound =
          (config.value['outbounds'] as List).first as Map<String, dynamic>;

      expect(outbound['type'], 'shadowsocks');
      expect(outbound['server'], 'example.com');
      expect(outbound['server_port'], 8388);
      expect(outbound['method'], 'aes-256-gcm');
      expect(outbound['password'], 'secret');
    });

    test('generates socks outbound with auth', () {
      const rawConfig = 'socks://user:pass@example.com:1080';

      final profile = Profile(
        id: 'p5',
        name: 'SOCKS Test',
        address: 'example.com',
        port: 1080,
        type: ProfileType.socks,
        rawConfig: rawConfig,
      );

      final config = generator.generate(profile);
      final outbound =
          (config.value['outbounds'] as List).first as Map<String, dynamic>;

      expect(outbound['type'], 'socks');
      expect(outbound['server'], 'example.com');
      expect(outbound['server_port'], 1080);
      expect(outbound['username'], 'user');
      expect(outbound['password'], 'pass');
    });

    test('generates http outbound with auth', () {
      const rawConfig = 'http://user:pass@example.com:8080';

      final profile = Profile(
        id: 'p6',
        name: 'HTTP Test',
        address: 'example.com',
        port: 8080,
        type: ProfileType.http,
        rawConfig: rawConfig,
      );

      final config = generator.generate(profile);
      final outbound =
          (config.value['outbounds'] as List).first as Map<String, dynamic>;

      expect(outbound['type'], 'http');
      expect(outbound['server'], 'example.com');
      expect(outbound['server_port'], 8080);
      expect(outbound['username'], 'user');
      expect(outbound['password'], 'pass');
    });

    test('throws fail-fast for unsupported wireguard', () {
      final profile = Profile(
        id: 'p7',
        name: 'WG Test',
        address: 'example.com',
        port: 51820,
        type: ProfileType.wireguard,
        rawConfig: 'wireguard://example',
      );

      expect(
        () => generator.generate(profile),
        throwsA(isA<SingBoxConfigException>()),
      );
    });

    test('throws fail-fast for invalid vmess payload', () {
      final profile = Profile(
        id: 'p8',
        name: 'Broken VMess',
        address: 'example.com',
        port: 443,
        type: ProfileType.vmess,
        rawConfig: 'vmess://broken-base64',
      );

      expect(
        () => generator.generate(profile),
        throwsA(isA<Object>()),
      );
    });

    test('sets route final to generated outbound tag', () {
      const rawConfig = 'http://user:pass@example.com:8080';

      final profile = Profile(
        id: 'p9',
        name: 'My Proxy',
        address: 'example.com',
        port: 8080,
        type: ProfileType.http,
        rawConfig: rawConfig,
      );

      final config = generator.generate(profile);
      final route = config.value['route'] as Map<String, dynamic>;

      expect(route['final'], 'My_Proxy');
      expect(route['auto_detect_interface'], true);
    });
  });
}
