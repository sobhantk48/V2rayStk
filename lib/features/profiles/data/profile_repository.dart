import '../domain/profile.dart';

abstract class ProfileRepository {
  Future<List<Profile>> getProfiles();

  Future<void> addProfile(Profile profile);

  Future<void> deleteProfile(String profileId);

  Future<void> activateProfile(String profileId);
}
