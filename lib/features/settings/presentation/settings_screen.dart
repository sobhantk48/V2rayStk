import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          const ListTile(
            leading: Icon(Icons.language),
            title: Text('Language / زبان'),
            subtitle: Text('فارسی / English'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.admin_panel_settings),
            title: Text('Admin Panel / پنل ادمین'),
            subtitle: Text('تنظیمات پیشرفته و رمز عبور'),
            trailing: Icon(Icons.chevron_right),
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
