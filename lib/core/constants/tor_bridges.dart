/// بریج‌های Tor برای نمایش در UI و ارسال به لایه native.
///
/// نکته: منبع حقیقت (source of truth) برای اتصال واقعی،
/// فایل TorDaemon.kt است. این کلاس فقط برای نمایش و انتخاب کاربر است.
class TorBridges {
  const TorBridges._();

  /// Snowflake روی بروکر فعلی (cdn77)
  static const String snowflakeCdn77 =
      'snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
      'fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 '
      'url=https://1098762253.rsc.cdn77.org/ '
      'fronts=www.cdn77.com,www.phpmyadmin.net '
      'ice=stun:stun.l.google.com:19302,stun:stun.antisip.com:3478,'
      'stun:stun.bluesip.net:3478,stun:stun.dus.net:3478,'
      'stun:stun.epygi.com:3478,stun:stun.sonetel.com:3478,'
      'stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,'
      'stun:stun.voys.nl:3478 '
      'utls-imitate=hellorandomizedalpn';

  /// Snowflake روی بروکر قدیمی (fastly) - به عنوان fallback
  static const String snowflakeFastly =
      'snowflake 192.0.2.4:80 8838024498816A039FCBBAB14E6F40A0843051FA '
      'fingerprint=8838024498816A039FCBBAB14E6F40A0843051FA '
      'url=https://snowflake-broker.torproject.net.global.prod.fastly.net/ '
      'front=foursquare.com '
      'ice=stun:stun.l.google.com:19302,stun:stun.voip.blackberry.com:3478 '
      'utls-imitate=hellorandomizedalpn';

  static const String obfs4_1 =
      'obfs4 193.11.166.194:27015 '
      '2D82C2E354D531A68469ADF7F878FA6060C6BACA '
      'cert=4TLQPJrTSaDffMK7Nbao6LC7G9OW/NHkUwIdjLSS3KYf0Nv4/nQiiI8dY2TcsQx01NniOg '
      'iat-mode=0';

  static const String obfs4_2 =
      'obfs4 209.148.46.65:443 '
      '74FAD13168806246602538555B5521A0383A1875 '
      'cert=ssH+9rP8dG2NLDN2XuFw63hIO/9MNNinLmxQDpVa+7kTOa9/m+tGWT1SmSYpQ9uTBGa6Hw '
      'iat-mode=0';

  /// نگه‌داشتن نام قدیمی برای سازگاری با کدهای موجود
  static const String snowflake = snowflakeCdn77;

  /// لیست همه پروفایل‌ها برای نمایش در UI
  static List<Map<String, String>> getAllProfiles() {
    return const [
      {
        'name': 'Snowflake (cdn77)',
        'config': snowflakeCdn77,
        'type': 'snowflake',
      },
      {
        'name': 'Snowflake (fastly)',
        'config': snowflakeFastly,
        'type': 'snowflake',
      },
      {
        'name': 'obfs4 - 1',
        'config': obfs4_1,
        'type': 'obfs4',
      },
      {
        'name': 'obfs4 - 2',
        'config': obfs4_2,
        'type': 'obfs4',
      },
    ];
  }
}
