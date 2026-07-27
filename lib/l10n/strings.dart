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
  String get connectionFailed =>
      fa ? 'اتصال برقرار نشد' : 'Connection failed';
}
