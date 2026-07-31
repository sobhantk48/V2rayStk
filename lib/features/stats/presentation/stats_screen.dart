import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../profiles/application/profile_providers.dart';
import '../../profiles/domain/profile.dart';
import '../application/proxy_traffic_providers.dart';
import '../domain/proxy_traffic.dart';

/// آمار مصرف هر پروکسی به‌صورت جداگانه (Per-Proxy Traffic Stats).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static String formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '-';
    }

    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  static String formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final DateTime local = value.toLocal();
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');

    return '$month/$day $hour:$minute';
  }

  Future<void> _confirmResetAll(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset all stats?'),
          content: const Text(
            'همهٔ آمار مصرف پاک می‌شود. این عمل قابل بازگشت نیست.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(proxyTrafficProvider.notifier).resetAll();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProxyTraffic>> trafficAsync =
        ref.watch(proxyTrafficProvider);
    final List<Profile> profiles =
        ref.watch(profilesProvider).value ?? <Profile>[];

    final Map<String, String> names = <String, String>{
      for (final Profile profile in profiles) profile.id: profile.name,
    };

    return AppScaffold(
      title: 'Traffic Stats',
      currentIndex: 0,
      body: trafficAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Text('خطا در خواندن آمار: $error'),
        ),
        data: (List<ProxyTraffic> items) {
          final List<ProxyTraffic> sorted = <ProxyTraffic>[...items]
            ..sort((ProxyTraffic a, ProxyTraffic b) =>
                b.totalBytes.compareTo(a.totalBytes));

          final int totalUp = sorted.fold<int>(
            0,
            (int sum, ProxyTraffic item) => sum + item.uploadBytes,
          );
          final int totalDown = sorted.fold<int>(
            0,
            (int sum, ProxyTraffic item) => sum + item.downloadBytes,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SummaryCard(
                uploadBytes: totalUp,
                downloadBytes: totalDown,
                profileCount: sorted.length,
                onResetAll: sorted.isEmpty
                    ? null
                    : () => _confirmResetAll(context, ref),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: sorted.isEmpty
                    ? const Center(
                        child: Text('هنوز آماری ثبت نشده است.'),
                      )
                    : ListView.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (BuildContext context, int index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final ProxyTraffic item = sorted[index];

                          return _TrafficTile(
                            traffic: item,
                            name: names[item.profileId] ?? item.profileId,
                            onReset: () => ref
                                .read(proxyTrafficProvider.notifier)
                                .reset(item.profileId),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.uploadBytes,
    required this.downloadBytes,
    required this.profileCount,
    required this.onResetAll,
  });

  final int uploadBytes;
  final int downloadBytes;
  final int profileCount;
  final VoidCallback? onResetAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Total usage',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: onResetAll,
                  tooltip: 'Reset all',
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    icon: Icons.arrow_downward,
                    label: 'Download',
                    value: ProxyTraffic.formatBytes(downloadBytes),
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: Icons.arrow_upward,
                    label: 'Upload',
                    value: ProxyTraffic.formatBytes(uploadBytes),
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: Icons.dns_outlined,
                    label: 'Proxies',
                    value: '$profileCount',
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _TrafficTile extends StatelessWidget {
  const _TrafficTile({
    required this.traffic,
    required this.name,
    required this.onReset,
  });

  final ProxyTraffic traffic;
  final String name;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              Text(
                '↓ ${ProxyTraffic.formatBytes(traffic.downloadBytes)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '↑ ${ProxyTraffic.formatBytes(traffic.uploadBytes)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Ping: ${traffic.lastPingMs == null ? '-' : '${traffic.lastPingMs} ms'}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Time: ${StatsScreen.formatDuration(traffic.totalDurationSeconds)}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Connects: ${traffic.connectCount}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                'Last: ${StatsScreen.formatDate(traffic.lastUsedAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: onReset,
          tooltip: 'Reset',
          icon: const Icon(Icons.restart_alt),
        ),
      ),
    );
  }
}
