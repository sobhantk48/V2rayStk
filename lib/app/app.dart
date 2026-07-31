import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/security/presentation/app_lock_gate.dart';
import 'locale_controller.dart';
import 'router.dart';
import 'theme.dart';

class V2rayStkApp extends ConsumerWidget {
  const V2rayStkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Locale? locale = ref.watch(localeControllerProvider);

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
        return AppLockGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
