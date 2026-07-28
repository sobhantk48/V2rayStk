import 'dart:convert';

import '../domain/profile.dart';
import '../domain/profile_type.dart';

/// ورودی کاربر (URI، لینک اشتراک یا JSON خام هسته) را به [Profile] تبدیل می‌کند.
///
/// پشتیبانی از ۱۶ پروتکل:
/// vless, vmess, trojan, shadowsocks, hysteria2, tuic, wireguard, shadowtls,
/// anytls, naive, tor, ssh, socks, http, hysteria, vless+reality
class ProfileImportParser {
  const ProfileImportParser();

  /// شمارنده برای تولید شناسه یکتا حتی در واردات انبوه (چند لینک در یک میلی‌ثانیه).
  static int _seq = 0;

  static final RegExp _authority = RegExp(
    r'^(?<scheme>[A-Za-z][A-Za-z0-9+.\-]*)://'
    r'(?:(?<userinfo>[^@/?#]*)@)?'
    r'(?<host>\[[^\]]+\]|[^:/?#]*)'
    r'(?::(?<port>\d+))?',
  );

  // ---------------------------------------------------------------------------
  // API عمومی
  // ---------------------------------------------------------------------------

  Profile parse(String input) {
    final String value = input.trim();

    if (value.isEmpty) {
      return _fallback(value, 'Empty Profile');
    }

    if (_looksLikeJson(value)) {
      return _parseJson(value);
    }

    final String scheme = _schemeOf(value);

    switch (scheme) {
      case 'vmess':
        return _parseVmess(value);
      case 'ss':
      case 'shadowsocks':
        return _parseShadowsocks(value);
      case '':
        return _fallback(value, 'Imported Profile');
      default:
        final ProfileType type = ProfileTypeX.fromUri(value);
        if (type == ProfileType.unknown) {
          return _fallback(value, 'Imported Profile');
        }
        return _parseUriBased(value, type);
    }
  }

  /// واردات انبوه: چند لینک در چند خط، یا بدنهٔ Base64 یک لینک اشتراک.
  List<Profile> parseMany(String input) {
    final String value = input.trim();
    if (value.isEmpty) {
      return const <Profile>[];
    }

    if (_looksLikeJson(value)) {
      return <Profile>[_parseJson(value)];
    }

    final String expanded = _maybeDecodeSubscription(value);
    final List<Profile> result = <Profile>[];

    for (final String line in expanded.split(RegExp(r'[\r\n]+'))) {
      final String candidate = line.trim();
      if (candidate.isEmpty ||
          candidate.startsWith('#') ||
          candidate.startsWith('//')) {
        continue;
      }

      final Profile profile = parse(candidate);
      final bool useless = profile.type == ProfileType.unknown &&
          (profile.server == null || profile.server!.isEmpty);
      if (useless) {
        continue;
      }
      result.add(profile);
    }

    return result;
  }

  /// بدنهٔ اشتراک اغلب Base64 است؛ اگر بود باز می‌شود.
  String _maybeDecodeSubscription(String value) {
    if (value.contains('://')) {
      return value;
    }

    final String compact = value.replaceAll(RegExp(r'\s'), '');
    if (compact.length < 8 || !RegExp(r'^[A-Za-z0-9+/_=-]+$').hasMatch(compact)) {
      return value;
    }

    try {
      final String decoded = utf8.decode(
        base64Decode(base64.normalize(compact.replaceAll('-', '+').replaceAll('_', '/'))),
        allowMalformed: true,
      );
      return decoded.contains('://') ? decoded : value;
    } catch (_) {
      return value;
    }
  }

