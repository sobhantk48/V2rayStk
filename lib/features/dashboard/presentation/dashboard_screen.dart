import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/strings.dart';
import '../../sing_box/domain/sing_box_config_exception.dart';
import '../../vpn/application/vpn_controller.dart';
import '../../vpn/application/vpn_stats_controller.dart';
import '../../vpn/domain/vpn_stats.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _recentlyDisconnected = false;
  Timer? _redTimer;

  @override
  void dispose() {
    _redTimer?.cancel();
    super.dispose();
  }

  void _markDisconnected() {
    _redTimer?.cancel();
    setState(() => _recentlyDisconnected = true);
    _redTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _recentlyDisconnected = false);
    });
  }

  Future<void> _toggle(VpnConnectionState state) async {
    final VpnController controller = ref.read(vpnControllerProvider.notifier);
    try {
      if (state == VpnConnectionState.connected) {
        await controller.disconnect();
      } else if (state == VpnConnectionState.disconnected) {
        await controller.connect();
      }
    } catch (error) {
      if (!mounted) return;
      final String reason =
          error is SingBoxConfigException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Strings.of(context).connectionFailed}: $reason'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: reason)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Strings s = Strings.of(context);
    final VpnConnectionState state = ref.watch(vpnControllerProvider);
    final VpnStats stats = ref.watch(vpnStatsProvider);

    ref.listen<VpnConnectionState>(vpnControllerProvider, (previous, next) {
      if (previous == VpnConnectionState.disconnecting &&
          next == VpnConnectionState.disconnected) {
        _markDisconnected();
      }
    });

    return AppScaffold(
      title: s.appName,
      currentIndex: 0,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            _ConnectButton(
              state: state,
              recentlyDisconnected: _recentlyDisconnected,
              label: _label(s, state),
              onTap: () => _toggle(state),
            ),
            const SizedBox(height: 28),
            _StatGrid(
                stats: stats,
                strings: s,
                active: state == VpnConnectionState.connected),
          ],
        ),
      ),
    );
  }

  String _label(Strings s, VpnConnectionState state) {
    switch (state) {
      case VpnConnectionState.connected:
        return s.connected;
      case VpnConnectionState.connecting:
        return s.connecting;
      case VpnConnectionState.disconnecting:
        return s.disconnecting;
      case VpnConnectionState.disconnected:
        return s.disconnected;
    }
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({
    required this.state,
    required this.recentlyDisconnected,
    required this.label,
    required this.onTap,
  });

  final VpnConnectionState state;
  final bool recentlyDisconnected;
  final String label;
  final VoidCallback onTap;

  Color get _color {
    switch (state) {
      case VpnConnectionState.connected:
        return const Color(0xFF2E7D32);
      case VpnConnectionState.connecting:
      case VpnConnectionState.disconnecting:
        return const Color(0xFFF9A825);
      case VpnConnectionState.disconnected:
        return recentlyDisconnected
            ? const Color(0xFFC62828)
            : const Color(0xFF1565C0);
    }
  }

  bool get _busy =>
      state == VpnConnectionState.connecting ||
      state == VpnConnectionState.disconnecting;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: _busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _color.withValues(alpha: 0.35),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_busy)
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              else
                const Icon(Icons.power_settings_new,
                    size: 56, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.stats,
    required this.strings,
    required this.active,
  });

  final VpnStats stats;
  final Strings strings;
  final bool active;

  static String formatDuration(Duration d) {
    final String h = d.inHours.toString().padLeft(2, '0');
    final String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  static String formatBytes(int bytes, {bool perSecond = false}) {
    const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final String text =
        '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
    return perSecond ? '$text/s' : text;
  }

  @override
  Widget build(BuildContext context) {
    const String dash = '—';
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: <Widget>[
        _StatCard(
          icon: Icons.timer_outlined,
          title: strings.duration,
          value: active ? formatDuration(stats.duration) : dash,
        ),
        _StatCard(
          icon: Icons.network_ping,
          title: strings.ping,
          value: stats.pingMs == null ? dash : '${stats.pingMs} ms',
        ),
        _StatCard(
          icon: Icons.download_outlined,
          title: strings.download,
          value:
              active ? formatBytes(stats.downloadBps, perSecond: true) : dash,
        ),
        _StatCard(
          icon: Icons.upload_outlined,
          title: strings.upload,
          value: active ? formatBytes(stats.uploadBps, perSecond: true) : dash,
        ),
        _StatCard(
          icon: Icons.public,
          title: strings.location,
          value: stats.location ?? strings.unknown,
        ),
        _StatCard(
          icon: Icons.data_usage,
          title: strings.totalUsage,
          value: formatBytes(stats.totalDownload + stats.totalUpload),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
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
                  title,
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
