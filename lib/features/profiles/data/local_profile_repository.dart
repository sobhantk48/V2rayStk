import '../../../core/storage/local_storage_service.dart';
import '../domain/profile.dart';
import 'profile_repository.dart';

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._storage);

  static const String _profilesKey = 'profiles';

  final LocalStorageService _storage;

  @override
  Future<List<Profile>> getProfiles() async {
    final List<Map<String, dynamic>> items =
        await _storage.readJsonList(_profilesKey);

    return items.map(Profile.fromJson).toList();
  }

  @override
  Future<void> addProfile(Profile profile) async {
    final List<Profile> profiles = await getProfiles();
    profiles.add(profile);

    await _storage.saveJsonList(
      _profilesKey,
      profiles.map((Profile item) => item.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final List<Profile> profiles = await getProfiles();

    await _storage.saveJsonList(
      _profilesKey,
      profiles
          .where((Profile item) => item.id != profileId)
          .map((Profile item) => item.toJson())
          .toList(),
    );
  }

  @override
  Future<void> activateProfile(String profileId) async {
    final List<Profile> profiles = await getProfiles();

    await _storage.saveJsonList(
      _profilesKey,
      profiles
          .map(
            (Profile item) => item.copyWith(
              isActive: item.id == profileId,
            ),
          )
          .map((Profile item) => item.toJson())
          .toList(),
    );
  }
}
