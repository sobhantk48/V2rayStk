import 'package:flutter/material.dart';

class Strings {
  const Strings(this.locale);

  final Locale locale;

  static Strings of(BuildContext context) =>
      Strings(Localizations.localeOf(context));

  static Strings forLocale(Locale locale) => Strings(locale);

  bool get fa => locale.languageCode == 'fa';

  String get appName => 'V2ray Stk';
  String get connect => fa ? 'اتصال' : 'Connect';
  String get disconnect => fa ? 'قطع اتصال' : 'Disconnect';
  String get connected => fa ? 'متصل' : 'Connected';
  String get disconnected => fa ? 'قطع' : 'Disconnected';
  String get connecting => fa ? 'در حال اتصال…' : 'Connecting…';
  String get disconnecting => fa ? 'در حال قطع…' : 'Disconnecting…';
  String get servers => fa ? 'سرورها' : 'Servers';
  String get language => fa ? 'زبان' : 'Language';
  String get tor => fa ? 'مسیریابی Tor' : 'Tor routing';

  String get ping => fa ? 'پینگ' : 'Ping';
  String get duration => fa ? 'مدت اتصال' : 'Duration';
  String get download => fa ? 'دانلود' : 'Download';
  String get upload => fa ? 'آپلود' : 'Upload';
  String get location => fa ? 'موقعیت' : 'Location';
  String get unknown => fa ? 'نامشخص' : 'Unknown';
  String get totalUsage => fa ? 'مصرف کل' : 'Total usage';
  String get noProfileSelected =>
      fa ? 'هیچ پروفایلی انتخاب نشده' : 'No profile selected';
  String get connectionFailed => fa ? 'اتصال برقرار نشد' : 'Connection failed';

  // ---- عمومی ----
  String get save => fa ? 'ذخیره' : 'Save';
  String get cancel => fa ? 'لغو' : 'Cancel';
  String get back => fa ? 'بازگشت' : 'Back';
  String get login => fa ? 'ورود' : 'Login';
  String get invalidValue => fa ? 'مقدار نامعتبر' : 'Invalid value';

  // ---- پنل ادمین ----
  String get adminPanel => fa ? 'پنل ادمین' : 'Admin panel';
  String get adminLoginHint => fa
      ? 'برای دسترسی به تنظیمات، رمز ادمین را وارد کنید.'
      : 'Enter the admin password to access settings.';
  String get password => fa ? 'رمز' : 'Password';
  String get showPassword => fa ? 'نمایش رمز' : 'Show password';
  String get hidePassword => fa ? 'پنهان کردن رمز' : 'Hide password';
  String get wrongPassword => fa ? 'رمز نادرست است' : 'Wrong password';
  String get lockPanel => fa ? 'قفل کردن پنل' : 'Lock panel';
  String get changePassword => fa ? 'تغییر رمز' : 'Change password';
  String get changePasswordHint =>
      fa ? 'رمز پیش‌فرض admin است' : 'Default password is admin';
  String get currentPassword => fa ? 'رمز فعلی' : 'Current password';
  String get newPassword => fa ? 'رمز جدید' : 'New password';
  String get confirmPassword => fa ? 'تکرار رمز جدید' : 'Confirm new password';
  String get passwordMismatch =>
      fa ? 'رمزها یکسان نیستند' : 'Passwords do not match';
  String get passwordTooShort =>
      fa ? 'رمز باید حداقل ۴ نویسه باشد' : 'Password must be at least 4 chars';
  String get passwordChanged => fa ? 'رمز تغییر کرد' : 'Password changed';

  String get tabGeneral => fa ? 'عمومی' : 'General';
  String get tabNetwork => fa ? 'شبکه' : 'Network';
  String get tabSecurity => fa ? 'امنیت' : 'Security';

  String get sectionRouting => fa ? 'مسیریابی' : 'Routing';
  String get sectionPerformance => fa ? 'کارایی' : 'Performance';
  String get sectionUserPermissions =>
      fa ? 'دسترسی‌های کاربر' : 'User permissions';
  String get sectionDns => 'DNS';
  String get sectionFragment => fa ? 'فرگمنت' : 'Fragment';
  String get sectionTun => fa ? 'تانل' : 'Tunnel';
  String get sectionApi => fa ? 'API و لاگ' : 'API & logs';
  String get sectionProtection => fa ? 'حفاظت' : 'Protection';
  String get sectionFirewall => fa ? 'فایروال' : 'Firewall';
  String get sectionPassword => fa ? 'رمز عبور' : 'Password';

