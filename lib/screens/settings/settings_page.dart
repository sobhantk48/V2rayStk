import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_theme.dart';
import '../admin/admin_login_page.dart';
import '../../services/auth_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (newPass.isEmpty || newPass.length < 4) {
      _showSnack('رمز جدید باید حداقل ۴ کاراکتر باشد', isError: true);
      return;
    }
    if (newPass != confirm) {
      _showSnack('تکرار رمز مطابقت ندارد', isError: true);
      return;
    }

    final ok = await AuthService.checkPassword(current);
    if (!ok) {
      _showSnack('wrong_password'.tr(), isError: true);
      return;
    }

    await AuthService.changePassword(newPass);
    _currentCtrl.clear();
    _newCtrl.clear();
    _confirmCtrl.clear();
    if (mounted) {
      Navigator.pop(context);
      _showSnack('password_changed'.tr());
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('change_password'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'current_password'.tr()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'new_password'.tr()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(labelText: 'confirm_password'.tr()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings'.tr()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.language, color: AppTheme.primary),
              title: Text('language'.tr()),
              subtitle: Text(
                context.locale.languageCode == 'fa'
                    ? 'persian'.tr()
                    : 'english'.tr(),
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                final newLocale = context.locale.languageCode == 'fa'
                    ? const Locale('en')
                    : const Locale('fa');
                context.setLocale(newLocale);
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: AppTheme.primary),
              title: Text('admin_panel'.tr()),
              trailing: const Icon(Icons.chevron_left),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_reset, color: AppTheme.primary),
              title: Text('change_password'.tr()),
              trailing: const Icon(Icons.chevron_left),
              onTap: _showChangePasswordDialog,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${'version'.tr()} 1.0.0 • V2ray Stk',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
