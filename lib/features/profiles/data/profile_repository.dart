import '../domain/profile.dart';

abstract class ProfileRepository {
  Future<List<Profile>> getProfiles();
  Future<void> saveProfiles(List<Profile> profiles);
  Future<void> addProfile(Profile profile);
  Future<void> setActiveProfile(String profileId);
  Future<void> deleteProfile(String profileId);
}
