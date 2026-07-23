import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/profiles/presentation/profiles_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/subscriptions/presentation/subscriptions_screen.dart';

class V2RayStkApp extends StatelessWidget {
  V2RayStkApp({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/profiles',
        builder: (BuildContext context, GoRouterState state) {
          return const ProfilesScreen();
        },
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (BuildContext context, GoRouterState state) {
          return const SubscriptionsScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'V2ray Stk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
    );
  }
}
