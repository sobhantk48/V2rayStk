import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../data/group_repository.dart';
import '../data/local_group_repository.dart';
import '../domain/proxy_group.dart';

final FutureProvider<GroupRepository> groupRepositoryProvider =
    FutureProvider<GroupRepository>((Ref ref) async {
  final LocalStorageService storage =
      await ref.watch(localStorageProvider.future);
  return LocalGroupRepository(storage);
});

final AsyncNotifierProvider<GroupsNotifier, List<ProxyGroup>> groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<ProxyGroup>>(
  GroupsNotifier.new,
);

class GroupsNotifier extends AsyncNotifier<List<ProxyGroup>> {
  Future<GroupRepository> get _repository =>
      ref.read(groupRepositoryProvider.future);

  @override
  Future<List<ProxyGroup>> build() async {
    final GroupRepository repository = await _repository;
    return repository.getGroups();
  }

  Future<void> _refresh() async {
    final GroupRepository repository = await _repository;
    state = AsyncValue<List<ProxyGroup>>.data(await repository.getGroups());
  }

  Future<ProxyGroup> createGroup(String name, {int? colorValue}) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> current = await repository.getGroups();

    final ProxyGroup group = ProxyGroup(
      id: 'grp_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Group' : name.trim(),
      createdAt: DateTime.now(),
      colorValue: colorValue,
      sortOrder: current.length,
    );

    await repository.addGroup(group);
    await _refresh();
    return group;
  }

  Future<void> renameGroup(String groupId, String name) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> current = await repository.getGroups();
    final int index =
        current.indexWhere((ProxyGroup item) => item.id == groupId);

    if (index == -1) {
      return;
    }

    await repository.updateGroup(
      current[index].copyWith(name: name.trim().isEmpty ? 'Group' : name.trim()),
    );
    await _refresh();
  }

  Future<void> setColor(String groupId, int? colorValue) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> current = await repository.getGroups();
    final int index =
        current.indexWhere((ProxyGroup item) => item.id == groupId);

    if (index == -1) {
      return;
    }

    await repository.updateGroup(
      colorValue == null
          ? current[index].copyWith(clearColor: true)
          : current[index].copyWith(colorValue: colorValue),
    );
    await _refresh();
  }

  Future<void> toggleCollapsed(String groupId) async {
    final GroupRepository repository = await _repository;
    final List<ProxyGroup> current = await repository.getGroups();
    final int index =
        current.indexWhere((ProxyGroup item) => item.id == groupId);

    if (index == -1) {
      return;
    }

    await repository.updateGroup(
      current[index].copyWith(isCollapsed: !current[index].isCollapsed),
    );
    await _refresh();
  }

  /// حذف گروه؛ پروفایل‌های داخل آن حذف نمی‌شوند و بدون گروه می‌مانند.
  Future<void> deleteGroup(String groupId) async {
    final GroupRepository repository = await _repository;
    await repository.deleteGroup(groupId);

    await ref.read(profileGroupAssignerProvider).detachGroup(groupId);
    await _refresh();
  }

  Future<void> reorder(List<String> orderedIds) async {
    final GroupRepository repository = await _repository;
    await repository.reorder(orderedIds);
    await _refresh();
  }
}

final Provider<ProfileGroupAssigner> profileGroupAssignerProvider =
    Provider<ProfileGroupAssigner>((Ref ref) => ProfileGroupAssigner(ref));

/// انتساب/برداشتن گروه روی پروفایل‌ها؛ از همان ProfilesNotifier استفاده می‌کند
/// تا لیست پروفایل‌ها در UI هم بلافاصله تازه شود.
class ProfileGroupAssigner {
  ProfileGroupAssigner(this._ref);

  final Ref _ref;

  Future<List<Profile>> _profiles() =>
      _ref.read(profilesProvider.future);

  Future<void> assign({
    required List<String> profileIds,
    required String? groupId,
  }) async {
    if (profileIds.isEmpty) {
      return;
    }

    final List<Profile> profiles = await _profiles();
    final ProfilesNotifier notifier = _ref.read(profilesProvider.notifier);

    for (final Profile profile in profiles) {
      if (!profileIds.contains(profile.id)) {
        continue;
      }

      await notifier.updateProfile(
        groupId == null || groupId.isEmpty
            ? profile.copyWith(clearGroup: true)
            : profile.copyWith(groupId: groupId),
      );
    }
  }

  /// پس از حذف یک گروه، ارجاع‌های باقی‌مانده پاک می‌شوند.
  Future<void> detachGroup(String groupId) async {
    final List<Profile> profiles = await _profiles();
    final List<String> affected = profiles
        .where((Profile profile) => profile.groupId == groupId)
        .map((Profile profile) => profile.id)
        .toList();

    await assign(profileIds: affected, groupId: null);
  }
}
