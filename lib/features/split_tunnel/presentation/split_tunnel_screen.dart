import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/haptics.dart';
import '../application/split_tunnel_providers.dart';
import '../domain/installed_app.dart';

class SplitTunnelScreen extends ConsumerStatefulWidget {
  const SplitTunnelScreen({super.key});

  @override
  ConsumerState<SplitTunnelScreen> createState() => _SplitTunnelScreenState();
}

class _SplitTunnelScreenState extends ConsumerState<SplitTunnelScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _showSystem = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<InstalledApp> _filter(List<InstalledApp> apps) {
    final List<InstalledApp> out = apps
        .where((InstalledApp a) => _showSystem || !a.isSystem)
        .where((InstalledApp a) => a.matches(_query))
        .toList();
    out.sort((InstalledApp a, InstalledApp b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SplitTunnelConfig> configAsync =
        ref.watch(splitTunnelProvider);
    final AsyncValue<List<InstalledApp>> appsAsync =
        ref.watch(installedAppsProvider);
    final SplitTunnelConfig config =
        configAsync.value ?? const SplitTunnelConfig();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Tunneling / تونل تفکیکی'),
        actions: <Widget>[
          IconButton(
            tooltip: 'نمایش اپ‌های سیستمی',
            icon: Icon(_showSystem ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _showSystem = !_showSystem),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) async {
              final SplitTunnelNotifier n =
                  ref.read(splitTunnelProvider.notifier);
              if (value == 'clear') {
                await n.clearAll();
              } else if (value == 'all') {
                final List<InstalledApp> apps =
                    ref.read(installedAppsProvider).value ??
                        const <InstalledApp>[];
                await n.selectAll(
                    _filter(apps).map((InstalledApp a) => a.packageName));
              } else if (value == 'reload') {
                ref.invalidate(installedAppsProvider);
              }
              Haptics.selection();
            },
            itemBuilder: (BuildContext c) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'all', child: Text('انتخاب همه')),
              PopupMenuItem<String>(
                  value: 'clear', child: Text('پاک کردن انتخاب‌ها')),
              PopupMenuItem<String>(
                  value: 'reload', child: Text('بارگذاری مجدد لیست')),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SegmentedButton<SplitMode>(
              segments: const <ButtonSegment<SplitMode>>[
                ButtonSegment<SplitMode>(
                  value: SplitMode.off,
                  label: Text('خاموش'),
                  icon: Icon(Icons.all_inclusive),
                ),
                ButtonSegment<SplitMode>(
                  value: SplitMode.exclude,
                  label: Text('حذف'),
                  icon: Icon(Icons.block),
                ),
                ButtonSegment<SplitMode>(
                  value: SplitMode.include,
                  label: Text('فقط'),
                  icon: Icon(Icons.check_circle_outline),
                ),
              ],
              selected: <SplitMode>{config.mode},
              onSelectionChanged: (Set<SplitMode> s) {
                Haptics.selection();
                ref.read(splitTunnelProvider.notifier).setMode(s.first);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _modeHint(config.mode),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'جستجوی اپ...',
                border: const OutlineInputBorder(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (String v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: appsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('خطا در خواندن لیست اپ‌ها:\n$e',
                      textAlign: TextAlign.center),
                ),
              ),
              data: (List<InstalledApp> apps) {
                final List<InstalledApp> list = _filter(apps);
                if (list.isEmpty) {
                  return const Center(child: Text('اپی پیدا نشد'));
                }
                final bool disabled = config.mode == SplitMode.off;
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (BuildContext c, int i) {
                    final InstalledApp app = list[i];
                    final bool checked = config.apps.contains(app.packageName);
                    return CheckboxListTile(
                      value: checked,
                      enabled: !disabled,
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: SizedBox(
                        width: 40,
                        height: 40,
                        child: app.icon != null
                            ? Image.memory(app.icon!, gaplessPlayback: true)
                            : const Icon(Icons.android, size: 32),
                      ),
                      title: Text(app.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(app.packageName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                      onChanged: disabled
                          ? null
                          : (bool? _) {
                              Haptics.selection();
                              ref
                                  .read(splitTunnelProvider.notifier)
                                  .toggleApp(app.packageName);
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            'انتخاب‌شده: ${config.apps.length} اپ • تغییرات بعد از اتصال مجدد اعمال می‌شود',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  static String _modeHint(SplitMode mode) {
    switch (mode) {
      case SplitMode.off:
        return 'همه‌ی اپ‌ها از VPN عبور می‌کنند.';
      case SplitMode.exclude:
        return 'اپ‌های انتخاب‌شده از VPN خارج می‌شوند (بقیه داخل تونل).';
      case SplitMode.include:
        return 'فقط اپ‌های انتخاب‌شده از VPN عبور می‌کنند.';
    }
  }
}
