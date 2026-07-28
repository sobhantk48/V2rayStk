enum ProfileType {
  vmess,
  vless,
  reality,
  trojan,
  shadowsocks,
  socks,
  http,
  wireguard,
  hysteria,
  hysteria2,
  tuic,
  shadowtls,
  anytls,
  naive,
  tor,
  ssh,
  unknown,
}

extension ProfileTypeX on ProfileType {
  static ProfileType fromName(String? value) {
    for (final ProfileType type in ProfileType.values) {
      if (type.name == value) {
        return type;
      }
    }

    return ProfileType.unknown;
  }

  String get label {
    switch (this) {
      case ProfileType.vmess:
        return 'VMess';
      case ProfileType.vless:
        return 'VLESS';
      case ProfileType.reality:
        return 'VLESS Reality';
      case ProfileType.trojan:
        return 'Trojan';
      case ProfileType.shadowsocks:
        return 'Shadowsocks';
      case ProfileType.socks:
        return 'SOCKS';
      case ProfileType.http:
        return 'HTTP';
      case ProfileType.wireguard:
        return 'WireGuard';
      case ProfileType.hysteria:
        return 'Hysteria';
      case ProfileType.hysteria2:
        return 'Hysteria2';
      case ProfileType.tuic:
        return 'TUIC';
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
      case ProfileType.unknown:
        return 'Unknown';
    }
  }

  bool get isSupported => this != ProfileType.unknown;
}
