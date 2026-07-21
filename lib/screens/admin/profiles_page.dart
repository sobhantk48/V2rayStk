import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/profile_service.dart';
import 'add_edit_profile_page.dart';

class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('profiles'.tr()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditProfilePage()),
          );
          ref.invalidate(profilesProvider);
          ref.invalidate(selectedProfileProvider);
        },
        icon: const Icon(Icons.add),
        label: Text('add_profile'.tr()),
        backgroundColor: AppTheme.primary,
      ),
      body: profilesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'no_profiles'.tr(),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final p = list[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.isSelected
                        ? AppTheme.success.withOpacity(0.2)
                        : AppTheme.primary.withOpacity(0.15),
                    child: Icon(
                      p.isSelected ? Icons.check_circle : Icons.dns,
                      color: p.isSelected ? AppTheme.success : AppTheme.primary,
                    ),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    p.config,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'select') {
                        await ProfileService.select(p.id);
                        ref.invalidate(profilesProvider);
                        ref.invalidate(selectedProfileProvider);
                      } else if (value == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditProfilePage(profile: p),
                          ),
                        );
                        ref.invalidate(profilesProvider);
                        ref.invalidate(selectedProfileProvider);
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.surface,
                            title: Text('confirm_delete'.tr()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('no'.tr()),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text('yes'.tr()),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ProfileService.delete(p.id);
                          ref.invalidate(profilesProvider);
                          ref.invalidate(selectedProfileProvider);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('profile_deleted'.tr())),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'select', child: Text('select_profile'.tr())),
                      PopupMenuItem(value: 'edit', child: Text('edit_profile'.tr())),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('delete_profile'.tr(), style: const TextStyle(color: AppTheme.danger)),
                      ),
                    ],
                  ),
                  onTap: () async {
                    await ProfileService.select(p.id);
                    ref.invalidate(profilesProvider);
                    ref.invalidate(selectedProfileProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
