import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  LocalStorageService(this._preferences);

  final SharedPreferences _preferences;

  static Future<LocalStorageService> create() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    return LocalStorageService(preferences);
  }

  Future<void> saveJsonList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    final String encoded = jsonEncode(value);
    await _preferences.setString(key, encoded);
  }

  List<Map<String, dynamic>> readJsonList(String key) {
    final String? raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (dynamic item) => Map<String, dynamic>.from(item as Map),
        )
        .toList();
  }
}
