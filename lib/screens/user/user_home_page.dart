import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/vpn_provider.dart';
import '../../services/profile_service.dart';
import '../../services/vpn_bridge.dart';
import '../settings/settings_page.dart';

class UserHomePage extends ConsumerStatefulWidget {
  const UserHomePage({super.key});

  @override
  ConsumerState<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends ConsumerState<UserHomePage> {
  bool _busy = false;

  Future<void> _toggleConnection() async {
    if (_busy) return;

    final selected = await ref.read(selectedProfileProvider.future);
    if (selected == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_profile_warn'.tr()),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final event = ref.read(vpnEventProvider).valueOrNull;
    final isConnected = event?.isConnected ?? false;

    setState(() => _busy = true);

    try {
      final controller = ref.read(vpnControllerProvider);

      if (isConnected) {
        await controller.disconnect();
        ref.read(connectionStatusProvider.notifier).state = false;
        return;
      }

      final ok = await controller.connect(config: selected.config);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('vpn_permission_denied'.tr()),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }
      // Native EventChannel will flip UI to connected.
      ref.read(connectionStatusProvider.notifier).state = true;
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? e.code),
          backgroundColor: AppTheme.danger,
        ),
      );
      ref.read(connectionStatusProvider.notifier).state = false;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.danger,
        ),
      );
      ref.read(connectionStatusProvider.notifier).state = false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showProfileSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final async = ref.watch(profilesProvider);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textSecondary.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'select_profile'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  async.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'no_profiles'.tr(),
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        );
                      }
                      return Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final p = list[i];
                            return ListTile(
                              leading: Icon(
                                p.isSelected
                                    ? Icons.check_circle
                                    : Icons.dns_rounded,
                                color: p.isSelected
                                    ? AppTheme.success
                                    : AppTheme.primary,
                              ),
                              title: Text(p.name),
                              subtitle: Text(
                                p.config,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: p.isSelected
                                  ? const Icon(Icons.done, color: AppTheme.success)
                                  : null,
                              onTap: () async {
                                await ProfileService.select(p.id);
                                ref.invalidate(profilesProvider);
                                ref.invalidate(selectedProfileProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Text('$e'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    final digits = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
    return '${value.toStringAsFixed(digits)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final vpnAsync = ref.watch(vpnEventProvider);
    final vpnEvent = vpnAsync.valueOrNull;
    final selectedAsync = ref.watch(selectedProfileProvider);

    final isConnected = vpnEvent?.isConnected ?? false;
    final isConnecting =
        _busy || (vpnEvent?.isConnecting ?? false);

    final statusColor = isConnecting
        ? AppTheme.primary
        : (isConnected ? AppTheme.success : AppTheme.primary);

    final statusText = isConnecting
        ? 'connecting'.tr()
        : (isConnected ? 'connected'.tr() : 'disconnected'.tr());

    final buttonText = isConnecting
        ? 'connecting'.tr()
        : (isConnected ? 'disconnect'.tr() : 'connect'.tr());

    final uploadText =
        isConnected ? _formatBytes(vpnEvent?.upload ?? 0) : '--';
    final downloadText =
        isConnected ? _formatBytes(vpnEvent?.download ?? 0) : '--';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'app_name'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded, color: AppTheme.primary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                color: statusColor.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),

            GestureDetector(
              onTap: isConnecting ? null : _toggleConnection,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surface,
                  border: Border.all(color: statusColor, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.45),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isConnecting)
                      SizedBox(
                        width: 42,
                        height: 42,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: statusColor,
                        ),
                      )
                    else
                      Icon(
                        isConnected
                            ? Icons.check_rounded
                            : Icons.power_settings_new_rounded,
                        size: 52,
                        color: statusColor,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      buttonText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _statCard(
                    'ping'.tr(),
                    isConnected ? '—' : '--',
                    'ms'.tr(),
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    'download'.tr(),
                    downloadText,
                    isConnected ? '' : 'mbps'.tr(),
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    'upload'.tr(),
                    uploadText,
                    isConnected ? '' : 'mbps'.tr(),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Profile Selector Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _showProfileSelector,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.dns_rounded, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: selectedAsync.when(
                            data: (p) => Text(
                              p?.name ?? 'select_profile'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p == null
                                    ? AppTheme.textSecondary
                                    : AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            loading: () => Text(
                              '…',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            error: (e, _) => Text('$e'),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              unit.isEmpty ? value : '$value $unit',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