  bool _looksLikeJson(String value) {
    if (!value.startsWith('{') || !value.endsWith('}')) {
      return false;
    }
    try {
      jsonDecode(value);
      return true;
    } on FormatException {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // JSON خام (sing-box / v2ray / Xray)
  // ---------------------------------------------------------------------------

  /// JSON خام sing-box یا v2ray/Xray. اولین outbound معتبر برای
  /// نمایش نام/سرور/پورت استخراج می‌شود و کل متن در rawConfig می‌ماند.
  Profile _parseJson(String value) {
    final Map<String, dynamic> root = jsonDecode(value) as Map<String, dynamic>;

    final List<dynamic> candidates = <dynamic>[
      ...((root['outbounds'] as List<dynamic>?) ?? const <dynamic>[]),
      // sing-box 1.13+: WireGuard زیر endpoints می‌آید.
      ...((root['endpoints'] as List<dynamic>?) ?? const <dynamic>[]),
    ];

    for (final dynamic entry in candidates) {
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final String protocol =
          (entry['type'] ?? entry['protocol'] ?? '').toString();
      final ProfileType type = _mapProtocol(protocol);

      if (type == ProfileType.unknown) {
        continue;
      }

      final String server = _readServer(entry);
      final int port = _readPort(entry);

      return Profile(
        id: _nextId(),
        name: (entry['tag'] as String?)?.trim().isNotEmpty == true
            ? entry['tag'] as String
            : protocol.toUpperCase(),
        server: server,
        port: port,
        type: type,
        rawConfig: value,
        isActive: false,
        createdAt: DateTime.now(),
      );
    }

    return _fallback(value, 'JSON Profile');
  }

  String _readServer(Map<String, dynamic> outbound) {
    final Object? direct = outbound['server'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    // WireGuard در قالب endpoints: peers[0].address
    final Object? peers = outbound['peers'];
    if (peers is List<dynamic> && peers.isNotEmpty) {
      final dynamic first = peers.first;
      if (first is Map<String, dynamic>) {
        final String address = (first['address'] as String?)?.trim() ?? '';
        if (address.isNotEmpty) {
          return address;
        }
      }
    }

    final Object? settings = outbound['settings'];
    if (settings is Map<String, dynamic>) {
      final Object? vnext = settings['vnext'];
      if (vnext is List<dynamic> && vnext.isNotEmpty) {
        final dynamic first = vnext.first;
        if (first is Map<String, dynamic>) {
          return (first['address'] as String?)?.trim() ?? '';
        }
      }

      final Object? servers = settings['servers'];
      if (servers is List<dynamic> && servers.isNotEmpty) {
        final dynamic first = servers.first;
        if (first is Map<String, dynamic>) {
          return (first['address'] as String?)?.trim() ?? '';
        }
      }
    }

    return '';
  }

  int _readPort(Map<String, dynamic> outbound) {
    final Object? direct = outbound['server_port'] ?? outbound['port'];
    final int? directPort = int.tryParse(direct?.toString() ?? '');
    if (directPort != null && directPort > 0) {
      return directPort;
    }

    final Object? peers = outbound['peers'];
    if (peers is List<dynamic> && peers.isNotEmpty) {
      final dynamic first = peers.first;
      if (first is Map<String, dynamic>) {
        final int? peerPort = int.tryParse(first['port']?.toString() ?? '');
        if (peerPort != null && peerPort > 0) {
          return peerPort;
        }
      }
    }

    final Object? settings = outbound['settings'];
    if (settings is Map<String, dynamic>) {
      for (final String key in const <String>['vnext', 'servers']) {
        final Object? list = settings[key];
        if (list is List<dynamic> && list.isNotEmpty) {
          final dynamic first = list.first;
          if (first is Map<String, dynamic>) {
            final int? port = int.tryParse(first['port']?.toString() ?? '');
            if (port != null && port > 0) {
              return port;
            }
          }
        }
      }
    }

    return 0;
  }

  /// نام پروتکل هسته را به [ProfileType] نگاشت می‌کند.
  ///
  /// ابتدا نام‌های مستعار رایج نرمال می‌شوند، سپس تصمیم به
  /// [ProfileTypeX.fromName] سپرده می‌شود تا با تغییر enum همگام بماند.
  ProfileType _mapProtocol(String protocol) {
    final String raw = protocol.trim().toLowerCase();

    const Set<String> ignored = <String>{
      '',
      'direct',
      'block',
      'dns',
      'selector',
      'urltest',
      'freedom',
      'blackhole',
      'dokodemo-door',
      'tun',
      'mixed',
      'redirect',
      'tproxy',
    };
    if (ignored.contains(raw)) {
      return ProfileType.unknown;
    }

    const Map<String, String> aliases = <String, String>{
      'ss': 'shadowsocks',
      'shadowsocksr': 'shadowsocks',
      'ssr': 'shadowsocks',
      'hy': 'hysteria',
      'hy2': 'hysteria2',
      'socks4': 'socks',
      'socks4a': 'socks',
      'socks5': 'socks',
      'https': 'http',
      'wg': 'wireguard',
      'nordlynx': 'wireguard',
      'naiveproxy': 'naive',
      'naive+https': 'naive',
      'shadow-tls': 'shadowtls',
      'any-tls': 'anytls',
    };

    return ProfileTypeX.fromName(aliases[raw] ?? raw);
  }

  // ---------------------------------------------------------------------------
  // URI ها
  // ---------------------------------------------------------------------------

  /// VMess دو فرمت دارد: Base64 از JSON (فرمت v2rayN) و URI استاندارد.
  Profile _parseVmess(String input) {
    final String payload = input.substring(input.indexOf('://') + 3);
    final String body = payload.split('#').first.split('?').first;

    try {
      final Object? decoded = jsonDecode(
        utf8.decode(base64Decode(base64.normalize(
          body.replaceAll('-', '+').replaceAll('_', '/'),
        ))),
      );

      if (decoded is Map<String, dynamic>) {
        final String name = (decoded['ps'] as Object?)?.toString().trim() ?? '';
        return Profile(
          id: _nextId(),
          name: name.isEmpty ? 'VMess' : name,
          server: (decoded['add'] as Object?)?.toString().trim() ?? '',
          port: int.tryParse(decoded['port']?.toString() ?? '') ?? 0,
          type: ProfileTypeX.fromName('vmess'),
          rawConfig: input,
          isActive: false,
          createdAt: DateTime.now(),
        );
      }
    } catch (_) {
      // به فرمت URI برمی‌گردیم.
    }

    return _parseUriBased(input, ProfileTypeX.fromName('vmess'));
  }

  /// Shadowsocks: هم SIP002 (`ss://base64(method:pass)@host:port`)
  /// و هم فرمت قدیمی (`ss://base64(method:pass@host:port)`).
  Profile _parseShadowsocks(String input) {
    final ProfileType type = ProfileTypeX.fromName('shadowsocks');

    String body = input.substring(input.indexOf('://') + 3);
    String name = '';

    final int hash = body.indexOf('#');
    if (hash >= 0) {
      name = _decode(body.substring(hash + 1));
      body = body.substring(0, hash);
    }

    final int query = body.indexOf('?');
    if (query >= 0) {
      body = body.substring(0, query);
    }

    if (!body.contains('@')) {
      try {
        body = utf8.decode(base64Decode(base64.normalize(
          body.replaceAll('-', '+').replaceAll('_', '/'),
        )));
      } catch (_) {
        // همان مقدار خام می‌ماند.
      }
    }

    final int at = body.lastIndexOf('@');
    final _HostPort hostPort = _splitHostPort(at >= 0 ? body.substring(at + 1) : body);

    return Profile(
      id: _nextId(),
      name: name.isEmpty ? 'Shadowsocks' : name,
      server: hostPort.host,
      port: hostPort.port,
      type: type,
      rawConfig: input,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  /// پارسر عمومی برای بقیهٔ پروتکل‌ها؛ با regex کار می‌کند تا کاراکترهای
  /// خاص در userinfo (رمزهای Trojan/TUIC/AnyTLS) پارس را نشکنند.
  Profile _parseUriBased(String input, ProfileType type) {
    final RegExpMatch? match = _authority.firstMatch(input);

    String host = match?.namedGroup('host') ?? '';
    if (host.startsWith('[') && host.endsWith(']')) {
      host = host.substring(1, host.length - 1);
    }

    int port = int.tryParse(match?.namedGroup('port') ?? '') ?? 0;
    if (port <= 0) {
      port = _defaultPort(_schemeOf(input));
    }

    return Profile(
      id: _nextId(),
      name: _readName(input, type),
      server: host,
      port: port,
      type: type,
      rawConfig: input,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }

  /// نام نمایشی: اول fragment، بعد پارامترهای رایج، در نهایت نام پروتکل.
  String _readName(String input, ProfileType type) {
    final int hash = input.indexOf('#');
    if (hash >= 0 && hash < input.length - 1) {
      final String fragment = _decode(input.substring(hash + 1)).trim();
      if (fragment.isNotEmpty) {
        return fragment;
      }
    }

    final Map<String, String> query = _queryOf(input);
    for (final String key in const <String>['remarks', 'remark', 'name', 'tag', 'ps']) {
      final String? value = query[key];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return type.name.toUpperCase();
  }

  Map<String, String> _queryOf(String input) {
    final int hash = input.indexOf('#');
    final String withoutFragment = hash >= 0 ? input.substring(0, hash) : input;

    final int mark = withoutFragment.indexOf('?');
    if (mark < 0 || mark == withoutFragment.length - 1) {
      return const <String, String>{};
    }

    final Map<String, String> result = <String, String>{};
    for (final String pair in withoutFragment.substring(mark + 1).split('&')) {
      if (pair.isEmpty) {
        continue;
      }
      final int eq = pair.indexOf('=');
      if (eq <= 0) {
        result[_decode(pair)] = '';
      } else {
        result[_decode(pair.substring(0, eq))] = _decode(pair.substring(eq + 1));
      }
    }
    return result;
  }

  /// پورت پیش‌فرض برای لینک‌هایی که پورت ندارند (مثل `tor://` محلی).
  int _defaultPort(String scheme) {
    switch (scheme) {
      case 'tor':
        return 9050;
      case 'ssh':
        return 22;
      case 'http':
        return 80;
      case 'https':
      case 'naive':
      case 'naive+https':
        return 443;
      case 'socks':
      case 'socks5':
      case 'socks5h':
      case 'socks4':
        return 1080;
      case 'wireguard':
      case 'wg':
        return 51820;
      default:
        return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // ابزارها
  // ---------------------------------------------------------------------------

  String _schemeOf(String value) {
    final int index = value.indexOf('://');
    if (index <= 0) {
      return '';
    }
    final String scheme = value.substring(0, index).toLowerCase();
    return RegExp(r'^[a-z][a-z0-9+.\-]*$').hasMatch(scheme) ? scheme : '';
  }

  _HostPort _splitHostPort(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const _HostPort('', 0);
    }

    if (trimmed.startsWith('[')) {
      final int close = trimmed.indexOf(']');
      if (close > 0) {
        final String host = trimmed.substring(1, close);
        final String rest = trimmed.substring(close + 1);
        final int port = rest.startsWith(':')
            ? int.tryParse(rest.substring(1)) ?? 0
            : 0;
        return _HostPort(host, port);
      }
    }

    final int colon = trimmed.lastIndexOf(':');
    if (colon > 0) {
      final int? port = int.tryParse(trimmed.substring(colon + 1));
      if (port != null) {
        return _HostPort(trimmed.substring(0, colon), port);
      }
    }

    return _HostPort(trimmed, 0);
  }

  String _decode(String value) {
    try {
      return Uri.decodeComponent(value.replaceAll('+', ' '));
    } catch (_) {
      return value;
    }
  }

  String _nextId() {
    _seq = (_seq + 1) & 0xFFFF;
    return '${DateTime.now().microsecondsSinceEpoch}-$_seq';
  }

  Profile _fallback(String value, String name) {
    return Profile(
      id: _nextId(),
      name: name,
      server: '',
      port: 0,
      type: ProfileType.unknown,
      rawConfig: value,
      isActive: false,
      createdAt: DateTime.now(),
    );
  }
}

class _HostPort {
  const _HostPort(this.host, this.port);

  final String host;
  final int port;
}
