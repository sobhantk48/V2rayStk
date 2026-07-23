import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.currentIndex,
    required this.body,
  });

  final String title;
  final int currentIndex;
  final Widget body;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: body,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (int index) => _onTap(context, index),
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
