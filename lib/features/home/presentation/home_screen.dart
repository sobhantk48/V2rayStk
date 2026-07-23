import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Home',
      currentIndex: 0,
      body: Center(
        child: Text('V2ray Stk is ready for phase 2.'),
      ),
    );
  }
}
