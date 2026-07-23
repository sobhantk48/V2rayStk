import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/profiles/domain/profile.dart';
import '../../features/subscriptions/domain/subscription.dart';

class LocalStorageService {
  LocalStorageService(this._preferences);

  static const String _profilesKey = 'profiles';
  static const String _subscriptionsKey = 'subscriptions';

  final SharedPreferences _preferences;

  static Future<LocalStorageService> create() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return LocalStorageService(preferences);
  }

  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final List<String> rawItems = _preferences.getStringList(key) ?? <String>[];
    return rawItems
        .map(
          (String item) => jsonDecode(item) as Map<String, dynamic>,
        )
        .toList();
  }

  Future<void> saveJsonList(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final List<String> rawItems = items
        .map((Map<String, dynamic> item) => jsonEncode(item))
        .toList();
    await _preferences.setStringList(key, rawItems);
  }

  Future<List<Profile>> loadProfiles() async {
    final List<Map<String, dynamic>> items = await readJsonList(_profilesKey);
    return items.map(Profile.fromJson).toList();
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    await saveJsonList(
      _profilesKey,
      profiles.map((Profile item) => item.toJson()).toList(),
    );
  }

  Future<List<Subscription>> loadSubscriptions() async {
    final List<Map<String, dynamic>> items =
        await readJsonList(_subscriptionsKey);
    return items.map(Subscription.fromJson).toList();
  }

  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    await saveJsonList(
      _subscriptionsKey,
      subscriptions.map((Subscription item) => item.toJson()).toList(),
    );
  }
}
