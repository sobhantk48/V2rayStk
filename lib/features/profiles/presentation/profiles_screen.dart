import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../vpn/application/vpn_controller.dart';
import '../application/profile_import_parser.dart';
import '../application/profile_providers.dart';
import '../domain/profile.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  static const ProfileImportParser _parser = ProfileImportParser();

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Profile>> profilesState = ref.watch(profilesProvider);

    return AppScaffold(
      title: 'Profiles',
      currentIndex: 1,
      body: Column(
        children: <Widget>[
          _buildToolbar(context),
          const Divider(height: 1),
          Expanded(
            child: profilesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) =>
                  _buildError(error),
              data: (List<Profile> profiles) => _buildList(profiles),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Search profiles / جستجوی پروفایل',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) {
              setState(() => _query = value.trim().toLowerCase());
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openImportSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Import'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importFromClipboard,
                  icon: const Icon(Icons.content_paste_go),
                  label: const Text('Smart paste'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Delete all',
                onPressed: _confirmDeleteAll,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.read(profilesProvider.notifier).reload(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Profile> profiles) {
    final List<Profile> visible = _query.isEmpty
        ? profiles
        : profiles.where((Profile profile) {
            final String haystack = <String>[
              profile.name,
              profile.server ?? '',
              profile.type.name,
            ].join(' ').toLowerCase();
            return haystack.contains(_query);
          }).toList();

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            profiles.isEmpty
                ? 'No profile yet. Import a config to connect.\nهنوز پروفایلی نیست. یک کانفیگ وارد کنید.'
                : 'No result for this search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(profilesProvider.notifier).reload(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final Profile profile = visible[index];
          final String subtitle = <String>[
            profile.type.name.toUpperCase(),
            if ((profile.server ?? '').isNotEmpty) profile.server!,
            if (profile.port != null) '${profile.port}',
          ].join('  •  ');

          return ListTile(
            leading: Icon(
              profile.isActive
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: profile.isActive ? Colors.green : null,
            ),
            title: Text(
              profile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle:
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _activate(profile),
            trailing: PopupMenuButton<String>(
              onSelected: (String action) => _onAction(action, profile),
              itemBuilder: (BuildContext context) =>
                  const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'activate',
                  child: Text('Set active'),
                ),
                PopupMenuItem<String>(
                  value: 'connect',
                  child: Text('Connect with this'),
                ),
                PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
                PopupMenuItem<String>(
                    value: 'copy', child: Text('Copy config')),
                PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _onAction(String action, Profile profile) async {
    switch (action) {
      case 'activate':
        await _activate(profile);
        break;
      case 'connect':
        await _connect(profile);
        break;
      case 'rename':
        await _rename(profile);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: profile.rawConfig));
        _toast('Config copied.');
        break;
      case 'delete':
        await ref.read(profilesProvider.notifier).deleteProfile(profile.id);
        _toast('Profile deleted.');
        break;
    }
  }

  Future<void> _activate(Profile profile) async {
    await ref.read(profilesProvider.notifier).activateProfile(profile.id);
    _toast('«${profile.name}» is active now.');
  }

  Future<void> _connect(Profile profile) async {
    try {
      await ref
          .read(vpnControllerProvider.notifier)
          .connectWithProfile(profile);
      _toast('Connecting with «${profile.name}»...');
    } catch (error) {
      _toast('Connect failed: $error');
    }
  }

  Future<void> _rename(Profile profile) async {
    final TextEditingController controller =
        TextEditingController(text: profile.name);

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename profile'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null || name.isEmpty) {
      return;
    }

    await ref
        .read(profilesProvider.notifier)
        .updateProfile(profile.copyWith(name: name));
  }

  Future<void> _openImportSheet(BuildContext context) async {
    final TextEditingController controller = TextEditingController();

    final String? input = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Paste one or more links (vless / vmess / trojan / ss) or raw JSON.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                minLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'vless://...\nvmess://...',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Import'),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (input != null) {
      await _importText(input);
    }
  }

  Future<void> _importFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String text = data?.text ?? '';
    if (text.trim().isEmpty) {
      _toast('Clipboard is empty.');
      return;
    }
    await _importText(text);
  }

  Future<void> _importText(String input) async {
    final String value = input.trim();
    if (value.isEmpty) {
      return;
    }

    final List<Profile> parsed = <Profile>[];

    // JSON خام تک‌تکه است؛ بقیه ورودی‌ها خط‌به‌خط پارس می‌شوند.
    if (value.startsWith('{')) {
      parsed.add(_parser.parse(value));
    } else {
      int offset = 0;
      for (final String line in value.split(RegExp(r'[\r\n]+'))) {
        final String candidate = line.trim();
        if (candidate.isEmpty) {
          continue;
        }
        final Profile profile = _parser.parse(candidate);
        // جلوگیری از تکراری شدن id در واردات انبوه سریع.
        parsed.add(profile.copyWith(id: '${profile.id}_${offset++}'));
      }
    }

    if (parsed.isEmpty) {
      _toast('Nothing valid to import.');
      return;
    }

    await ref.read(profilesProvider.notifier).addProfiles(parsed);
    _toast('${parsed.length} profile(s) imported.');
  }

  Future<void> _confirmDeleteAll() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete all profiles?'),
          content: const Text('This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(profilesProvider.notifier).deleteAll();
      _toast('All profiles deleted.');
    }
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
