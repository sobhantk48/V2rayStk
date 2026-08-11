import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/presentation/admin_login_screen.dart';
import '../features/admin/presentation/admin_panel_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/groups/presentation/groups_manage_screen.dart';
import '../features/logs/presentation/native_log_screen.dart';
import '../features/profiles/presentation/profiles_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/speedtest/presentation/speed_test_screen.dart';
import '../features/stats/presentation/stats_screen.dart';
import '../features/split_tunnel/presentation/split_tunnel_screen.dart';
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
    GoRoute(
      path: '/groups',
      builder: (BuildContext context, GoRouterState state) {
        return const GroupsManageScreen();
      },
    ),
    GoRoute(
      path: '/stats',
      builder: (BuildContext context, GoRouterState state) {
        return const StatsScreen();
      },
    ),
    GoRoute(
      path: '/speedtest',
      builder: (BuildContext context, GoRouterState state) {
        return const SpeedTestScreen();
      },
    ),
    GoRoute(
      path: '/logs',
      builder: (BuildContext context, GoRouterState state) {
        return const NativeLogScreen();
      },
    ),
    GoRoute(
      path: '/split-tunnel',
      builder: (BuildContext context, GoRouterState state) {
        return const SplitTunnelScreen();
      },
    ),
    GoRoute(
      path: '/admin',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminLoginScreen();
      },
    ),
    GoRoute(
      path: '/admin/panel',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminPanelScreen();
      },
    ),
  ],
);
