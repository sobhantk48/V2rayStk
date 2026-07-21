import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../services/profile_service.dart';
import '../settings/settings_page.dart';

class UserHomePage extends ConsumerStatefulWidget {
  const UserHomePage({super.key});

  @override
  ConsumerState<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends ConsumerState<UserHomePage> {
  bool _connecting = false;

  Future<void> _toggleConnection() async {
    final selected = await ref.read(selectedProfileProvider.future);
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('no_profile_warn'.tr()),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final isConnected = ref.read(connectionStatusProvider);
    if (isConnected) {
      ref.read(connectionStatusProvider.notifier).state = false;
      return;
    }

    setState(() => _connecting = true);
    await Future.delayed(const Duration(milliseconds: 900)); // mock
    if (mounted) {
      ref.read(connectionStatusProvider.notifier).state = true;
      setState(() => _connecting = false);
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

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(connectionStatusProvider);
    final selectedAsync = ref.watch(selectedProfileProvider);

    final statusColor = isConnected ? AppTheme.success : AppTheme.primary;
    final statusText = isConnected ? 'connected'.tr() : 'disconnected'.tr();
    final buttonText = _connecting
        ? 'connecting'.tr()
        : (isConnected ? 'disconnect'.tr() : 'connect'.tr());

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

            // Status + Power Button
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
              onTap: _connecting ? null : _toggleConnection,
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
                    Icon(
                      isConnected ? Icons.check_rounded : Icons.power_settings_new_rounded,
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
                  _statCard('ping'.tr(), isConnected ? '42' : '--', 'ms'.tr()),
                  const SizedBox(width: 12),
                  _statCard('download'.tr(), isConnected ? '12.4' : '--', 'mbps'.tr()),
                  const SizedBox(width: 12),
                  _statCard('upload'.tr(), isConnected ? '3.1' : '--', 'mbps'.tr()),
                ],
              ),
            ),

            const Spacer(),

            // Profile Selector Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Material(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _showProfileSelector,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.dns_rounded, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: selectedAsync.when(
                            data: (p) => Text(
                              p?.name ?? 'select_profile'.tr(),
                              style: TextStyle(
                                color: p != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            loading: () => Text('...'),
                            error: (_, __) => Text('select_profile'.tr()),
                          ),
                        ),
                        const Icon(Icons.chevron_left, color: AppTheme.primary),
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
