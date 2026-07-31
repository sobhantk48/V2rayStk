import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/group_providers.dart';
import '../domain/proxy_group.dart';

/// Preset ARGB colors offered in the color picker sheet.
const List<int> _presetColors = <int>[
  0xFF2196F3,
  0xFF4CAF50,
  0xFFFF9800,
  0xFFF44336,
  0xFF9C27B0,
  0xFF009688,
  0xFF795548,
  0xFF607D8B,
];

class GroupsManageScreen extends ConsumerWidget {
  const GroupsManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProxyGroup>> groupsState = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Delete all',
            onPressed: groupsState.valueOrNull == null ||
                    groupsState.valueOrNull!.isEmpty
                ? null
                : () => _confirmDeleteAll(context, ref),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createGroup(context, ref),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('New group'),
      ),
      body: groupsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (List<ProxyGroup> groups) {
          if (groups.isEmpty) {
            return const _EmptyView();
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: groups.length,
            onReorder: (int oldIndex, int newIndex) {
              final List<ProxyGroup> reordered = List<ProxyGroup>.of(groups);
              // ReorderableListView reports the target index before removal.
              final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
              final ProxyGroup moved = reordered.removeAt(oldIndex);
              reordered.insert(target, moved);
              ref.read(groupsProvider.notifier).reorder(
                    reordered.map((ProxyGroup g) => g.id).toList(),
                  );
            },
            itemBuilder: (BuildContext context, int index) {
              final ProxyGroup group = groups[index];
              return _GroupTile(
                key: ValueKey<String>(group.id),
                group: group,
                index: index,
                onRename: () => _renameGroup(context, ref, group),
                onPickColor: () => _pickColor(context, ref, group),
                onDelete: () => _confirmDelete(context, ref, group),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final String? name = await _askName(context, title: 'New group');
    if (name == null) {
      return;
    }
    await ref.read(groupsProvider.notifier).createGroup(name);
  }

  Future<void> _renameGroup(
    BuildContext context,
    WidgetRef ref,
    ProxyGroup group,
  ) async {
    final String? name = await _askName(
      context,
      title: 'Rename group',
      initialValue: group.name,
    );
    if (name == null) {
      return;
    }
    await ref.read(groupsProvider.notifier).renameGroup(group.id, name);
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    String initialValue = '',
  }) {
    final TextEditingController controller =
        TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'e.g. Germany',
            ),
            onSubmitted: (String value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    ).then((String? value) {
      controller.dispose();
      if (value == null || value.isEmpty) {
        return null;
      }
      return value;
    });
  }

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    ProxyGroup group,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Group color',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    for (final int value in _presetColors)
                      _ColorDot(
                        colorValue: value,
                        selected: group.colorValue == value,
                        onTap: () {
                          ref
                              .read(groupsProvider.notifier)
                              .setColor(group.id, value);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    // Passing null clears the color (clearColor: true).
                    ref.read(groupsProvider.notifier).setColor(group.id, null);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.format_color_reset),
                  label: const Text('Use theme default'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProxyGroup group,
  ) async {
    final bool confirmed = await _confirm(
      context,
      title: 'Delete group',
      message:
          'Delete "${group.name}"? Its profiles are kept and moved to Ungrouped.',
    );
    if (!confirmed) {
      return;
    }
    await ref.read(groupsProvider.notifier).deleteGroup(group.id);
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final bool confirmed = await _confirm(
      context,
      title: 'Delete all groups',
      message:
          'All groups will be removed. Profiles are kept and moved to Ungrouped.',
    );
    if (!confirmed) {
      return;
    }
    await ref.read(groupsProvider.notifier).deleteAll();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.index,
    required this.onRename,
    required this.onPickColor,
    required this.onDelete,
    super.key,
  });

  final ProxyGroup group;
  final int index;
  final VoidCallback onRename;
  final VoidCallback onPickColor;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color color = group.colorValue == null
        ? Theme.of(context).colorScheme.primary
        : Color(group.colorValue!);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: const Icon(Icons.folder, color: Colors.white, size: 20),
      ),
      title: Text(group.name),
      subtitle: Text('Order ${group.sortOrder}'),
      onTap: onRename,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Color',
            onPressed: onPickColor,
            icon: const Icon(Icons.palette_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color #${colorValue.toRadixString(16).toUpperCase()}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Color(colorValue),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.folder_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'No groups yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Create a group to organize your profiles.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
