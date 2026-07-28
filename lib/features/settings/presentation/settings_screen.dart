import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/locale_controller.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/strings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Strings strings = Strings.of(context);
    final Locale locale = ref.watch(localeControllerProvider);
    final bool isFa = locale.languageCode == 'fa';

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
            title: Text(strings.language),
            subtitle: Text(isFa ? 'فارسی' : 'English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageSheet(context, ref, locale),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: Text(strings.adminPanel),
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

  Future<void> _showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    Locale current,
  ) async {
    final Locale? picked = await showModalBottomSheet<Locale>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Language / زبان',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              RadioListTile<String>(
                value: 'fa',
                groupValue: current.languageCode,
                title: const Text('فارسی'),
                onChanged: (_) =>
                    Navigator.of(sheetContext).pop(const Locale('fa')),
              ),
              RadioListTile<String>(
                value: 'en',
                groupValue: current.languageCode,
                title: const Text('English'),
                onChanged: (_) =>
                    Navigator.of(sheetContext).pop(const Locale('en')),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      await ref.read(localeControllerProvider.notifier).setLocale(picked);
    }
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
