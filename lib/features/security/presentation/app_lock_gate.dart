import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../settings/application/app_settings.dart';

/// Blocks the UI with a biometric prompt while [AppSettings.biometricLock] is on.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _unlocked = false;
  bool _prompting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Re-lock whenever the app leaves the foreground.
      if (mounted) {
        setState(() => _unlocked = false);
      }
    }
  }

  Future<void> _authenticate(bool isFa) async {
    if (_prompting) {
      return;
    }
    setState(() {
      _prompting = true;
      _error = null;
    });

    bool ok = false;
    String? failure;
    try {
      ok = await _auth.authenticate(
        localizedReason: isFa
            ? 'برای باز کردن برنامه هویت خود را تایید کنید'
            : 'Authenticate to unlock the app',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (error) {
      failure = error.toString();
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _prompting = false;
      _unlocked = ok;
      _error = ok ? null : failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool locked =
        ref.watch(appSettingsProvider).biometricLock && !_unlocked;

    if (!locked) {
      return widget.child;
    }

    final bool isFa = Localizations.localeOf(context).languageCode == 'fa';

    // Fire the prompt as soon as the lock screen is on screen.
    if (!_prompting && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _authenticate(isFa);
        }
      });
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                isFa ? 'برنامه قفل است' : 'App is locked',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isFa
                    ? 'با اثر انگشت، چهره یا رمز دستگاه باز کنید.'
                    : 'Unlock with fingerprint, face or device credential.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _prompting ? null : () => _authenticate(isFa),
                icon: const Icon(Icons.fingerprint),
                label: Text(isFa ? 'باز کردن' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
