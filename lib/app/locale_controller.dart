import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// زبان‌های پشتیبانی‌شده برنامه.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('fa'),
  Locale('en'),
];

/// تنها منبع حقیقت برای زبان برنامه.
/// هیچ provider دیگری نباید زبان را نگه دارد.
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
    if (_isSupported(code)) {
      state = Locale(code);
    }
  }

  static bool _isSupported(String code) {
    for (final Locale locale in kSupportedLocales) {
      if (locale.languageCode == code) {
        return true;
      }
    }
    return false;
  }

  Future<void> setLocale(Locale locale) async {
    await setLanguageCode(locale.languageCode);
  }

  Future<void> setLanguageCode(String code) async {
    if (!_isSupported(code) || code == state.languageCode) {
      return;
    }
    state = Locale(code);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, code);
  }

  Future<void> toggle() async {
    await setLanguageCode(isFa ? 'en' : 'fa');
  }

  bool get isFa => state.languageCode == 'fa';
}

final StateNotifierProvider<LocaleController, Locale> localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>(
  (Ref ref) => LocaleController(),
);
