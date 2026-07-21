import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _key = 'admin_password';
  static const defaultPassword = 'admin';

  static Future<String> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? defaultPassword;
  }

  static Future<bool> checkPassword(String input) async {
    final real = await getPassword();
    return input == real;
  }

  static Future<void> changePassword(String newPass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, newPass);
  }

  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, defaultPassword);
  }
}
