/// انواع پروتکل پشتیبانی‌شده در V2ray Stk.
///
/// ترتیب اعضا با لیست ۱۶ پروتکل پروژه هم‌راستاست و [ProfileType.unknown]
/// برای کانفیگ‌های ناشناخته یا JSON خام نگه داشته شده است.
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
  reality,
  unknown,
}

extension ProfileTypeX on ProfileType {
  /// برچسب کامل برای نمایش در UI.
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
        return 'NaiveProxy';
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
      case ProfileType.reality:
        return 'VLESS + XTLS Reality';
      case ProfileType.unknown:
        return 'Unknown';
    }
  }

  /// برچسب کوتاه برای چیپ‌ها و لیست‌ها.
  String get shortLabel {
    switch (this) {
      case ProfileType.shadowsocks:
        return 'SS';
      case ProfileType.hysteria2:
        return 'HY2';
      case ProfileType.hysteria:
        return 'HY';
      case ProfileType.wireguard:
        return 'WG';
      case ProfileType.shadowtls:
        return 'STLS';
      case ProfileType.naive:
        return 'NAIVE';
      case ProfileType.reality:
        return 'REALITY';
      case ProfileType.unknown:
        return 'RAW';
      default:
        return label.toUpperCase();
    }
  }

  /// نوع outbound معادل در sing-box.
  ///
  /// - `reality` روی outbound نوع `vless` با بخش TLS/Reality ساخته می‌شود.
  /// - `tor` از طریق SOCKS5 محلی کلاینت Tor مصرف می‌شود.
  /// - `naive` روی outbound نوع `http` با TLS و ALPN=h2 سوار می‌شود.
  String get singBoxType {
    switch (this) {
      case ProfileType.vless:
      case ProfileType.reality:
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
      case ProfileType.ssh:
        return 'ssh';
      case ProfileType.tor:
      case ProfileType.socks:
        return 'socks';
      case ProfileType.naive:
      case ProfileType.http:
        return 'http';
      case ProfileType.unknown:
        return '';
    }
  }

  /// طرح URI استاندارد برای import/export.
  String get uriScheme {
    switch (this) {
      case ProfileType.vless:
      case ProfileType.reality:
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
        return 'naive+https';
      case ProfileType.tor:
        return 'tor';
      case ProfileType.ssh:
        return 'ssh';
      case ProfileType.socks:
        return 'socks';
      case ProfileType.http:
        return 'http';
      case ProfileType.unknown:
        return '';
    }
  }

  /// پورت پیش‌فرض وقتی URI پورت ندارد.
  int get defaultPort {
    switch (this) {
      case ProfileType.tor:
        return 9050;
      case ProfileType.socks:
        return 1080;
      case ProfileType.http:
        return 8080;
      case ProfileType.ssh:
        return 22;
      case ProfileType.naive:
        return 443;
      case ProfileType.wireguard:
        return 51820;
      default:
        return 443;
    }
  }

  /// پروتکل‌هایی که روی UDP/QUIC کار می‌کنند (برای Kill Switch و rule ها مهم است).
  bool get isUdpBased {
    switch (this) {
      case ProfileType.hysteria:
      case ProfileType.hysteria2:
      case ProfileType.tuic:
      case ProfileType.wireguard:
        return true;
      default:
        return false;
    }
  }

  /// پروتکل‌هایی که بخش TLS دارند.
  bool get supportsTls {
    switch (this) {
      case ProfileType.vless:
      case ProfileType.reality:
      case ProfileType.vmess:
      case ProfileType.trojan:
      case ProfileType.hysteria:
      case ProfileType.hysteria2:
      case ProfileType.tuic:
      case ProfileType.shadowtls:
      case ProfileType.anytls:
      case ProfileType.naive:
        return true;
      default:
        return false;
    }
  }

  /// پروتکل‌هایی که transport (ws/grpc/http/httpupgrade) می‌پذیرند.
  bool get supportsTransport {
    switch (this) {
      case ProfileType.vless:
      case ProfileType.reality:
      case ProfileType.vmess:
      case ProfileType.trojan:
        return true;
      default:
        return false;
    }
  }

  /// در sing-box نسخه‌های جدید، WireGuard به‌جای outbound در بخش endpoints می‌نشیند.
  bool get isEndpoint => this == ProfileType.wireguard;

  /// انواع قابل انتخاب در UI (بدون unknown).
  static List<ProfileType> get selectable => ProfileType.values
      .where((ProfileType type) => type != ProfileType.unknown)
      .toList(growable: false);

  /// تبدیل نام ذخیره‌شده (JSON) به نوع، با پذیرش نام‌های مستعار.
  static ProfileType fromName(String? name) {
    switch ((name ?? '').trim().toLowerCase()) {
      case 'vless':
        return ProfileType.vless;
      case 'vmess':
        return ProfileType.vmess;
      case 'trojan':
        return ProfileType.trojan;
      case 'ss':
      case 'shadowsocks':
        return ProfileType.shadowsocks;
      case 'hy2':
      case 'hysteria2':
        return ProfileType.hysteria2;
      case 'hy':
      case 'hysteria':
        return ProfileType.hysteria;
      case 'tuic':
        return ProfileType.tuic;
      case 'wg':
      case 'wireguard':
        return ProfileType.wireguard;
      case 'shadowtls':
      case 'shadow-tls':
        return ProfileType.shadowtls;
      case 'anytls':
        return ProfileType.anytls;
      case 'naive':
      case 'naiveproxy':
        return ProfileType.naive;
      case 'tor':
        return ProfileType.tor;
      case 'ssh':
        return ProfileType.ssh;
      case 'socks':
      case 'socks4':
      case 'socks4a':
      case 'socks5':
        return ProfileType.socks;
      case 'http':
      case 'https':
        return ProfileType.http;
      case 'reality':
      case 'vless-reality':
        return ProfileType.reality;
      default:
        return ProfileType.unknown;
    }
  }

  /// تبدیل طرح URI به نوع.
  static ProfileType fromScheme(String? scheme) {
    final String value = (scheme ?? '').trim().toLowerCase();
    if (value.startsWith('naive')) {
      return ProfileType.naive;
    }
    return fromName(value);
  }
}
