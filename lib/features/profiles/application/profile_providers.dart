import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../data/local_profile_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';

final FutureProvider<LocalStorageService> localStorageProvider =
    FutureProvider<LocalStorageService>((Ref ref) async {
  return LocalStorageService.create();
});

final FutureProvider<ProfileRepository> profileRepositoryProvider =
    FutureProvider<ProfileRepository>((Ref ref) async {
  final LocalStorageService storage =
      await ref.watch(localStorageProvider.future);
  return LocalProfileRepository(storage);
});

final AsyncNotifierProvider<ProfilesNotifier, List<Profile>> profilesProvider =
    AsyncNotifierProvider<ProfilesNotifier, List<Profile>>(
  ProfilesNotifier.new,
);

class ProfilesNotifier extends AsyncNotifier<List<Profile>> {
  Future<ProfileRepository> get _repository async {
    return ref.read(profileRepositoryProvider.future);
  }

  @override
  Future<List<Profile>> build() async {
    final ProfileRepository repository = await _repository;
    return repository.getProfiles();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<Profile>>();
    state = await AsyncValue.guard<List<Profile>>(() async {
      final ProfileRepository repository = await _repository;
      return repository.getProfiles();
    });
  }

  Future<void> addProfile(Profile profile) async {
    final ProfileRepository repository = await _repository;
    await repository.addProfile(profile);
    await reload();
  }

  /// واردات انبوه: چند کانفیگ در یک عملیات ذخیره می‌شود.
  Future<void> addProfiles(List<Profile> profiles) async {
    if (profiles.isEmpty) {
      return;
    }
    final ProfileRepository repository = await _repository;
    await repository.addProfiles(profiles);
    await reload();
  }

  Future<void> updateProfile(Profile profile) async {
    final ProfileRepository repository = await _repository;
    await repository.updateProfile(profile);
    await reload();
  }

  Future<void> deleteProfile(String profileId) async {
    final ProfileRepository repository = await _repository;
    await repository.deleteProfile(profileId);
    await reload();
  }

  Future<void> deleteAll() async {
    final ProfileRepository repository = await _repository;
    await repository.deleteAll();
    await reload();
  }

  Future<void> activateProfile(String profileId) async {
    final ProfileRepository repository = await _repository;
    await repository.activateProfile(profileId);
    await reload();
  }

  /// پروفایل فعال فعلی؛ اگر هیچ‌کدام فعال نباشد، اولین مورد.
  Profile? get activeProfile {
    final List<Profile>? profiles = state.value;
    if (profiles == null || profiles.isEmpty) {
      return null;
    }
    for (final Profile profile in profiles) {
      if (profile.isActive) {
        return profile;
      }
    }
    return profiles.first;
  }
}
