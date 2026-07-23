import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Dashboard',
      currentIndex: 0,
      body: Center(
        child: Text('Dashboard placeholder.'),
      ),
    );
  }
}
