import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/latency_providers.dart';
import '../application/profile_providers.dart';
import '../domain/profile.dart';

class PingResultsSheet extends ConsumerStatefulWidget {
  const PingResultsSheet({super.key, required this.profiles});

  final List<Profile> profiles;

  @override
  ConsumerState<PingResultsSheet> createState() => _PingResultsSheetState();
}

class _PingResultsSheetState extends ConsumerState<PingResultsSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _run());
  }

  Future<void> _run() async {
    await ref.read(latencyProvider.notifier).pingAll(widget.profiles);
  }

  Color? _colorFor(int? ms, ThemeData theme) {
    if (ms == null) {
      return theme.colorScheme.error;
    }
    if (ms < 300) {
      return Colors.green;
    }
    if (ms < 800) {
      return Colors.orange;
    }
    return theme.colorScheme.error;
  }

  Future<void> _activateFastest() async {
    final String? bestId =
        ref.read(latencyProvider.notifier).fastestProfileId();
    if (bestId == null) {
      return;
    }
    await ref.read(profilesProvider.notifier).activateProfile(bestId);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LatencyState latency = ref.watch(latencyProvider);

    final List<Profile> sorted = List<Profile>.from(widget.profiles);
    sorted.sort((Profile a, Profile b) {
      final int? aMs = latency.latencyFor(a.id);
      final int? bMs = latency.latencyFor(b.id);
      if (aMs == null && bMs == null) {
        return a.name.compareTo(b.name);
      }
      if (aMs == null) {
        return 1;
      }
      if (bMs == null) {
        return -1;
      }
      return aMs.compareTo(bMs);
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Ping all / تست همهٔ سرورها',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: latency.isTesting ? latency.progress : 1,
            ),
            const SizedBox(height: 6),
            Text(
              latency.isTesting
                  ? 'Testing ${latency.done}/${latency.total} …'
                  : 'Done / پایان یافت (${latency.done}/${latency.total})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (BuildContext _, int __) =>
                    const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final Profile profile = sorted[index];
                  final int? ms = latency.latencyFor(profile.id);
                  final String? error = latency.errorFor(profile.id);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${profile.type.name} • '
                      '${profile.server ?? '-'}:${profile.port ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      ms != null ? '$ms ms' : (error ?? 'failed'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _colorFor(ms, theme),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: latency.isTesting ? null : _run,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retest'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: latency.isTesting ? null : _activateFastest,
                    icon: const Icon(Icons.bolt),
                    label: const Text('Use fastest'),
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
