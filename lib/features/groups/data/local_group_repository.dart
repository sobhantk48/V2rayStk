import '../../../core/storage/local_storage_service.dart';
import '../domain/proxy_group.dart';
import 'group_repository.dart';

class LocalGroupRepository implements GroupRepository {
  LocalGroupRepository(this._storage);

  static const String _groupsKey = 'proxy_groups';

  final LocalStorageService _storage;

  @override
  Future<List<ProxyGroup>> getGroups() async {
    final List<Map<String, dynamic>> items =
        await _storage.readJsonList(_groupsKey);

    final List<ProxyGroup> groups = items.map(ProxyGroup.fromJson).toList()
      ..sort((ProxyGroup a, ProxyGroup b) {
        final int byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) {
          return byOrder;
        }

        return a.createdAt.compareTo(b.createdAt);
      });

    return groups;
  }

  Future<void> _persist(List<ProxyGroup> groups) async {
    await _storage.saveJsonList(
      _groupsKey,
      groups.map((ProxyGroup item) => item.toJson()).toList(),
    );
  }

  @override
  Future<void> addGroup(ProxyGroup group) async {
    final List<ProxyGroup> groups = await getGroups();
    groups.add(group);
    await _persist(groups);
  }

  @override
  Future<void> updateGroup(ProxyGroup group) async {
    final List<ProxyGroup> groups = await getGroups();
    final int index =
        groups.indexWhere((ProxyGroup item) => item.id == group.id);

    if (index == -1) {
      groups.add(group);
    } else {
      groups[index] = group;
    }

    await _persist(groups);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final List<ProxyGroup> groups = await getGroups();
    groups.removeWhere((ProxyGroup item) => item.id == groupId);
    await _persist(groups);
  }

  @override
  Future<void> deleteAll() async {
    await _persist(<ProxyGroup>[]);
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    final List<ProxyGroup> groups = await getGroups();

    final List<ProxyGroup> reordered = <ProxyGroup>[];
    for (int i = 0; i < orderedIds.length; i++) {
      final int index =
          groups.indexWhere((ProxyGroup item) => item.id == orderedIds[i]);
      if (index != -1) {
        reordered.add(groups[index].copyWith(sortOrder: i));
      }
    }

    // گروه‌هایی که در لیست ترتیب نبودند، انتهای لیست می‌روند.
    int tail = orderedIds.length;
    for (final ProxyGroup group in groups) {
      final bool alreadyAdded =
          reordered.any((ProxyGroup item) => item.id == group.id);
      if (!alreadyAdded) {
        reordered.add(group.copyWith(sortOrder: tail));
        tail++;
      }
    }

    await _persist(reordered);
  }
}
