import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_controller.dart';
import 'router.dart';
import 'theme.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../core/platform/haptics.dart';
import '../features/settings/application/app_settings.dart';

class V2rayStkApp extends ConsumerWidget {
  const V2rayStkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hapticOn = ref.watch(appSettingsProvider).hapticEnabled;
    Haptics.enabled = hapticOn;

    final Locale locale = ref.watch(localeControllerProvider);
    final TextDirection direction =
        locale.languageCode == 'fa' ? TextDirection.rtl : TextDirection.ltr;

    return MaterialApp.router(
      title: 'V2ray Stk',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      builder: (BuildContext context, Widget? child) {
        return AppLockGate(
          child: Directionality(
          textDirection: direction,
          child: child ?? const SizedBox.shrink(),
        ),
        );
      },
    );
  }
}