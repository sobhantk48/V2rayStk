import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/profile.dart';

class ProfileService {
  static const String _boxName = 'profiles';
  static final _uuid = Uuid();

  static Future<Box<Profile>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox<Profile>(_boxName);
    }
    return Hive.box<Profile>(_boxName);
  }

  static Future<List<Profile>> getAll() async {
    final box = await _box();
    return box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<Profile?> getSelected() async {
    final list = await getAll();
    try {
      return list.firstWhere((p) => p.isSelected);
    } catch (_) {
      return list.isNotEmpty ? list.first : null;
    }
  }

  static Future<void> add(String name, String config, {String? remark}) async {
    final box = await _box();
    final profile = Profile(
      id: _uuid.v4(),
      name: name,
      config: config,
      remark: remark,
      isSelected: box.isEmpty,
    );
    await box.put(profile.id, profile);
  }

  static Future<void> update(Profile profile) async {
    final box = await _box();
    await box.put(profile.id, profile);
  }

  static Future<void> delete(String id) async {
    final box = await _box();
    final wasSelected = box.get(id)?.isSelected ?? false;
    await box.delete(id);
    if (wasSelected && box.isNotEmpty) {
      final first = box.values.first;
      first.isSelected = true;
      await first.save();
    }
  }

  static Future<void> select(String id) async {
    final box = await _box();
    for (final p in box.values) {
      p.isSelected = p.id == id;
      await p.save();
    }
  }
}
