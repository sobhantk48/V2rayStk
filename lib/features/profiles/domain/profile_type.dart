/// انواع پروتکل پشتیبانی‌شده در V2ray Stk (۱۶ پروتکل + unknown).
///
/// ترتیب اعضا همان ترتیب لیست رسمی پروژه است تا در UI هم قابل استفاده باشد.
enum ProfileType {
  vless,
  vmess,
  trojan,
  shadowsocks,
  hysteria2,
  tuic,
  wireguard,
  shadowtls,
  anytls,
  naive,
  tor,
  ssh,
  socks,
  http,
  hysteria,
  vlessReality,
  unknown,
}

extension ProfileTypeX on ProfileType {
  /// نام‌های جایگزینی که در لینک‌ها و کانفیگ‌های واقعی دیده می‌شوند.
  /// کلیدها باید نرمال‌شده باشند (حروف کوچک، بدون فاصله/خط‌تیره/آندرلاین/جمع).
  static const Map<String, ProfileType> _aliases = <String, ProfileType>{
    'ss': ProfileType.shadowsocks,
    'shadowsocks2022': ProfileType.shadowsocks,
    'hy2': ProfileType.hysteria2,
    'hysteria2': ProfileType.hysteria2,
    'hy': ProfileType.hysteria,
    'hysteria1': ProfileType.hysteria,
    'tuicv5': ProfileType.tuic,
    'wg': ProfileType.wireguard,
    'nordlynx': ProfileType.wireguard,
    'stls': ProfileType.shadowtls,
    'naiveproxy': ProfileType.naive,
    'naivehttps': ProfileType.naive,
    'torsocks': ProfileType.tor,
    'socks5': ProfileType.socks,
    'socks4': ProfileType.socks,
    'socks4a': ProfileType.socks,
    'https': ProfileType.http,
    'reality': ProfileType.vlessReality,
    'vlessxtlsreality': ProfileType.vlessReality,
    'vlessxtls': ProfileType.vlessReality,
    'xtls': ProfileType.vlessReality,
  };

