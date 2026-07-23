import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class V2rayStkApp extends StatelessWidget {
  const V2rayStkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'V2ray Stk',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
