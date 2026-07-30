import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../profiles/domain/profile.dart';
import '../../profiles/domain/profile_type.dart';
import '../domain/sing_box_config.dart';
import '../domain/sing_box_config_exception.dart';
import 'v2ray_outbound_converter.dart';

/// سازندهٔ کانفیگ sing-box از روی پروفایل.
///
/// سه مسیر ورودی پشتیبانی می‌شود:
/// 1) rawConfig یک کانفیگ کامل sing-box باشد -> فقط inbound/experimental جایگزین می‌شود.
/// 2) rawConfig یک کانفیگ v2ray/xray باشد -> با [V2rayOutboundConverter] تبدیل می‌شود.
/// 3) rawConfig یک URI اشتراک (vless://, vmess://, ...) باشد -> اینجا پارس می‌شود.
class SingBoxConfigGenerator {
  const SingBoxConfigGenerator();

  static const V2rayOutboundConverter _v2rayConverter = V2rayOutboundConverter();

  static const String tunInterfaceName = 'tun0';
  static const String tunAddress = '172.19.0.1/30';
  static const int tunMtu = 9000;
  static const String dnsRemoteAddress = 'tls://1.1.1.1';
  static const String dnsDirectAddress = 'local';

  static const String proxyTag = 'proxy';

  static const Set<String> _helperOutboundTypes = <String>{
    'direct',
    'block',
    'dns',
    'selector',
    'urltest',
  };

  // ---------------------------------------------------------------------------
  // API عمومی
  // ---------------------------------------------------------------------------

  SingBoxConfig generate(Profile profile) {
    final Map<String, dynamic>? json = _tryDecodeJsonObject(profile.rawConfig);

    if (json != null) {
      if (_looksLikeSingBoxConfig(json)) {
        return SingBoxConfig(_adoptSingBoxConfig(json));
      }
      return SingBoxConfig(
        _wrap(<Map<String, dynamic>>[
          _v2rayConverter.convert(json, tag: _safeTag(profile)),
        ]),
      );
    }

    return SingBoxConfig(_wrap(_buildOutbounds(profile)));
  }

  // ---------------------------------------------------------------------------
  // انتخاب سازندهٔ outbound بر اساس نوع پروفایل
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _buildOutbounds(Profile profile) {
    final String tag = _safeTag(profile);

    switch (profile.type) {
      case ProfileType.vmess:
        return <Map<String, dynamic>>[_buildVmessOutbound(profile, tag)];
      case ProfileType.vless:
      case ProfileType.reality:
        return <Map<String, dynamic>>[_buildVlessOutbound(profile, tag)];
      case ProfileType.trojan:
        return <Map<String, dynamic>>[_buildTrojanOutbound(profile, tag)];
      case ProfileType.shadowsocks:
        return <Map<String, dynamic>>[_buildShadowsocksOutbound(profile, tag)];
      case ProfileType.hysteria2:
        return <Map<String, dynamic>>[_buildHysteria2Outbound(profile, tag)];
      case ProfileType.hysteria:
        return <Map<String, dynamic>>[_buildHysteriaOutbound(profile, tag)];
      case ProfileType.tuic:
        return <Map<String, dynamic>>[_buildTuicOutbound(profile, tag)];
      case ProfileType.wireguard:
        return <Map<String, dynamic>>[_buildWireGuardOutbound(profile, tag)];
      case ProfileType.shadowtls:
        return _buildShadowTlsOutbounds(profile, tag);
      case ProfileType.anytls:
        return <Map<String, dynamic>>[_buildAnyTlsOutbound(profile, tag)];
      case ProfileType.naive:
        return <Map<String, dynamic>>[_buildNaiveOutbound(profile, tag)];
      case ProfileType.tor:
        return <Map<String, dynamic>>[_buildTorOutbound(profile, tag)];
      case ProfileType.ssh:
        return <Map<String, dynamic>>[_buildSshOutbound(profile, tag)];
      case ProfileType.socks:
        return <Map<String, dynamic>>[_buildSocksOutbound(profile, tag)];
      case ProfileType.http:
        return <Map<String, dynamic>>[_buildHttpOutbound(profile, tag)];
      case ProfileType.unknown:
        throw const SingBoxConfigException(
          'Unsupported or unknown profile type',
        );
    }
  }

