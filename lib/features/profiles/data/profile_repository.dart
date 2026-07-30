import '../domain/profile.dart';

abstract class ProfileRepository {
  Future<List<Profile>> getProfiles();

  Future<void> addProfile(Profile profile);

  Future<void> addProfiles(List<Profile> profiles);

  Future<void> updateProfile(Profile profile);

  /// به‌روزرسانی دسته‌جمعی: فقط یک بار خواندن و یک بار نوشتن روی دیسک.
  /// پروفایل‌هایی که id آن‌ها در لیست موجود نباشد، نادیده گرفته می‌شوند.
  Future<void> updateProfiles(List<Profile> profiles);

  Future<void> deleteProfile(String profileId);

  Future<void> deleteAll();

  Future<void> activateProfile(String profileId);
}
