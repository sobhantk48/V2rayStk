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

  Future<void> _persist(List<Profile> profiles) async {
    await _storage.saveJsonList(
      _profilesKey,
      profiles.map((Profile item) => item.toJson()).toList(),
    );
  }

  @override
  Future<void> addProfile(Profile profile) async {
    final List<Profile> profiles = await getProfiles();
    profiles.add(profile);
    await _persist(profiles);
  }

  @override
  Future<void> addProfiles(List<Profile> newProfiles) async {
    if (newProfiles.isEmpty) {
      return;
    }

    final List<Profile> profiles = await getProfiles();
    profiles.addAll(newProfiles);
    await _persist(profiles);
  }

  @override
  Future<void> updateProfile(Profile profile) async {
    final List<Profile> profiles = await getProfiles();

    await _persist(
      profiles
          .map((Profile item) => item.id == profile.id ? profile : item)
          .toList(),
    );
  }

  @override
  Future<void> updateProfiles(List<Profile> updated) async {
    if (updated.isEmpty) {
      return;
    }

    final List<Profile> profiles = await getProfiles();

    // آخرین نسخه برای هر id برنده است.
    final Map<String, Profile> patches = <String, Profile>{
      for (final Profile item in updated) item.id: item,
    };

    bool changed = false;

    final List<Profile> merged = profiles.map((Profile item) {
      final Profile? patch = patches[item.id];

      if (patch == null || patch == item) {
        return item;
      }

      changed = true;
      return patch;
    }).toList();

    // اگر هیچ تفاوت واقعی نبود، از نوشتن روی دیسک صرف‌نظر می‌کنیم.
    if (!changed) {
      return;
    }

    await _persist(merged);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final List<Profile> profiles = await getProfiles();

    await _persist(
      profiles.where((Profile item) => item.id != profileId).toList(),
    );
  }

  @override
  Future<void> deleteAll() async {
    await _persist(const <Profile>[]);
  }

  @override
  Future<void> activateProfile(String profileId) async {
    final List<Profile> profiles = await getProfiles();

    await _persist(
      profiles
          .map(
            (Profile item) => item.copyWith(
              isActive: item.id == profileId,
            ),
          )
          .toList(),
    );
  }
}
