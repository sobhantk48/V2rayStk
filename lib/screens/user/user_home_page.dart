import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../settings/settings_page.dart';
import '../admin/admin_login_page.dart';

class UserHomePage extends ConsumerWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionStatusProvider);
    final selectedAsync = ref.watch(selectedProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // AppBar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppTheme.primary),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                  Text(
                    'app_name'.tr(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),

              const Spacer(flex: 1),

              // Status text
              Text(
                isConnected ? 'connected'.tr() : 'disconnected'.tr(),
                style: TextStyle(
                  color: isConnected ? AppTheme.success : AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 30),

              // Big Connect Button
              GestureDetector(
                onTap: () {
                  ref.read(connectionStatusProvider.notifier).state = !isConnected;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.bg,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? AppTheme.success : AppTheme.primary)
                            .withOpacity(0.45),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                    border: Border.all(
                      color: isConnected ? AppTheme.success : AppTheme.primary,
                      width: 4,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isConnected ? Icons.check_rounded : Icons.power_settings_new_rounded,
                        size: 64,
                        color: isConnected ? AppTheme.success : AppTheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isConnected ? 'disconnect'.tr() : 'connect'.tr(),
                        style: TextStyle(
                          color: isConnected ? AppTheme.success : AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Stats
              Row(
                children: [
                  _statCard('upload'.tr(), isConnected ? '3.1' : '--', 'MB/s'),
                  const SizedBox(width: 12),
                  _statCard('download'.tr(), isConnected ? '12.4' : '--', 'MB/s'),
                  const SizedBox(width: 12),
                  _statCard('ping'.tr(), isConnected ? '42' : '--', 'ms'),
                ],
              ),

              const Spacer(flex: 1),

              // Selected Profile
              selectedAsync.when(
                data: (profile) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A3A55)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dns_rounded, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          profile?.name ?? 'select_profile'.tr(),
                          style: const TextStyle(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(unit, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
