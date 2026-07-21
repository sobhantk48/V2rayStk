import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _key = 'admin_password';
  static const _default = 'admin';

  static Future<bool> checkPassword(String input) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key) ?? _default;
    return input == saved;
  }

  static Future<void> changePassword(String newPass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newPass);
  }
}