  String get torRouting => fa ? 'مسیریابی Tor' : 'Tor routing';
  String get torRoutingHint =>
      fa ? 'عبور ترافیک از شبکه Tor' : 'Route traffic through the Tor network';
  String get multiHop => fa ? 'مسیریابی چندهاپه' : 'Multi-hop routing';
  String get multiHopHint =>
      fa ? 'زنجیره‌کردن چند سرور' : 'Chain multiple servers';
  String get dynamicRouting => fa ? 'مسیریابی پویا' : 'Dynamic routing';
  String get autoServerSelection =>
      fa ? 'انتخاب خودکار سرور' : 'Auto server selection';
  String get liteMode => fa ? 'حالت سبک' : 'Lite mode';
  String get liteModeHint => fa
      ? 'مصرف کمتر منابع برای دستگاه‌های ضعیف'
      : 'Lower resource usage on weak devices';
  String get batteryOptimization =>
      fa ? 'بهینه‌سازی باتری' : 'Battery optimization';
  String get trafficCompression =>
      fa ? 'فشرده‌سازی ترافیک' : 'Traffic compression';
  String get lwo =>
      fa ? 'مبهم‌سازی سبک WireGuard' : 'Lightweight WG obfuscation';
  String get lwoHint => fa ? 'LWO' : 'LWO';
  String get nordLynx => fa ? 'پشتیبانی NordLynx' : 'NordLynx support';
  String get sniffEnabled => 'شناسایی پروتکل (Sniffing)';
  String get sniffHint => 'تشخیص دامنه واقعی از ترافیک (بهبود مسیریابی)';
  String get muxEnabled => 'چندتایی‌سازی (Mux)';
  String get muxHint => 'ارسال چند جریان روی یک اتصال';
  String get muxType => 'پروتکل Mux';
  String get muxConcurrency => 'بیشینه جریان همزمان';
  String get sniSpoofEnabled => 'جعل SNI';
  String get sniSpoofHint => 'ارسال SNI جعلی در دست‌دهی TLS';
  String get utlsFingerprint => 'اثر انگشت uTLS';
  String get utlsFingerprintHint => 'تقلید اثر انگشت TLS مرورگر واقعی (مثلاً chrome)';

  String get sniffHint =>
      fa ? 'تشخیص خودکار پروتکل' : 'Automatic protocol detection';
  String get muxHint =>
      fa ? 'چندپلکسینگ برای کاهش Latency' : 'Multiplexing to reduce latency';
  String get sniSpoofHint =>
      fa ? 'جعل Server Name Indication' : 'Spoof Server Name Indication';
  String get utlsFingerprintHint =>
      fa ? 'شبیه‌سازی TLS مرورگرها' : 'Simulate browser TLS';

  String get allowUserEdit =>
      fa ? 'اجازه ویرایش پروفایل به کاربر' : 'Allow user to edit profiles';
  String get allowUserImport =>
      fa ? 'اجازه واردات به کاربر' : 'Allow user to import';
  String get allowUserGroups =>
      fa ? 'اجازه مدیریت گروه به کاربر' : 'Allow user group management';
  String get hapticFeedback => fa ? 'بازخورد لمسی' : 'Haptic feedback';

  String get dnsMode => fa ? 'حالت DNS' : 'DNS mode';
  String get dnsServer => fa ? 'سرور DNS' : 'DNS server';
  String get splitDns => fa ? 'DNS تفکیکی' : 'Split DNS';
  String get splitDnsHint => fa
      ? 'DNS جداگانه برای دامنه‌های داخلی و خارجی'
      : 'Separate DNS for local and remote domains';
  String get splitDnsDirectDomains =>
      fa ? 'دامنه‌های مستقیم (Split DNS)' : 'Direct domains (Split DNS)';
  String get splitDnsLocalServer =>
      fa ? 'سرور DNS محلی' : 'Local DNS server';
  String get splitDnsDirectDomainsHint => fa
      ? 'با کاما جدا کنید، مثال: ir,digikala.com'
      : 'Comma separated, e.g. ir,digikala.com';
  String get splitDnsLocalServerHint => fa
      ? 'مثال: 8.8.8.8 یا https://dns.google/dns-query'
      : 'e.g. 8.8.8.8 or https://dns.google/dns-query';

