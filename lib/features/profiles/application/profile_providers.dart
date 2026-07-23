import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../data/local_profile_repository.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import 'profile_import_parser.dart';

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

final Provider<ProfileImportParser> profileImportParserProvider =
    Provider<ProfileImportParser>((Ref ref) {
  return ProfileImportParser();
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final ProfileRepository repository = await _repository;
      return repository.getProfiles();
    });
  }

  Future<void> importProfile(String input) async {
    final ProfileImportParser parser = ref.read(profileImportParserProvider);
    final Profile profile = parser.parse(input);
    final ProfileRepository repository = await _repository;
    await repository.addProfile(profile);
    await reload();
  }

  Future<void> activateProfile(String profileId) async {
    final ProfileRepository repository = await _repository;
    await repository.setActiveProfile(profileId);
    await reload();
  }

  Future<void> deleteProfile(String profileId) async {
    final ProfileRepository repository = await _repository;
    await repository.deleteProfile(profileId);
    await reload();
  }
}
