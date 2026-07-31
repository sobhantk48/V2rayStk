import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../application/speed_test_controller.dart';
import '../domain/speed_test_result.dart';

/// تست سرعت داخلی + تست کیفیت اینترنت + امتیازدهی.
class SpeedTestScreen extends ConsumerWidget {
  const SpeedTestScreen({super.key});

  static String phaseLabel(SpeedTestPhase phase) {
    switch (phase) {
      case SpeedTestPhase.idle:
        return 'Ready';
      case SpeedTestPhase.ping:
        return 'Testing ping...';
      case SpeedTestPhase.download:
        return 'Testing download...';
      case SpeedTestPhase.upload:
        return 'Testing upload...';
      case SpeedTestPhase.done:
        return 'Completed';
      case SpeedTestPhase.error:
        return 'Failed';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SpeedTestState state = ref.watch(speedTestControllerProvider);
    final SpeedTestController controller =
        ref.read(speedTestControllerProvider.notifier);
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      title: 'Speed Test',
      currentIndex: 0,
      body: ListView(
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  Text(
                    phaseLabel(state.phase),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.isRunning
                        ? state.currentSpeedMbps.toStringAsFixed(1)
                        : state.downloadMbps.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text('Mbps', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: state.isRunning
                        ? state.progress.clamp(0.0, 1.0)
                        : (state.phase == SpeedTestPhase.done ? 1.0 : 0.0),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: state.isRunning
                        ? OutlinedButton.icon(
                            onPressed: controller.cancel,
                            icon: const Icon(Icons.stop),
                            label: const Text('Cancel'),
                          )
                        : FilledButton.icon(
                            onPressed: controller.start,
                            icon: const Icon(Icons.speed),
                            label: const Text('Start test'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Network quality', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Metric(
                          icon: Icons.arrow_downward,
                          label: 'Download',
                          value:
                              '${state.downloadMbps.toStringAsFixed(1)} Mbps',
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          icon: Icons.arrow_upward,
                          label: 'Upload',
                          value: '${state.uploadMbps.toStringAsFixed(1)} Mbps',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Metric(
                          icon: Icons.network_ping,
                          label: 'Ping',
                          value: '${state.pingMs.toStringAsFixed(0)} ms',
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          icon: Icons.graphic_eq,
                          label: 'Jitter',
                          value: '${state.jitterMs.toStringAsFixed(0)} ms',
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          icon: Icons.wifi_tethering_error,
                          label: 'Loss',
                          value:
                              '${state.packetLossPercent.toStringAsFixed(0)}%',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Scores', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ScoreBar(
                    label: 'Gaming',
                    score: state.gamingScore,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 10),
                  _ScoreBar(
                    label: 'Browsing',
                    score: state.browsingScore,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 10),
                  _ScoreBar(
                    label: 'Streaming',
                    score: state.streamingScore,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          if (state.phase == SpeedTestPhase.error &&
              state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleSmall),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            Text('$score/100', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }
}
