import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/strings.dart';
import 'screens/admin_panel.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';

class V2rayStkApp extends ConsumerWidget {
  const V2rayStkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appStateProvider).locale;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      title: 'V2ray Stk',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomeScreen(),
      routes: {'/admin': (_) => const AdminPanel()},
      onGenerateTitle: (_) => Strings.of(locale).appName,
    );
  }
}