  static String _normalize(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_+.]'), '');
  }

  /// از نام ذخیره‌شده در JSON یا دیتابیس، نوع را برمی‌گرداند.
  static ProfileType fromName(String? value) {
    final String key = _normalize(value);
    if (key.isEmpty) {
      return ProfileType.unknown;
    }

    for (final ProfileType type in ProfileType.values) {
      if (_normalize(type.name) == key) {
        return type;
      }
    }

    return _aliases[key] ?? ProfileType.unknown;
  }

  /// از یک لینک اشتراک (مثل `vless://...` یا `hy2://...`) نوع را حدس می‌زند.
  static ProfileType fromUri(String? uri) {
    final String raw = (uri ?? '').trim();
    if (raw.isEmpty) {
      return ProfileType.unknown;
    }

    final int separator = raw.indexOf('://');
    final String scheme =
        separator > 0 ? raw.substring(0, separator) : raw.split(':').first;

    return fromName(scheme);
  }

  /// نوع outbound معادل در هسته sing-box.
  ///
  /// نکته: sing-box برای NaïveProxy و Tor نوع outbound اختصاصی ندارد؛
  /// naive روی `http` با TLS نگاشت می‌شود و tor از طریق `socks`
  /// به کلاینت محلی Tor وصل می‌شود.
  String get singBoxType {
    switch (this) {
      case ProfileType.vless:
      case ProfileType.vlessReality:
        return 'vless';
      case ProfileType.vmess:
        return 'vmess';
      case ProfileType.trojan:
        return 'trojan';
      case ProfileType.shadowsocks:
        return 'shadowsocks';
      case ProfileType.hysteria2:
        return 'hysteria2';
      case ProfileType.hysteria:
        return 'hysteria';
      case ProfileType.tuic:
        return 'tuic';
      case ProfileType.wireguard:
        return 'wireguard';
      case ProfileType.shadowtls:
        return 'shadowtls';
      case ProfileType.anytls:
        return 'anytls';
      case ProfileType.naive:
        return 'http';
      case ProfileType.tor:
      case ProfileType.socks:
        return 'socks';
      case ProfileType.http:
        return 'http';
      case ProfileType.ssh:
        return 'ssh';
      case ProfileType.unknown:
        return '';
    }
  }

  /// اسکیم پیشنهادی برای ساخت لینک اشتراک.
  String get uriScheme {
    switch (this) {
      case ProfileType.vless:
      case ProfileType.vlessReality:
        return 'vless';
      case ProfileType.vmess:
        return 'vmess';
      case ProfileType.trojan:
        return 'trojan';
      case ProfileType.shadowsocks:
        return 'ss';
      case ProfileType.hysteria2:
        return 'hysteria2';
      case ProfileType.hysteria:
        return 'hysteria';
      case ProfileType.tuic:
        return 'tuic';
      case ProfileType.wireguard:
        return 'wireguard';
      case ProfileType.shadowtls:
        return 'shadowtls';
      case ProfileType.anytls:
        return 'anytls';
      case ProfileType.naive:
        return 'naive';
      case ProfileType.tor:
        return 'tor';
      case ProfileType.ssh:
        return 'ssh';
      case ProfileType.socks:
        return 'socks5';
      case ProfileType.http:
        return 'http';
      case ProfileType.unknown:
        return '';
    }
  }

  /// برچسب انگلیسی برای نمایش در UI.
  String get label {
    switch (this) {
      case ProfileType.vless:
        return 'VLESS';
      case ProfileType.vmess:
        return 'VMess';
      case ProfileType.trojan:
        return 'Trojan';
      case ProfileType.shadowsocks:
        return 'Shadowsocks';
      case ProfileType.hysteria2:
        return 'Hysteria2';
      case ProfileType.tuic:
        return 'TUIC';
      case ProfileType.wireguard:
        return 'WireGuard';
      case ProfileType.shadowtls:
        return 'ShadowTLS';
      case ProfileType.anytls:
        return 'AnyTLS';
      case ProfileType.naive:
        return 'NaïveProxy';
      case ProfileType.tor:
        return 'Tor';
      case ProfileType.ssh:
        return 'SSH';
      case ProfileType.socks:
        return 'SOCKS';
      case ProfileType.http:
        return 'HTTP';
      case ProfileType.hysteria:
        return 'Hysteria';
      case ProfileType.vlessReality:
        return 'VLESS + XTLS Reality';
      case ProfileType.unknown:
        return 'Unknown';
    }
  }

  /// برچسب فارسی برای نمایش در UI دوزبانه.
  String get labelFa {
    switch (this) {
      case ProfileType.tor:
        return 'تور';
      case ProfileType.unknown:
        return 'ناشناس';
      default:
        return label;
    }
  }

  /// پروتکل‌هایی که بدون TLS معنا ندارند.
  bool get requiresTls {
    switch (this) {
      case ProfileType.trojan:
      case ProfileType.hysteria2:
      case ProfileType.hysteria:
      case ProfileType.tuic:
      case ProfileType.shadowtls:
      case ProfileType.anytls:
      case ProfileType.naive:
      case ProfileType.vlessReality:
        return true;
      default:
        return false;
    }
  }

  /// پروتکل‌های مبتنی بر QUIC/UDP که در شبکه‌های پرافت‌وخیز بهتر عمل می‌کنند.
  bool get isQuicBased {
    switch (this) {
      case ProfileType.hysteria:
      case ProfileType.hysteria2:
      case ProfileType.tuic:
        return true;
      default:
        return false;
    }
  }

  /// پروتکل‌هایی که ترافیک UDP را عبور می‌دهند (مهم برای بازی و تماس تصویری).
  bool get supportsUdp {
    switch (this) {
      case ProfileType.http:
      case ProfileType.naive:
      case ProfileType.tor:
      case ProfileType.shadowtls:
        return false;
      default:
        return true;
    }
  }

  /// آیا این پروتکل می‌تواند در زنجیره‌ی Multi-Hop به‌عنوان hop میانی بنشیند.
  bool get supportsMultiHop {
    switch (this) {
      case ProfileType.wireguard:
      case ProfileType.unknown:
        return false;
      default:
        return true;
    }
  }

  /// آیا برای این پروتکل به کلاینت محلی کمکی نیاز است (فعلاً فقط Tor).
  bool get needsLocalHelper => this == ProfileType.tor;

  /// همه‌ی انواع قابل انتخاب توسط کاربر (بدون unknown).
  static List<ProfileType> get selectable => ProfileType.values
      .where((ProfileType type) => type != ProfileType.unknown)
      .toList(growable: false);
}
