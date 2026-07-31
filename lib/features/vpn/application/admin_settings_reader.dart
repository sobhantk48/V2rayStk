import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../admin/domain/admin_settings.dart';

/// تنظیمات ادمین را مستقیم از حافظه می‌خواند تا مسیر اتصال VPN
/// به لایهٔ UI ادمین وابسته نباشد.
class AdminSettingsReader {
  const AdminSettingsReader();

  static const String storageKey = 'admin_settings_v1';

  static const AdminSettings defaults =
      AdminSettings(passwordHash: '', salt: '');

  Future<AdminSettings> read() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        return defaults;
      }
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return defaults;
      }
      return AdminSettings.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return defaults;
    }
  }
}
