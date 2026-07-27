import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/strings.dart';
import '../data/admin_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final Strings strings = Strings.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final bool ok = await AdminService.unlock(_passwordController.text);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (ok) {
      context.go('/admin/panel');
    } else {
      setState(() => _error = strings.wrongPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Strings strings = Strings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.adminPanel)),
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  strings.adminLoginHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: strings.password,
                    errorText: _error,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscure
                          ? strings.showPassword
                          : strings.hidePassword,
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(strings.login),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/settings'),
                  child: Text(strings.back),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
