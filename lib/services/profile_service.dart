import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/profile.dart';

class ProfileService {
  static const boxName = 'profiles';
  static final _uuid = Uuid();

  static Future<Box<Profile>> get box async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProfileAdapter());
    }
    return await Hive.openBox<Profile>(boxName);
  }

  static Future<List<Profile>> getAll() async {
    final b = await box;
    return b.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<void> add(String name, String config, {String? remark}) async {
    final b = await box;
    final profile = Profile(
      id: _uuid.v4(),
      name: name,
      config: config,
      remark: remark,
    );
    await b.put(profile.id, profile);
  }

  static Future<void> update(Profile profile) async {
    final b = await box;
    await b.put(profile.id, profile);
  }

  static Future<void> delete(String id) async {
    final b = await box;
    await b.delete(id);
  }

  static Future<void> select(String id) async {
    final b = await box;
    for (final p in b.values) {
      p.isSelected = p.id == id;
      await p.save();
    }
  }

  static Future<Profile?> getSelected() async {
    final list = await getAll();
    try {
      return list.firstWhere((p) => p.isSelected);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }
}
