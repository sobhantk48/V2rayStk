import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/profiles/presentation/profiles_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/subscriptions/presentation/subscriptions_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const DashboardScreen();
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
