enum ProfileType {
  vmess,
  vless,
  trojan,
  shadowsocks,
  socks,
  http,
  wireguard,
  hysteria2,
  tuic,
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
}
