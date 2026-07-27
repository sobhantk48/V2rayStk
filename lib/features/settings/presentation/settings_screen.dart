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
          const _SectionHeader(title: 'عیب‌یابی / Diagnostics'),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('لاگ برنامه'),
            subtitle: const Text('App logs'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/logs'),
          ),
          ListTile(
            leading: const Icon(Icons.terminal),
            title: const Text('لاگ نیتیو (هسته sing-box)'),
            subtitle: const Text('Native logcat — errors from libbox'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.push('/native-logs'),
          ),
          const Divider(height: 24),
          const _SectionHeader(title: 'عمومی / General'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('نسخه'),
            subtitle: Text('V2ray Stk'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
