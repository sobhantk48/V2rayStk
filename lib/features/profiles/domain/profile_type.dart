/// انواع پروتکل‌های پشتیبانی‌شده در V2ray Stk.
///
/// ترتیب مقادیر مطابق لیست رسمی ۱۶ پروتکل پروژه است و `unknown`
/// همیشه آخرین مقدار می‌ماند تا در UI به‌عنوان حالت پیش‌فرض استفاده شود.
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
  /// تبدیل نام ذخیره‌شده (یا اسکیم لینک) به مقدار enum.
  ///
  /// هم نام دقیق enum و هم نام‌های مستعار رایج در لینک‌های اشتراک
  /// (مثل `ss`, `hy2`, `wg`) پذیرفته می‌شوند.
  static ProfileType fromName(String? value) {
    if (value == null) {
      return ProfileType.unknown;
    }

    final String key = value.trim().toLowerCase();
    if (key.isEmpty) {
      return ProfileType.unknown;
    }

    for (final ProfileType type in ProfileType.values) {
      if (type.name == key) {
        return type;
      }
    }

    return _aliases[key] ?? ProfileType.unknown;
  }

  /// نام قابل نمایش برای کاربر (در کارت پروفایل و فیلترها).
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
        return 'VLESS + Reality';
      case ProfileType.unknown:
        return 'Unknown';
    }
  }

  /// هم‌نام `label` برای سازگاری با کدهایی که `displayName` صدا می‌زنند.
  String get displayName => label;

  /// نوع outbound متناظر در sing-box.
  ///
  /// نکته: `reality` در sing-box نوع جدا ندارد و به‌صورت `vless`
  /// با بلوک `tls.reality` تولید می‌شود. `naive` هم outbound اختصاصی
  /// ندارد و روی `http` با TLS نگاشت می‌شود.
  String get singBoxType {
    switch (this) {
      case ProfileType.reality:
      case ProfileType.vless:
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
      case ProfileType.tor:
        return 'tor';
      case ProfileType.ssh:
        return 'ssh';
      case ProfileType.socks:
        return 'socks';
      case ProfileType.naive:
      case ProfileType.http:
        return 'http';
      case ProfileType.unknown:
        return 'direct';
    }
  }

  /// پورت پیش‌فرض وقتی لینک ورودی پورت ندارد.
  int get defaultPort {
    switch (this) {
      case ProfileType.vless:
      case ProfileType.reality:
      case ProfileType.trojan:
      case ProfileType.anytls:
      case ProfileType.naive:
      case ProfileType.shadowtls:
        return 443;
      case ProfileType.vmess:
        return 80;
      case ProfileType.shadowsocks:
        return 8388;
      case ProfileType.hysteria2:
      case ProfileType.hysteria:
      case ProfileType.tuic:
        return 443;
      case ProfileType.wireguard:
        return 51820;
      case ProfileType.tor:
        return 9050;
      case ProfileType.ssh:
        return 22;
      case ProfileType.socks:
        return 1080;
      case ProfileType.http:
        return 8080;
      case ProfileType.unknown:
        return 443;
    }
  }

  /// آیا این پروتکل روی UDP/QUIC کار می‌کند (برای هشدار و تست سرعت).
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

  /// اسکیم لینک برای صادر کردن (export) پروفایل.
  String get uriScheme {
    switch (this) {
      case ProfileType.reality:
        return 'vless';
      case ProfileType.shadowsocks:
        return 'ss';
      case ProfileType.hysteria2:
        return 'hy2';
      case ProfileType.naive:
        return 'naive+https';
      case ProfileType.unknown:
        return 'unknown';
      default:
        return name;
    }
  }

  static const Map<String, ProfileType> _aliases = <String, ProfileType>{
    'ss': ProfileType.shadowsocks,
    'shadow-socks': ProfileType.shadowsocks,
    'ssr': ProfileType.shadowsocks,
    'hy': ProfileType.hysteria,
    'hysteria1': ProfileType.hysteria,
    'hy2': ProfileType.hysteria2,
    'hysteria-2': ProfileType.hysteria2,
    'wg': ProfileType.wireguard,
    'wireguard-go': ProfileType.wireguard,
    'nordlynx': ProfileType.wireguard,
    'stls': ProfileType.shadowtls,
    'shadow-tls': ProfileType.shadowtls,
    'any-tls': ProfileType.anytls,
    'naiveproxy': ProfileType.naive,
    'naive+https': ProfileType.naive,
    'socks5': ProfileType.socks,
    'socks4': ProfileType.socks,
    'https': ProfileType.http,
    'vless-reality': ProfileType.reality,
    'xtls': ProfileType.reality,
    'xtls-reality': ProfileType.reality,
    'v2ray': ProfileType.vmess,
  };
}
