import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:v2ray_stk/app/locale_controller.dart';
import 'package:v2ray_stk/core/widgets/app_scaffold.dart';
import 'package:v2ray_stk/features/settings/application/app_settings.dart';
import 'package:v2ray_stk/l10n/strings.dart';
import '../../../core/platform/haptics.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Strings strings = Strings.of(context);
    final Locale? currentLocale = ref.watch(localeControllerProvider);
    final AppSettings settings = ref.watch(appSettingsProvider);

    return AppScaffold(
      title: 'Settings',
      currentIndex: 3,
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          const _SectionHeader('Diagnostics / عیب‌یابی'),
          ListTile(
            leading: const Icon(Icons.terminal, color: Colors.greenAccent),
            title: const Text('Native Logs'),
            subtitle: const Text('لاگ‌های هسته sing-box (logcat)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/logs'),
          ),
          const Divider(height: 1),
          const _SectionHeader('General / عمومی'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language / زبان'),
            subtitle: Text(_localeLabel(currentLocale)),
            trailing: const Icon(Icons.keyboard_arrow_down),
            onTap: () => _pickLanguage(context, ref, currentLocale),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Lock / قفل بیومتریک'),
            subtitle: const Text('باز کردن اپ با اثر انگشت یا چهره'),
            value: settings.biometricLock,
            onChanged: (bool v) {
              Haptics.selection();
              ref.read(appSettingsProvider.notifier).setBiometricLock(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Haptic Feedback / بازخورد لمسی'),
            value: settings.hapticEnabled,
            onChanged: (bool v) {
              Haptics.enabled = v;
              Haptics.selection();
              ref.read(appSettingsProvider.notifier).setHaptic(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.call_split, color: Colors.tealAccent),
            title: const Text('Split Tunneling / تونل تفکیکی'),
            subtitle: const Text('انتخاب اپ‌های داخل یا خارج از VPN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/split-tunnel'),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: Text('${strings.adminPanel} / Admin Panel'),
            subtitle: const Text('تنظیمات پیشرفته و رمز عبور'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin'),
          ),
          const Divider(height: 1),
          const _SectionHeader('About / درباره'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('V2ray Stk'),
            subtitle: Text('Core: sing-box (libbox)'),
          ),
        ],
      ),
    );
  }

  static String _localeLabel(Locale? locale) {
    if (locale == null) return 'System / سیستم';
    if (locale.languageCode == 'fa') return 'فارسی';
    return 'English';
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    Locale? current,
  ) async {
    final String? code = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              const Text(
                'Language / زبان',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: current?.languageCode ?? 'system',
                onChanged: (String? v) => Navigator.pop(ctx, v),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'system',
                      title: Text('System / سیستم'),
                    ),
                    RadioListTile<String>(
                      value: 'fa',
                      title: Text('فارسی'),
                    ),
                    RadioListTile<String>(
                      value: 'en',
                      title: Text('English'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (code == null) return;
    final Locale? next = code == 'system' ? null : Locale(code);
    await ref.read(localeControllerProvider.notifier).setLocale(next!);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
