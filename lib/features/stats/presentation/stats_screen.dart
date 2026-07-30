import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/proxy_traffic_providers.dart';
import '../domain/proxy_traffic.dart';

/// صفحه آمار مصرف هر پروکسی (Per-Proxy Traffic Stats)
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsSort _sort = StatsSort.traffic;

  bool _isFa(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'fa';

  String _sortLabel(StatsSort sort, bool fa) {
    switch (sort) {
      case StatsSort.traffic:
        return fa ? 'بیشترین مصرف' : 'Most traffic';
      case StatsSort.connects:
        return fa ? 'تعداد اتصال' : 'Connections';
      case StatsSort.duration:
        return fa ? 'مدت اتصال' : 'Duration';
      case StatsSort.lastUsed:
        return fa ? 'آخرین استفاده' : 'Last used';
      case StatsSort.ping:
        return fa ? 'کمترین پینگ' : 'Lowest ping';
    }
  }

  String _fmtDuration(int seconds, bool fa) {
    if (seconds <= 0) return fa ? '۰ ثانیه' : '0s';
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    final int s = seconds % 60;
    if (h > 0) return fa ? '$h ساعت $m دقیقه' : '${h}h ${m}m';
    if (m > 0) return fa ? '$m دقیقه $s ثانیه' : '${m}m ${s}s';
    return fa ? '$s ثانیه' : '${s}s';
  }

  String _fmtLastUsed(DateTime? at, bool fa) {
    if (at == null) return fa ? 'هرگز' : 'Never';
    final Duration diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return fa ? 'همین حالا' : 'Just now';
    if (diff.inHours < 1) {
      return fa ? '${diff.inMinutes} دقیقه پیش' : '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return fa ? '${diff.inHours} ساعت پیش' : '${diff.inHours}h ago';
    }
    return fa ? '${diff.inDays} روز پیش' : '${diff.inDays}d ago';
  }

  Future<void> _confirmResetAll(bool fa) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(fa ? 'پاک کردن همه آمار؟' : 'Reset all stats?'),
        content: Text(
          fa
              ? 'تمام آمار مصرف پروکسی‌ها حذف می‌شود. این عمل قابل بازگشت نیست.'
              : 'All per-proxy usage stats will be deleted. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(fa ? 'انصراف' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(fa ? 'پاک کن' : 'Reset'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(proxyTrafficProvider.notifier).resetAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fa = _isFa(context);
    final AsyncValue<List<ProxyTraffic>> state = ref.watch(proxyTrafficProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(fa ? 'آمار مصرف' : 'Traffic Stats'),
        actions: <Widget>[
          PopupMenuButton<StatsSort>(
            icon: const Icon(Icons.sort),
            tooltip: fa ? 'مرتب‌سازی' : 'Sort',
            initialValue: _sort,
            onSelected: (StatsSort value) => setState(() => _sort = value),
            itemBuilder: (BuildContext ctx) => StatsSort.values
                .map(
                  (StatsSort s) => PopupMenuItem<StatsSort>(
                    value: s,
                    child: Text(_sortLabel(s, fa)),
                  ),
                )
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: fa ? 'پاک کردن همه' : 'Reset all',
            onPressed: () => _confirmResetAll(fa),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              fa ? 'خطا در بارگذاری آمار:\n$e' : 'Failed to load stats:\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (List<ProxyTraffic> items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.insights_outlined, size: 56),
                  const SizedBox(height: 12),
                  Text(
                    fa
                        ? 'هنوز آماری ثبت نشده است'
                        : 'No usage recorded yet',
                  ),
                ],
              ),
            );
          }

          final List<ProxyTraffic> sorted = List<ProxyTraffic>.of(items)
            ..sort(_sort.compare);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(proxyTrafficProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (BuildContext ctx, int index) {
                final ProxyTraffic t = sorted[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                t.profileId,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restart_alt, size: 20),
                              tooltip: fa ? 'صفر کردن' : 'Reset',
                              onPressed: () => ref
                                  .read(proxyTrafficProvider.notifier)
                                  .reset(t.profileId),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: <Widget>[
                            _Chip(
                              icon: Icons.swap_vert,
                              text: ProxyTraffic.formatBytes(t.totalBytes),
                            ),
                            _Chip(
                              icon: Icons.upload,
                              text: ProxyTraffic.formatBytes(t.uploadBytes),
                            ),
                            _Chip(
                              icon: Icons.download,
                              text: ProxyTraffic.formatBytes(t.downloadBytes),
                            ),
                            _Chip(
                              icon: Icons.link,
                              text: fa
                                  ? '${t.connectCount} بار'
                                  : '${t.connectCount}x',
                            ),
                            _Chip(
                              icon: Icons.timer_outlined,
                              text: _fmtDuration(t.totalDurationSeconds, fa),
                            ),
                            _Chip(
                              icon: Icons.network_ping,
                              text: t.lastPingMs == null
                                  ? '—'
                                  : '${t.lastPingMs} ms',
                            ),
                            _Chip(
                              icon: Icons.history,
                              text: _fmtLastUsed(t.lastUsedAt, fa),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
