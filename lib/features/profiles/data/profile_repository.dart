import '../domain/profile.dart';

abstract class ProfileRepository {
  Future<List<Profile>> getProfiles();

  Future<void> addProfile(Profile profile);

  Future<void> addProfiles(List<Profile> profiles);

  Future<void> updateProfile(Profile profile);

  Future<void> deleteProfile(String profileId);

  Future<void> deleteAll();

  Future<void> activateProfile(String profileId);
}
