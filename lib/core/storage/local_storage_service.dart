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
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    return LocalStorageService(preferences);
  }

  Future<List<Profile>> loadProfiles() async {
    final List<String> rawItems = _preferences.getStringList(_profilesKey) ?? <String>[];
    return rawItems
        .map((String item) => Profile.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    final List<String> rawItems = profiles
        .map((Profile item) => jsonEncode(item.toJson()))
        .toList();
    await _preferences.setStringList(_profilesKey, rawItems);
  }

  Future<List<Subscription>> loadSubscriptions() async {
    final List<String> rawItems =
        _preferences.getStringList(_subscriptionsKey) ?? <String>[];
    return rawItems
        .map(
          (String item) =>
              Subscription.fromJson(jsonDecode(item) as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    final List<String> rawItems = subscriptions
        .map((Subscription item) => jsonEncode(item.toJson()))
        .toList();
    await _preferences.setStringList(_subscriptionsKey, rawItems);
  }
}
