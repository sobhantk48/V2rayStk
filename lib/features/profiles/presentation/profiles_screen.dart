import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Profiles',
      currentIndex: 1,
      body: Center(
        child: Text('Profiles module will be implemented in phase 1.'),
      ),
    );
  }
}
