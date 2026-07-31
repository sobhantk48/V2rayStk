import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentIndex,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;

  /// اگر null باشد، نوار پایین نمایش داده نمی‌شود (صفحات فرعی مثل گروه‌ها).
  final int? currentIndex;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/profiles');
      case 2:
        context.go('/subscriptions');
      case 3:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final int? index = currentIndex;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: index == null
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (int i) => _onTap(context, i),
              destinations: const <Widget>[
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.dns_outlined),
                  selectedIcon: Icon(Icons.dns),
                  label: 'Profiles',
                ),
                NavigationDestination(
                  icon: Icon(Icons.subscriptions_outlined),
                  selectedIcon: Icon(Icons.subscriptions),
                  label: 'Subscriptions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}
