import '../../../core/storage/local_storage_service.dart';
import '../domain/profile.dart';
import 'profile_repository.dart';

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._storage);

  static const String _profilesKey = 'profiles';

  final LocalStorageService _storage;

  /// اثرانگشت یکتای یک پروفایل برای تشخیص تکراری بودن.
  /// id عمداً لحاظ نمی‌شود؛ چون هر بار واردات یک id تازه می‌سازد.
  static String fingerprintOf(Profile profile) {
    final Map<String, dynamic> json = profile.toJson();

    String pick(List<String> keys) {
      for (final String key in keys) {
        final dynamic value = json[key];
        if (value != null) {
          final String text = value.toString().trim();
          if (text.isNotEmpty && text != 'null') {
            return text.toLowerCase();
          }
        }
      }
      return '';
    }

    final String type = pick(<String>['type', 'protocol']);
    final String host = pick(<String>['server', 'address', 'host', 'serverAddress']);
    final String port = pick(<String>['port', 'serverPort']);
    final String secret = pick(<String>[
      'uuid',
      'id',
      'password',
      'privateKey',
      'psk',
      'token',
    ]);
    final String extra = pick(<String>['path', 'serviceName', 'publicKey']);

    final String base = '$type|$host|$port|$secret|$extra';

    // اگر هیچ فیلد معناداری نبود، به لینک خام یا کل JSON برمی‌گردیم.
    if (base.replaceAll('|', '').isEmpty) {
      final String raw = pick(<String>['rawLink', 'link', 'uri', 'config']);
      if (raw.isNotEmpty) {
        return raw;
      }
      return json.toString();
    }

    return base;
  }

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

    final Set<String> seen = profiles.map(fingerprintOf).toSet();
    if (seen.contains(fingerprintOf(profile))) {
      // تکراری است؛ چیزی اضافه نمی‌کنیم.
      return;
    }

    profiles.add(profile);
    await _persist(profiles);
  }

  @override
  Future<void> addProfiles(List<Profile> newProfiles) async {
    if (newProfiles.isEmpty) {
      return;
    }

    final List<Profile> profiles = await getProfiles();
    final Set<String> seen = profiles.map(fingerprintOf).toSet();

    final List<Profile> accepted = <Profile>[];
    for (final Profile item in newProfiles) {
      final String key = fingerprintOf(item);
      if (seen.add(key)) {
        accepted.add(item);
      }
    }

    if (accepted.isEmpty) {
      return;
    }

    profiles.addAll(accepted);
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

  /// حذف تکراری‌های موجود در دیتای فعلی (یک‌بار پاک‌سازی).
  /// تعداد موارد حذف‌شده را برمی‌گرداند.
  Future<int> removeDuplicates() async {
    final List<Profile> profiles = await getProfiles();
    if (profiles.length < 2) {
      return 0;
    }

    final Set<String> seen = <String>{};
    final List<Profile> kept = <Profile>[];

    for (final Profile item in profiles) {
      if (seen.add(fingerprintOf(item))) {
        kept.add(item);
      }
    }

    final int removed = profiles.length - kept.length;
    if (removed > 0) {
      await _persist(kept);
    }
    return removed;
  }
}
