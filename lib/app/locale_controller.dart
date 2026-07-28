import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// زبان‌های پشتیبانی‌شده برنامه.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('fa'),
  Locale('en'),
];

/// نگه‌دارنده زبان انتخابی کاربر با ذخیره‌سازی محلی.
class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(const Locale('fa')) {
    _load();
  }

  static const String _storageKey = 'app_locale_v1';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? code = prefs.getString(_storageKey);
    if (code == null) {
      return;
    }
    if (code == 'fa' || code == 'en') {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == state.languageCode) {
      return;
    }
    state = locale;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, locale.languageCode);
  }

  bool get isFa => state.languageCode == 'fa';
}

final StateNotifierProvider<LocaleController, Locale> localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>(
  (Ref ref) => LocaleController(),
);
