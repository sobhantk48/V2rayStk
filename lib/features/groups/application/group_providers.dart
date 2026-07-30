import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profiles/application/profile_providers.dart';
import '../../profiles/data/profile_repository.dart';
import '../../profiles/domain/profile.dart';
import '../data/group_repository.dart';
import '../data/local_group_repository.dart';
import '../domain/proxy_group.dart';

final FutureProvider<GroupRepository> groupRepositoryProvider =
    FutureProvider<GroupRepository>((Ref ref) async {
  final localStorage = await ref.watch(localStorageProvider.future);
  return LocalGroupRepository(localStorage);
});

class GroupsNotifier extends AsyncNotifier<List<ProxyGroup>> {
  @override
  Future<List<ProxyGroup>> build() async {
    final GroupRepository repository =
        await ref.watch(groupRepositoryProvider.future);
    return repository.getGroups();
  }

  Future<GroupRepository> get _repository =>
      ref.read(groupRepositoryProvider.future);

  Future<void> _refresh() async {
    final GroupRepository repository = await _repository;
    state = AsyncValue<List<ProxyGroup>>.data(await repository.getGroups());
  }

  Future<ProxyGroup> createGroup(String name, {int? colorValue}) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> existing = await repository.getGroups();

    final ProxyGroup group = ProxyGroup(
      id: 'grp_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Group' : name.trim(),
      createdAt: DateTime.now(),
      colorValue: colorValue,
      sortOrder: existing.length,
    );

    await repository.addGroup(group);
    await _refresh();

    return group;
  }

  Future<void> renameGroup(String groupId, String name) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> groups = await repository.getGroups();
    final int index =
        groups.indexWhere((ProxyGroup item) => item.id == groupId);

    if (index == -1) {
      return;
    }

    await repository.updateGroup(groups[index].copyWith(name: name.trim()));
    await _refresh();
  }

  Future<void> setColor(String groupId, int? colorValue) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> groups = await repository.getGroups();
    final int index =
        groups.indexWhere((ProxyGroup item) => item.id == groupId);

    if (index == -1) {
      return;
    }

    await repository.updateGroup(
      colorValue == null
          ? groups[index].copyWith(clearColor: true)
          : groups[index].copyWith(colorValue: colorValue),
    );
    await _refresh();
  }

  Future<void> toggleCollapsed(String groupId) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> groups = await repository.getGroups();
    final int index =
        groups.indexWhere((ProxyGroup item) => item.id == groupId);

    if (index == -1) {
      return;
    }

    await repository.updateGroup(
      groups[index].copyWith(isCollapsed: !groups[index].isCollapsed),
    );
    await _refresh();
  }

  /// گروه حذف می‌شود اما پروفایل‌های عضو آن پاک نمی‌شوند و «بدون گروه» می‌شوند.
  Future<void> deleteGroup(String groupId) async {
    final GroupRepository repository = await _repository;
    await repository.deleteGroup(groupId);

    final ProfileRepository profiles =
        await ref.read(profileRepositoryProvider.future);
    final List<Profile> all = await profiles.getProfiles();

    final List<Profile> orphans = all
        .where((Profile profile) => profile.groupId == groupId)
        .map((Profile profile) => profile.copyWith(clearGroup: true))
        .toList();

    await profiles.updateProfiles(orphans);

    await _refresh();

    if (orphans.isNotEmpty) {
      ref.invalidate(profilesProvider);
    }
  }

  Future<void> reorder(List<String> orderedIds) async {
    final GroupRepository repository = await _repository;
    await repository.reorder(orderedIds);
    await _refresh();
  }
}

final AsyncNotifierProvider<GroupsNotifier, List<ProxyGroup>> groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<ProxyGroup>>(
  GroupsNotifier.new,
);

/// انتساب/جابه‌جایی پروفایل‌ها بین گروه‌ها (پشتیبانی از انتخاب چندگانه).
final Provider<ProfileGroupAssigner> profileGroupAssignerProvider =
    Provider<ProfileGroupAssigner>((Ref ref) => ProfileGroupAssigner(ref));

class ProfileGroupAssigner {
  ProfileGroupAssigner(this._ref);

  final Ref _ref;

  Future<void> assign({
    required List<String> profileIds,
    required String? groupId,
  }) async {
    if (profileIds.isEmpty) {
      return;
    }

    final ProfileRepository profiles =
        await _ref.read(profileRepositoryProvider.future);
    final List<Profile> all = await profiles.getProfiles();

    final Set<String> targets = profileIds.toSet();

    final List<Profile> patched = all
        .where((Profile profile) => targets.contains(profile.id))
        .map(
          (Profile profile) => groupId == null
              ? profile.copyWith(clearGroup: true)
              : profile.copyWith(groupId: groupId),
        )
        .toList();

    if (patched.isEmpty) {
      return;
    }

    await profiles.updateProfiles(patched);

    _ref.invalidate(profilesProvider);
  }
}
