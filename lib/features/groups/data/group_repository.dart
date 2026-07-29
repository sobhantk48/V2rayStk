import '../domain/proxy_group.dart';

abstract class GroupRepository {
  Future<List<ProxyGroup>> getGroups();

  Future<void> addGroup(ProxyGroup group);

  Future<void> updateGroup(ProxyGroup group);

  Future<void> deleteGroup(String groupId);

  Future<void> deleteAll();

  Future<void> reorder(List<String> orderedIds);
}
