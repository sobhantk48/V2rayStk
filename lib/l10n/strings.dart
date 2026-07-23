import 'package:flutter/material.dart';

class Strings {
  const Strings(this.locale);
  final Locale locale;
  static Strings of(Locale locale) => Strings(locale);
  bool get fa => locale.languageCode == 'fa';
  String get appName => 'V2ray Stk';
  String get connect => fa ? 'اتصال' : 'Connect';
  String get disconnect => fa ? 'قطع اتصال' : 'Disconnect';
  String get connected => fa ? 'متصل' : 'Connected';
  String get disconnected => fa ? 'قطع' : 'Disconnected';
  String get servers => fa ? 'سرورها' : 'Servers';
  String get language => fa ? 'زبان' : 'Language';
  String get tor => fa ? 'مسیریابی Tor' : 'Tor routing';
}