  // ---------------------------------------------------------------------------
  // VLESS / Reality
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildVlessOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);
    final String uuid = _requireString(
      uri.userInfo.isNotEmpty ? uri.userInfo : uri.param(<String>['id']),
      'VLESS uuid',
    );

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'uuid': uuid,
    };

    final String flow = uri.param(<String>['flow']) ?? '';
    if (flow.isNotEmpty && flow != 'none') {
      outbound['flow'] = flow;
    }

    final String encryption = uri.param(<String>['encryption']) ?? '';
    if (encryption.isNotEmpty && encryption != 'none') {
      outbound['encryption'] = encryption;
    }

    outbound['packet_encoding'] =
        uri.param(<String>['packetEncoding', 'packet_encoding']) ?? 'xudp';

    final bool forceTls = profile.type == ProfileType.reality;
    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: forceTls,
    );
    if (tls != null) {
      outbound['tls'] = tls;
    }

    final Map<String, dynamic>? transport = _buildTransport(uri.params);
    if (transport != null) {
      outbound['transport'] = transport;
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // VMess (هم base64 JSON و هم URI استاندارد)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildVmessOutbound(Profile profile, String tag) {
    final Map<String, dynamic>? legacy = _tryDecodeVmessLegacy(profile.rawConfig);

    if (legacy != null) {
      final String server = _requireString(
        _stringOrNull(legacy['add']) ?? profile.server,
        'VMess server',
      );
      final int port = _intOf(legacy['port']) ?? profile.port ?? 443;
      final String uuid =
          _requireString(_stringOrNull(legacy['id']), 'VMess uuid');

      final Map<String, String> params = <String, String>{};
      _putIfNotEmpty(params, 'type', _stringOrNull(legacy['net']));
      _putIfNotEmpty(params, 'headerType', _stringOrNull(legacy['type']));
      _putIfNotEmpty(params, 'host', _stringOrNull(legacy['host']));
      _putIfNotEmpty(params, 'path', _stringOrNull(legacy['path']));
      _putIfNotEmpty(params, 'serviceName', _stringOrNull(legacy['path']));
      _putIfNotEmpty(params, 'security', _stringOrNull(legacy['tls']));
      _putIfNotEmpty(params, 'sni', _stringOrNull(legacy['sni']));
      _putIfNotEmpty(params, 'alpn', _stringOrNull(legacy['alpn']));
      _putIfNotEmpty(params, 'fp', _stringOrNull(legacy['fp']));
      _putIfNotEmpty(params, 'insecure', _stringOrNull(legacy['allowInsecure']));

      final Map<String, dynamic> outbound = <String, dynamic>{
        'type': 'vmess',
        'tag': tag,
        'server': server,
        'server_port': port,
        'uuid': uuid,
        'security': _emptyToNull(_stringOrNull(legacy['scy'])) ?? 'auto',
        'alter_id': _intOf(legacy['aid']) ?? 0,
        'packet_encoding': 'xudp',
      };

      final Map<String, dynamic>? tls =
          _buildTls(params: params, serverAddress: server);
      if (tls != null) {
        outbound['tls'] = tls;
      }
      final Map<String, dynamic>? transport = _buildTransport(params);
      if (transport != null) {
        outbound['transport'] = transport;
      }
      return outbound;
    }

    final _ParsedUri uri = _parseUri(profile);
    final String uuid = _requireString(
      uri.userInfo.isNotEmpty ? uri.userInfo : uri.param(<String>['id']),
      'VMess uuid',
    );

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'uuid': uuid,
      'security': uri.param(<String>['encryption', 'scy']) ?? 'auto',
      'alter_id': _intOf(uri.param(<String>['alterId', 'aid'])) ?? 0,
      'packet_encoding': 'xudp',
    };

    final Map<String, dynamic>? tls =
        _buildTls(params: uri.params, serverAddress: uri.host);
    if (tls != null) {
      outbound['tls'] = tls;
    }
    final Map<String, dynamic>? transport = _buildTransport(uri.params);
    if (transport != null) {
      outbound['transport'] = transport;
    }
    return outbound;
  }

  // ---------------------------------------------------------------------------
  // Trojan
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildTrojanOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);
    final String password = _requireString(
      Uri.decodeComponent(uri.userInfo),
      'Trojan password',
    );

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'password': password,
    };

    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: true,
    );
    if (tls != null) {
      outbound['tls'] = tls;
    }
    final Map<String, dynamic>? transport = _buildTransport(uri.params);
    if (transport != null) {
      outbound['transport'] = transport;
    }
    return outbound;
  }

  // ---------------------------------------------------------------------------
  // Shadowsocks
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildShadowsocksOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile, decodeShadowsocks: true);

    String method = '';
    String password = '';

    final String userInfo = uri.userInfo;
    if (userInfo.contains(':')) {
      final int index = userInfo.indexOf(':');
      method = userInfo.substring(0, index);
      password = userInfo.substring(index + 1);
    } else if (userInfo.isNotEmpty) {
      final String decoded = _decodeBase64(userInfo);
      final int index = decoded.indexOf(':');
      if (index > 0) {
        method = decoded.substring(0, index);
        password = decoded.substring(index + 1);
      }
    }

    method = _emptyToNull(method) ??
        _requireString(uri.param(<String>['method']), 'Shadowsocks method');
    password = _emptyToNull(password) ??
        _requireString(uri.param(<String>['password']), 'Shadowsocks password');

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'method': method,
      'password': Uri.decodeComponent(password),
      'udp_over_tcp': false,
    };

    final String plugin = uri.param(<String>['plugin']) ?? '';
    if (plugin.isNotEmpty) {
      final int index = plugin.indexOf(';');
      if (index > 0) {
        outbound['plugin'] = plugin.substring(0, index);
        outbound['plugin_opts'] = plugin.substring(index + 1);
      } else {
        outbound['plugin'] = plugin;
      }
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // Hysteria2 / Hysteria
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildHysteria2Outbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'hysteria2',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
    };

    final String password = _emptyToNull(Uri.decodeComponent(uri.userInfo)) ??
        _emptyToNull(uri.param(<String>['password', 'auth'])) ??
        '';
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }

    final int? up = _intOf(uri.param(<String>['upmbps', 'up', 'up_mbps']));
    final int? down =
        _intOf(uri.param(<String>['downmbps', 'down', 'down_mbps']));
    if (up != null) {
      outbound['up_mbps'] = up;
    }
    if (down != null) {
      outbound['down_mbps'] = down;
    }

    final String obfs = uri.param(<String>['obfs']) ?? '';
    final String obfsPassword =
        uri.param(<String>['obfs-password', 'obfsParam', 'obfs_password']) ?? '';
    if (obfs.isNotEmpty && obfsPassword.isNotEmpty) {
      outbound['obfs'] = <String, dynamic>{
        'type': obfs.toLowerCase() == 'none' ? 'salamander' : obfs,
        'password': obfsPassword,
      };
    }

    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: true,
      defaultAlpn: const <String>['h3'],
    );
    if (tls != null) {
      outbound['tls'] = tls;
    }

    return outbound;
  }

  Map<String, dynamic> _buildHysteriaOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'hysteria',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'up_mbps': _intOf(uri.param(<String>['upmbps', 'up', 'up_mbps'])) ?? 50,
      'down_mbps':
          _intOf(uri.param(<String>['downmbps', 'down', 'down_mbps'])) ?? 100,
    };

    final String auth = _emptyToNull(
          uri.param(<String>['auth', 'auth_str', 'authStr', 'password']),
        ) ??
        _emptyToNull(Uri.decodeComponent(uri.userInfo)) ??
        '';
    if (auth.isNotEmpty) {
      outbound['auth_str'] = auth;
    }

    final String obfs = uri.param(<String>['obfs', 'obfsParam']) ?? '';
    if (obfs.isNotEmpty) {
      outbound['obfs'] = obfs;
    }

    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: true,
      defaultAlpn: const <String>['h3'],
    );
    if (tls != null) {
      outbound['tls'] = tls;
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // TUIC
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildTuicOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);

    String uuid = '';
    String password = '';
    final String userInfo = uri.userInfo;
    if (userInfo.contains(':')) {
      final int index = userInfo.indexOf(':');
      uuid = userInfo.substring(0, index);
      password = userInfo.substring(index + 1);
    } else {
      uuid = userInfo;
    }

    uuid = _emptyToNull(uuid) ??
        _requireString(uri.param(<String>['uuid', 'id']), 'TUIC uuid');
    password = _emptyToNull(password) ??
        _emptyToNull(uri.param(<String>['password', 'token'])) ??
        '';

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'tuic',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'uuid': Uri.decodeComponent(uuid),
      'congestion_control': uri.param(
            <String>['congestion_control', 'congestion'],
          ) ??
          'bbr',
      'udp_relay_mode':
          uri.param(<String>['udp_relay_mode', 'udp-relay-mode']) ?? 'native',
      'zero_rtt_handshake': _boolOf(
        uri.param(<String>['zero_rtt_handshake', 'reduce_rtt']),
      ),
    };

    if (password.isNotEmpty) {
      outbound['password'] = Uri.decodeComponent(password);
    }

    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: true,
      defaultAlpn: const <String>['h3'],
    );
    if (tls != null) {
      outbound['tls'] = tls;
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // WireGuard
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildWireGuardOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);

    final String privateKey = _requireString(
      _emptyToNull(uri.param(<String>['privateKey', 'private_key', 'pk'])) ??
          _emptyToNull(Uri.decodeComponent(uri.userInfo)),
      'WireGuard private_key',
    );

    final String localAddress = uri.param(
          <String>['address', 'ip', 'local_address'],
        ) ??
        '172.16.0.2/32';

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'wireguard',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'local_address': localAddress
          .split(',')
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList(),
      'private_key': privateKey,
      'mtu': _intOf(uri.param(<String>['mtu'])) ?? 1408,
    };

    final String peerPublicKey = uri.param(
          <String>['publicKey', 'peer_public_key', 'peerPublicKey', 'pbk'],
        ) ??
        '';
    if (peerPublicKey.isNotEmpty) {
      outbound['peer_public_key'] = peerPublicKey;
    }

    final String preShared =
        uri.param(<String>['presharedKey', 'pre_shared_key', 'psk']) ?? '';
    if (preShared.isNotEmpty) {
      outbound['pre_shared_key'] = preShared;
    }

    final String reserved = uri.param(<String>['reserved']) ?? '';
    if (reserved.isNotEmpty) {
      final List<int> values = reserved
          .split(',')
          .map((String e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
      if (values.length == 3) {
        outbound['reserved'] = values;
      }
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // ShadowTLS (زنجیرهٔ shadowsocks + shadowtls)
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _buildShadowTlsOutbounds(
    Profile profile,
    String tag,
  ) {
    final _ParsedUri uri = _parseUri(profile);
    const String detourTag = 'shadowtls-out';

    final Map<String, dynamic> shadowTls = <String, dynamic>{
      'type': 'shadowtls',
      'tag': detourTag,
      'server': uri.host,
      'server_port': uri.port,
      'version': _intOf(uri.param(<String>['version', 'v'])) ?? 3,
      'password': _emptyToNull(
            uri.param(<String>['shadowtlsPassword', 'stpassword']),
          ) ??
          _emptyToNull(Uri.decodeComponent(uri.userInfo)) ??
          '',
    };

    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: true,
    );
    if (tls != null) {
      shadowTls['tls'] = tls;
    }

    final String method = uri.param(<String>['method', 'encryption']) ?? '';
    final String password = uri.param(<String>['password']) ?? '';

    if (method.isEmpty || password.isEmpty) {
      // بدون لایهٔ shadowsocks، خود shadowtls به عنوان proxy استفاده می‌شود.
      shadowTls['tag'] = tag;
      return <Map<String, dynamic>>[shadowTls];
    }

    final Map<String, dynamic> shadowsocks = <String, dynamic>{
      'type': 'shadowsocks',
      'tag': tag,
      'method': method,
      'password': Uri.decodeComponent(password),
      'detour': detourTag,
      'udp_over_tcp': true,
    };

    return <Map<String, dynamic>>[shadowsocks, shadowTls];
  }

  // ---------------------------------------------------------------------------
  // AnyTLS
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildAnyTlsOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'anytls',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'password': _requireString(
        _emptyToNull(Uri.decodeComponent(uri.userInfo)) ??
            _emptyToNull(uri.param(<String>['password'])),
        'AnyTLS password',
      ),
    };

    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: true,
    );
    if (tls != null) {
      outbound['tls'] = tls;
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // NaïveProxy
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildNaiveOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);
    final List<String> credentials = _splitCredentials(uri.userInfo);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'naive',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'username': _emptyToNull(credentials.first) ??
          _emptyToNull(uri.param(<String>['username', 'user'])) ??
          '',
      'password': _emptyToNull(credentials.last) ??
          _emptyToNull(uri.param(<String>['password', 'pass'])) ??
          '',
      'network': 'tcp',
    };

    final Map<String, dynamic>? tls = _buildTls(
      params: uri.params,
      serverAddress: uri.host,
      forceEnabled: true,
    );
    if (tls != null) {
      outbound['tls'] = tls;
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // Tor (از طریق SOCKS محلی)
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildTorOutbound(Profile profile, String tag) {
    final _ParsedUri? uri = _tryParseUri(profile);

    return <String, dynamic>{
      'type': 'socks',
      'tag': tag,
      'server': uri?.host.isNotEmpty == true ? uri!.host : '127.0.0.1',
      'server_port': _intOf(uri?.param(<String>['port'])) ??
          V2rayOutboundConverter.torSocksPort,
      'version': '5',
    };
  }

  // ---------------------------------------------------------------------------
  // SSH
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildSshOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);
    final List<String> credentials = _splitCredentials(uri.userInfo);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'ssh',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'user': _emptyToNull(credentials.first) ??
          _emptyToNull(uri.param(<String>['user', 'username'])) ??
          'root',
    };

    final String password = _emptyToNull(credentials.last) ??
        _emptyToNull(uri.param(<String>['password', 'pass'])) ??
        '';
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }

    final String privateKey =
        uri.param(<String>['private_key', 'privateKey', 'pk']) ?? '';
    if (privateKey.isNotEmpty) {
      outbound['private_key'] = privateKey;
    }

    final String passphrase =
        uri.param(<String>['private_key_passphrase', 'passphrase']) ?? '';
    if (passphrase.isNotEmpty) {
      outbound['private_key_passphrase'] = passphrase;
    }

    return outbound;
  }

  // ---------------------------------------------------------------------------
  // SOCKS / HTTP
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildSocksOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);
    final List<String> credentials = _splitCredentials(uri.userInfo);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'socks',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
      'version': uri.param(<String>['version']) ?? '5',
    };

    _applyProxyCredentials(outbound, credentials, uri);
    return outbound;
  }

  Map<String, dynamic> _buildHttpOutbound(Profile profile, String tag) {
    final _ParsedUri uri = _parseUri(profile);
    final List<String> credentials = _splitCredentials(uri.userInfo);

    final Map<String, dynamic> outbound = <String, dynamic>{
      'type': 'http',
      'tag': tag,
      'server': uri.host,
      'server_port': uri.port,
    };

    _applyProxyCredentials(outbound, credentials, uri);

    final Map<String, dynamic>? tls =
        _buildTls(params: uri.params, serverAddress: uri.host);
    if (tls != null) {
      outbound['tls'] = tls;
    }

    return outbound;
  }

  void _applyProxyCredentials(
    Map<String, dynamic> outbound,
    List<String> credentials,
    _ParsedUri uri,
  ) {
    final String username = _emptyToNull(credentials.first) ??
        _emptyToNull(uri.param(<String>['username', 'user'])) ??
        '';
    final String password = _emptyToNull(credentials.last) ??
        _emptyToNull(uri.param(<String>['password', 'pass'])) ??
        '';
    if (username.isNotEmpty) {
      outbound['username'] = username;
    }
    if (password.isNotEmpty) {
      outbound['password'] = password;
    }
  }

  // ---------------------------------------------------------------------------
  // TLS / Reality مشترک
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _buildTls({
    required Map<String, String> params,
    required String serverAddress,
    bool forceEnabled = false,
    List<String>? defaultAlpn,
  }) {
    final String security =
        (_pick(params, <String>['security']) ?? '').toLowerCase();
    final String publicKey =
        _pick(params, <String>['pbk', 'publicKey', 'public_key']) ?? '';
    final bool isReality = publicKey.isNotEmpty || security == 'reality';

    final bool enabled = forceEnabled ||
        isReality ||
        security == 'tls' ||
        security == 'xtls' ||
        _boolOf(_pick(params, <String>['tls']));

    if (!enabled) {
      return null;
    }

    final Map<String, dynamic> tls = <String, dynamic>{'enabled': true};

    final String sni = _pick(params, <String>[
          'sni',
          'peer',
          'servername',
          'server_name',
        ]) ??
        _pick(params, <String>['host']) ??
        serverAddress;
    if (sni.isNotEmpty) {
      tls['server_name'] = sni.split(',').first.trim();
    }

    final String fingerprint =
        _pick(params, <String>['fp', 'fingerprint']) ?? '';

    if (isReality) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint.isEmpty ? 'chrome' : fingerprint,
      };
      tls['reality'] = <String, dynamic>{
        'enabled': true,
        'public_key': _requireString(publicKey, 'Reality public_key'),
      };
      final String shortId =
          _pick(params, <String>['sid', 'shortId', 'short_id']) ?? '';
      if (shortId.isNotEmpty) {
        (tls['reality'] as Map<String, dynamic>)['short_id'] = shortId;
      }
      // Reality با insecure و alpn سازگار نیست؛ عمداً تنظیم نمی‌شوند.
      return tls;
    }

    if (fingerprint.isNotEmpty) {
      tls['utls'] = <String, dynamic>{
        'enabled': true,
        'fingerprint': fingerprint,
      };
    }

    final List<String>? alpn = _alpnList(params) ?? defaultAlpn;
    if (alpn != null && alpn.isNotEmpty) {
      tls['alpn'] = alpn;
    }

    if (_boolOf(_pick(params, <String>[
      'insecure',
      'allowInsecure',
      'allow_insecure',
      'skip-cert-verify',
    ]))) {
      tls['insecure'] = true;
    }

    return tls;
  }

  List<String>? _alpnList(Map<String, String> params) {
    final String raw = _pick(params, <String>['alpn']) ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final List<String> items = raw
        .split(',')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    return items.isEmpty ? null : items;
  }

  // ---------------------------------------------------------------------------
  // Transport مشترک
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _buildTransport(Map<String, String> params) {
    final String network =
        (_pick(params, <String>['type', 'network', 'net']) ?? 'tcp')
            .toLowerCase();

    final String host = _pick(params, <String>['host']) ?? '';
    final String path = _pick(params, <String>['path']) ?? '';

    switch (network) {
      case 'ws':
      case 'websocket':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'ws',
        };
        String wsPath = path.isEmpty ? '/' : Uri.decodeComponent(path);
        int? earlyData = _intOf(
          _pick(params, <String>['ed', 'max_early_data', 'maxEarlyData']),
        );
        if (wsPath.contains('?ed=')) {
          final List<String> parts = wsPath.split('?ed=');
          wsPath = parts.first;
          earlyData ??= _intOf(parts.last);
        }
        transport['path'] = wsPath.isEmpty ? '/' : wsPath;
        if (host.isNotEmpty) {
          transport['headers'] = <String, dynamic>{'Host': host};
        }
        if (earlyData != null && earlyData > 0) {
          transport['max_early_data'] = earlyData;
          transport['early_data_header_name'] =
              _pick(params, <String>['eh', 'early_data_header_name']) ??
                  'Sec-WebSocket-Protocol';
        }
        return transport;

      case 'grpc':
        final String serviceName = _pick(params, <String>[
              'serviceName',
              'service_name',
              'servicename',
            ]) ??
            path;
        return <String, dynamic>{
          'type': 'grpc',
          'service_name': serviceName.isEmpty
              ? ''
              : Uri.decodeComponent(serviceName).replaceAll(RegExp(r'^/'), ''),
        };

      case 'http':
      case 'h2':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'http',
        };
        if (host.isNotEmpty) {
          transport['host'] = host
              .split(',')
              .map((String e) => e.trim())
              .where((String e) => e.isNotEmpty)
              .toList();
        }
        if (path.isNotEmpty) {
          transport['path'] = Uri.decodeComponent(path);
        }
        return transport;

      case 'httpupgrade':
        final Map<String, dynamic> transport = <String, dynamic>{
          'type': 'httpupgrade',
        };
        if (host.isNotEmpty) {
          transport['host'] = host;
        }
        transport['path'] = path.isEmpty ? '/' : Uri.decodeComponent(path);
        return transport;

      case 'quic':
        return <String, dynamic>{'type': 'quic'};

      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // پارس URI
  // ---------------------------------------------------------------------------

  _ParsedUri _parseUri(Profile profile, {bool decodeShadowsocks = false}) {
    final _ParsedUri? parsed =
        _tryParseUri(profile, decodeShadowsocks: decodeShadowsocks);
    if (parsed == null || parsed.host.isEmpty) {
      throw SingBoxConfigException(
        'Cannot parse ${profile.type.name} config: invalid share link',
      );
    }
    return parsed;
  }

  _ParsedUri? _tryParseUri(Profile profile, {bool decodeShadowsocks = false}) {
    String raw = profile.rawConfig.trim();
    if (raw.isEmpty) {
      return null;
    }

    if (decodeShadowsocks && raw.toLowerCase().startsWith('ss://')) {
      raw = _normalizeShadowsocksUri(raw);
    }

    if (!raw.contains('://')) {
      raw = '${profile.type.uriScheme}://$raw';
    }

    try {
      final Uri uri = Uri.parse(raw);
      final Map<String, String> params = <String, String>{};
      uri.queryParameters.forEach((String key, String value) {
        params[key] = value;
      });

      final int port = uri.hasPort && uri.port != 0
          ? uri.port
          : (profile.port ?? profile.type.defaultPort);

      return _ParsedUri(
        userInfo: uri.userInfo,
        host: uri.host.isNotEmpty ? uri.host : (profile.server ?? ''),
        port: port,
        params: params,
      );
    } catch (_) {
      return null;
    }
  }

  String _normalizeShadowsocksUri(String raw) {
    String body = raw.substring(5);
    String fragment = '';
    final int hashIndex = body.indexOf('#');
    if (hashIndex >= 0) {
      fragment = body.substring(hashIndex);
      body = body.substring(0, hashIndex);
    }

    if (!body.contains('@')) {
      final String decoded = _decodeBase64(body);
      if (decoded.contains('@')) {
        return 'ss://$decoded$fragment';
      }
    }
    return raw;
  }

  // ---------------------------------------------------------------------------
  // پوشش کانفیگ نهایی
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _wrap(List<Map<String, dynamic>> proxyOutbounds) {
    if (proxyOutbounds.isEmpty) {
      throw const SingBoxConfigException('No outbound generated');
    }

    return <String, dynamic>{
      'log': <String, dynamic>{
        'level': 'info',
        'timestamp': true,
      },
      'dns': _defaultDns(),
      'inbounds': <Map<String, dynamic>>[
        _tunInbound(),
      ],
      'outbounds': <Map<String, dynamic>>[
        ...proxyOutbounds,
        <String, dynamic>{
          'type': 'direct',
          'tag': 'direct',
        },
        <String, dynamic>{
          'type': 'block',
          'tag': 'block',
        },
        <String, dynamic>{
          'type': 'dns',
          'tag': 'dns-out',
        },
      ],
      'route': <String, dynamic>{
        'rules': <Map<String, dynamic>>[
          <String, dynamic>{
            'protocol': 'dns',
            'outbound': 'dns-out',
          },
        ],
        'auto_detect_interface': true,
      },
      'experimental': _experimental(),
    };
  }

  Map<String, dynamic> _tunInbound() {
    return <String, dynamic>{
      'type': 'tun',
      'tag': 'tun-in',
      'interface_name': tunInterfaceName,
      'address': <String>[tunAddress],
      'mtu': tunMtu,
      'auto_route': true,
      'strict_route': true,
      'stack': 'gvisor',
      'sniff': true,
    };
  }

  Map<String, dynamic> _defaultDns() {
    return <String, dynamic>{
      'servers': <Map<String, dynamic>>[
        <String, dynamic>{
          'tag': 'dns-remote',
          'address': dnsRemoteAddress,
          'detour': proxyTag,
        },
        <String, dynamic>{
          'tag': 'dns-direct',
          'address': dnsDirectAddress,
          'detour': 'direct',
        },
      ],
      'rules': <Map<String, dynamic>>[
        <String, dynamic>{
          'outbound': 'any',
          'server': 'dns-remote',
        },
      ],
      'strategy': 'ipv4_only',
    };
  }

  Map<String, dynamic> _experimental() {
    return <String, dynamic>{
      'clash_api': <String, dynamic>{
        'external_controller': AppConstants.clashApiListenAddress,
        'external_ui': 'ui',
        'secret': AppConstants.clashApiSecret,
        'default_mode': 'rule',
      },
    };
  }

  Map<String, dynamic> _adoptSingBoxConfig(Map<String, dynamic> json) {
    final Map<String, dynamic> config = Map<String, dynamic>.from(json);

    config['inbounds'] = <Map<String, dynamic>>[_tunInbound()];

    final Object? outbounds = config['outbounds'];
    if (outbounds is List && outbounds.isNotEmpty) {
      for (int i = 0; i < outbounds.length; i++) {
        final Object? item = outbounds[i];
        if (item is Map) {
          final Map<String, dynamic> outbound = Map<String, dynamic>.from(item);
          final String type = (outbound['type'] ?? '').toString();
          if (!_helperOutboundTypes.contains(type)) {
            outbound['tag'] = proxyTag;
            outbounds[i] = outbound;
            break;
          }
        }
      }
    }

    config['experimental'] = _experimental();
    return config;
  }

  bool _looksLikeSingBoxConfig(Map<String, dynamic> json) {
    return json.containsKey('outbounds') || json.containsKey('inbounds');
  }

  Map<String, dynamic>? _tryDecodeJsonObject(String raw) {
    try {
      final dynamic decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _tryDecodeVmessLegacy(String raw) {
    final String trimmed = raw.trim();
    if (!trimmed.toLowerCase().startsWith('vmess://')) {
      return null;
    }
    String body = trimmed.substring(8);
    final int hashIndex = body.indexOf('#');
    if (hashIndex >= 0) {
      body = body.substring(0, hashIndex);
    }
    if (body.contains('@')) {
      return null;
    }
    final String decoded = _decodeBase64(body);
    if (decoded.isEmpty) {
      return null;
    }
    return _tryDecodeJsonObject(decoded);
  }

  /// تگ خروجی را بر اساس نام پروفایل تعیین می‌کند؛
  /// اگر نام خالی/فقط فاصله باشد از تگ پیش‌فرض [proxyTag] استفاده می‌شود.
  String _safeTag(Profile profile) {
    final String name = profile.name.trim().replaceAll(RegExp(r'\s+'), '_');
    return name.isNotEmpty ? name : proxyTag;
  }

  // ---------------------------------------------------------------------------
  // ابزارهای کوچک
  // ---------------------------------------------------------------------------

  String _decodeBase64(String input) {
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/').trim();
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    try {
      return utf8.decode(base64.decode(normalized), allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  List<String> _splitCredentials(String userInfo) {
    if (userInfo.isEmpty) {
      return <String>['', ''];
    }
    final String decoded = Uri.decodeComponent(userInfo);
    final int index = decoded.indexOf(':');
    if (index < 0) {
      return <String>[decoded, ''];
    }
    return <String>[decoded.substring(0, index), decoded.substring(index + 1)];
  }

  String? _pick(Map<String, String> params, List<String> keys) {
    for (final String key in keys) {
      final String? direct = params[key];
      if (direct != null && direct.trim().isNotEmpty) {
        return direct.trim();
      }
      for (final String actual in params.keys) {
        if (actual.toLowerCase() == key.toLowerCase()) {
          final String value = params[actual]!.trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return null;
  }

  void _putIfNotEmpty(Map<String, String> target, String key, String? value) {
    if (value != null && value.trim().isNotEmpty) {
      target[key] = value.trim();
    }
  }

  String? _stringOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _emptyToNull(String? value) {
    if (value == null) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _intOf(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }

  bool _boolOf(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    final String text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes' || text == 'on';
  }

  String _requireString(String? value, String name) {
    final String? result = _emptyToNull(value);
    if (result == null) {
      throw SingBoxConfigException('$name is required');
    }
    return result;
  }
}

/// نمایش ساده‌شدهٔ لینک اشتراک.
class _ParsedUri {
  const _ParsedUri({
    required this.userInfo,
    required this.host,
    required this.port,
    required this.params,
  });

  final String userInfo;
  final String host;
  final int port;
  final Map<String, String> params;

  String? param(List<String> keys) {
    for (final String key in keys) {
      for (final String actual in params.keys) {
        if (actual.toLowerCase() == key.toLowerCase()) {
          final String value = params[actual]!.trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return null;
  }
}
