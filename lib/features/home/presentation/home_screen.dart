import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/strings.dart';
import '../../sing_box/domain/sing_box_config_exception.dart';
import '../../vpn/application/vpn_controller.dart';
import '../../vpn/application/vpn_stats_controller.dart';
import '../../vpn/domain/vpn_stats.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Strings strings = Strings.of(context);
    final VpnConnectionState state = ref.watch(vpnControllerProvider);
    final VpnStats stats = ref.watch(vpnStatsProvider);

    return AppScaffold(
      title: strings.appName,
      currentIndex: 0,
      body: ListView(
        children: <Widget>[
          _StatusBadge(state: state),
          const SizedBox(height: 24),
          Center(
            child: _ConnectButton(
              state: state,
              onPressed: () => _toggle(context, ref, state),
            ),
          ),
          const SizedBox(height: 28),
          _StatsGrid(state: state, stats: stats),
          const SizedBox(height: 16),
          _TotalUsageCard(stats: stats),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    VpnConnectionState state,
  ) async {
    // در حالت‌های میانی هیچ اقدامی نمی‌کنیم تا هسته گیج نشود.
    if (state == VpnConnectionState.connecting ||
        state == VpnConnectionState.disconnecting) {
      return;
    }

    final Strings strings = Strings.of(context);
    final VpnController controller = ref.read(vpnControllerProvider.notifier);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    try {
      if (state == VpnConnectionState.connected) {
        await controller.disconnect();
      } else {
        await controller.connect();
        await ref.read(vpnStatsProvider.notifier).refreshLatency();
      }
    } on SingBoxConfigException {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.noProfileSelected)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.connectionFailed)),
      );
    }
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.state, required this.onPressed});

  final VpnConnectionState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Strings strings = Strings.of(context);
    final Color color = _statusColor(context, state);
    final bool busy = state == VpnConnectionState.connecting ||
        state == VpnConnectionState.disconnecting;

    return Semantics(
      button: true,
      label: state == VpnConnectionState.connected
          ? strings.disconnect
          : strings.connect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 190,
        height: 190,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color, width: 3),
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onPressed,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (busy)
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  else
                    Icon(Icons.power_settings_new, size: 52, color: color),
                  const SizedBox(height: 12),
                  Text(
                    state == VpnConnectionState.connected
                        ? strings.disconnect
                        : strings.connect,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.state});

  final VpnConnectionState state;

  @override
  Widget build(BuildContext context) {
    final Color color = _statusColor(context, state);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              _statusLabel(context, state),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.state, required this.stats});

  final VpnConnectionState state;
  final VpnStats stats;

  @override
  Widget build(BuildContext context) {
    final Strings strings = Strings.of(context);
    final bool live = state == VpnConnectionState.connected;

    final List<_StatItem> items = <_StatItem>[
      _StatItem(
        icon: Icons.network_ping,
        label: strings.ping,
        value: stats.pingMs == null ? '—' : '${stats.pingMs} ms',
      ),
      _StatItem(
        icon: Icons.timer_outlined,
        label: strings.duration,
        value: live ? _formatDuration(stats.duration) : '00:00:00',
      ),
      _StatItem(
        icon: Icons.download_rounded,
        label: strings.download,
        value: _formatSpeed(live ? stats.downloadBps : 0),
      ),
      _StatItem(
        icon: Icons.upload_rounded,
        label: strings.upload,
        value: _formatSpeed(live ? stats.uploadBps : 0),
      ),
      _StatItem(
        icon: Icons.public,
        label: strings.location,
        value: stats.location ?? strings.unknown,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: items,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalUsageCard extends StatelessWidget {
  const _TotalUsageCard({required this.stats});

  final VpnStats stats;

  @override
  Widget build(BuildContext context) {
    final Strings strings = Strings.of(context);
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.totalUsage, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _UsageTile(
                    icon: Icons.arrow_downward_rounded,
                    label: strings.download,
                    value: _formatBytes(stats.totalDownload),
                  ),
                ),
                Expanded(
                  child: _UsageTile(
                    icon: Icons.arrow_upward_rounded,
                    label: strings.upload,
                    value: _formatBytes(stats.totalUpload),
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

class _UsageTile extends StatelessWidget {
  const _UsageTile({
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

    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.labelSmall),
            Text(
              value,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }
}

Color _statusColor(BuildContext context, VpnConnectionState state) {
  final VpnStatusColors colors = VpnStatusColors.of(context);
  switch (state) {
    case VpnConnectionState.connected:
      return colors.connected;
    case VpnConnectionState.connecting:
    case VpnConnectionState.disconnecting:
      return colors.connecting;
    case VpnConnectionState.disconnected:
      return colors.idle;
  }
}

String _statusLabel(BuildContext context, VpnConnectionState state) {
  final Strings strings = Strings.of(context);
  switch (state) {
    case VpnConnectionState.connected:
      return strings.connected;
    case VpnConnectionState.connecting:
      return strings.connecting;
    case VpnConnectionState.disconnecting:
      return strings.disconnecting;
    case VpnConnectionState.disconnected:
      return strings.disconnected;
  }
}

String _formatDuration(Duration duration) {
  String two(int value) => value.toString().padLeft(2, '0');
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}

String _formatBytes(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 || unit == 0 ? 0 : 1)} '
      '${units[unit]}';
}

String _formatSpeed(int bytesPerSecond) => '${_formatBytes(bytesPerSecond)}/s';
