import '../../../core/storage/local_storage_service.dart';
import '../domain/profile.dart';
import 'profile_repository.dart';

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._storage);

  final LocalStorageService _storage;

  static const String _profilesKey = 'profiles';

  @override
  Future<List<Profile>> getProfiles() async {
    final List<Map<String, dynamic>> rawProfiles =
        _storage.readJsonList(_profilesKey);
    return rawProfiles.map(Profile.fromJson).toList();
  }

  @override
  Future<void> saveProfiles(List<Profile> profiles) async {
    await _storage.saveJsonList(
      _profilesKey,
      profiles.map((Profile profile) => profile.toJson()).toList(),
    );
  }

  @override
  Future<void> addProfile(Profile profile) async {
    final List<Profile> profiles = await getProfiles();
    final bool hasActive = profiles.any((Profile item) => item.isActive);
    profiles.add(profile.copyWith(isActive: hasActive ? profile.isActive : true));
    await saveProfiles(profiles);
  }

  @override
  Future<void> setActiveProfile(String profileId) async {
    final List<Profile> profiles = await getProfiles();
    final List<Profile> updated = profiles
        .map(
          (Profile profile) => profile.copyWith(
            isActive: profile.id == profileId,
          ),
        )
        .toList();
    await saveProfiles(updated);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final List<Profile> profiles = await getProfiles();
    final List<Profile> updated = profiles
        .where((Profile profile) => profile.id != profileId)
        .toList();

    if (updated.isNotEmpty && !updated.any((Profile item) => item.isActive)) {
      updated[0] = updated[0].copyWith(isActive: true);
    }

    await saveProfiles(updated);
  }
}
