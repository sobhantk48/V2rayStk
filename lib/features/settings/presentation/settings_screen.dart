import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Settings',
      currentIndex: 3,
      body: Center(
        child: Text('Settings module will be implemented in phase 1.'),
      ),
    );
  }
}
