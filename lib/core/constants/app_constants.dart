class AppConstants {
  static const String appName = 'V2ray Stk';

  static const String vpnChannelName = 'com.v2ray.stk/vpn';
  static const String vpnStatusChannelName = 'com.v2ray.stk/vpn_status';
  static const String logChannelName = 'com.v2ray.stk/logs';

  /// Clash API فقط روی loopback گوش می‌دهد و با secret محافظت می‌شود.
  /// اگر سمت Kotlin هم این API را صدا زدی، همین مقدار را در هدر
  /// `Authorization: Bearer <secret>` بفرست.
  static const String clashApiListenAddress = '127.0.0.1:9090';
  static const String clashApiSecret = 'stk-9f3c1a7b52e04d68';
}
