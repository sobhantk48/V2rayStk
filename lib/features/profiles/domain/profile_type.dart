enum ProfileType {
  vmess,
  vless,
  trojan,
  shadowsocks,
  socks,
  wireguard,
  unknown,
}

ProfileType parseProfileType(String value) {
  switch (value.toLowerCase()) {
    case 'vmess':
      return ProfileType.vmess;
    case 'vless':
      return ProfileType.vless;
    case 'trojan':
      return ProfileType.trojan;
    case 'shadowsocks':
      return ProfileType.shadowsocks;
    case 'socks':
      return ProfileType.socks;
    case 'wireguard':
      return ProfileType.wireguard;
    default:
      return ProfileType.unknown;
  }
}

String profileTypeToJson(ProfileType value) {
  return value.name;
}