  String get fragmentEnabled => fa ? 'فعال‌سازی فرگمنت' : 'Enable fragment';
  String get fragmentPackets => fa ? 'بسته‌ها' : 'Packets';
  String get fragmentLength => fa ? 'طول' : 'Length';
  String get fragmentInterval => fa ? 'فاصله' : 'Interval';

  String get mtu => 'MTU';
  String get autoConnectOnNetworkChange =>
      fa ? 'اتصال خودکار با تغییر شبکه' : 'Auto-connect on network change';
  String get alwaysOnVpn => fa ? 'VPN همیشه‌روشن' : 'Always-on VPN';

  String get clashApi => fa ? 'Clash API' : 'Clash API';
  String get clashApiHint =>
      fa ? 'آمار پیشرفته و مدیریت گروه‌ها' : 'Advanced stats and group control';
  String get clashApiPort => fa ? 'پورت Clash API' : 'Clash API port';
  String get logLevel => fa ? 'سطح لاگ' : 'Log level';

  String get killSwitch => fa ? 'کیل سوییچ' : 'Kill switch';
  String get killSwitchHint => fa
      ? 'قطع کامل اینترنت هنگام افتادن VPN'
      : 'Block all traffic if the VPN drops';
  String get anonymousMode => fa ? 'حالت ناشناس' : 'Anonymous mode';
  String get anonymousModeHint =>
      fa ? 'غیرفعال‌سازی لاگ و آمار محلی' : 'Disable local logs and stats';
  String get biometricLock => fa ? 'قفل بیومتریک' : 'Biometric lock';
  String get firewall => fa ? 'فایروال داخلی' : 'Built-in firewall';
  String get blockAds => fa ? 'مسدودسازی تبلیغات' : 'Block ads';
  String get blockTrackers => fa ? 'مسدودسازی ترکرها' : 'Block trackers';
  String get blockTorrent => fa ? 'مسدودسازی تورنت' : 'Block torrent';

  // ---- اسکنر ----
  String get scanQr => fa ? 'اسکن QR' : 'Scan QR';
  String get scanQrHint => fa
      ? 'کد QR کانفیگ یا لینک اشتراک را در کادر قرار دهید'
      : 'Place the config or subscription QR inside the frame';
  String get torch => fa ? 'چراغ' : 'Torch';
  String get switchCamera => fa ? 'تغییر دوربین' : 'Switch camera';
  String get cameraPermissionDenied =>
      fa ? 'دسترسی به دوربین داده نشده است' : 'Camera permission denied';
  String get cameraError => fa ? 'خطای دوربین' : 'Camera error';
  String get invalidQr => fa ? 'QR نامعتبر است' : 'Invalid QR code';
  String get importedFromQr => fa ? 'از QR وارد شد' : 'Imported from QR';

  String get sniffing => fa ? 'شناسایی پروتکل (Sniffing)' : 'Protocol Sniffing';
  String get sniffOverrideDestination => fa ? 'بازنویسی مقصد با دامنهٔ شناسایی‌شده' : 'Override Destination';
  String get sniffTimeout => fa ? 'زمان‌ انتظار شناسایی' : 'Sniff Timeout';
  String get muxTitle => fa ? 'Mux (چندگانه‌سازی)' : 'Multiplexing (Mux)';
  String get muxProtocol => fa ? 'پروتکل Mux' : 'Mux Protocol';
  String get muxMaxStreams => fa ? 'حداکثر جریان همزمان' : 'Max Streams';
  String get muxPadding => fa ? 'پدینگ Mux' : 'Mux Padding';
  String get sniSpoofing => fa ? 'جعل SNI' : 'SNI Spoofing';
  String get sniSpoofValue => fa ? 'مقدار SNI جعلی' : 'Spoofed SNI';
}
