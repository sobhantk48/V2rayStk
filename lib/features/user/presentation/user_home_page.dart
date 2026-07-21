import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

enum ConnectionState { disconnected, connecting, connected }

final connectionStateProvider = StateProvider<ConnectionState>((ref) => ConnectionState.disconnected);

class UserHomePage extends ConsumerWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectionStateProvider);

    Color buttonColor;
    String buttonText;
    IconData buttonIcon;

    switch (state) {
      case ConnectionState.disconnected:
        buttonColor = AppTheme.idleBlue;
        buttonText = 'connect'.tr();
        buttonIcon = Icons.power_settings_new_rounded;
        break;
      case ConnectionState.connecting:
        buttonColor = AppTheme.primaryNeon;
        buttonText = 'connecting'.tr();
        buttonIcon = Icons.hourglass_top_rounded;
        break;
      case ConnectionState.connected:
        buttonColor = AppTheme.connectedGreen;
        buttonText = 'disconnect'.tr();
        buttonIcon = Icons.check_circle_rounded;
        break;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppBar ساده
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'app_name'.tr(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNeon,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppTheme.primaryNeon),
                    onPressed: () {
                      // بعداً پنل تنظیمات و ادمین
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

            // دکمه اتصال بزرگ مرکزی
            GestureDetector(
              onTap: () {
                final current = ref.read(connectionStateProvider);
                if (current == ConnectionState.disconnected) {
                  ref.read(connectionStateProvider.notifier).state = ConnectionState.connecting;
                  // شبیه‌سازی اتصال (بعداً واقعی با sing-box)
                  Future.delayed(const Duration(seconds: 2), () {
                    ref.read(connectionStateProvider.notifier).state = ConnectionState.connected;
                  });
                } else if (current == ConnectionState.connected) {
                  ref.read(connectionStateProvider.notifier).state = ConnectionState.disconnected;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: buttonColor.withOpacity(0.15),
                  border: Border.all(color: buttonColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(buttonIcon, size: 64, color: buttonColor),
                    const SizedBox(height: 8),
                    Text(
                      buttonText,
                      style: TextStyle(
                        color: buttonColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // کارت‌های آمار (فعلاً placeholder واقعی بعداً)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _StatCard(title: 'ping'.tr(), value: state == ConnectionState.connected ? '42 ms' : '--'),
                  const SizedBox(width: 12),
                  _StatCard(title: 'download'.tr(), value: state == ConnectionState.connected ? '12.4 MB/s' : '--'),
                  const SizedBox(width: 12),
                  _StatCard(title: 'upload'.tr(), value: state == ConnectionState.connected ? '3.1 MB/s' : '--'),
                ],
              ),
            ),

            const Spacer(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryNeon.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.primaryNeon,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
