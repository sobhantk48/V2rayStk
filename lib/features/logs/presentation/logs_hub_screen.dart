import 'package:flutter/material.dart';

import 'log_screen.dart';
import 'native_log_screen.dart';

/// میزبان دو نمای لاگ.
///
/// هر دو صفحه Scaffold و AppBar مستقل دارند، پس اینجا AppBar نمی‌گذاریم
/// و فقط با NavigationBar پایین بین آن‌ها جابه‌جا می‌شویم. IndexedStack
/// باعث می‌شود state هر تب (اسکرول، فیلتر، pause) با سوییچ از بین نرود.
class LogsHubScreen extends StatefulWidget {
  const LogsHubScreen({super.key});

  @override
  State<LogsHubScreen> createState() => _LogsHubScreenState();
}

class _LogsHubScreenState extends State<LogsHubScreen> {
  int _index = 0;

  bool _isFa(BuildContext context) {
    return Localizations.localeOf(context).languageCode == 'fa';
  }

  @override
  Widget build(BuildContext context) {
    final bool fa = _isFa(context);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          LogScreen(),
          NativeLogScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() => _index = value);
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.article_outlined),
            selectedIcon: const Icon(Icons.article),
            label: fa ? 'لاگ اپ' : 'App',
            tooltip: fa
                ? 'لاگ‌های ساختاریافته اپ با فیلتر و جست‌وجو'
                : 'Structured app logs with filter and search',
          ),
          NavigationDestination(
            icon: const Icon(Icons.terminal_outlined),
            selectedIcon: const Icon(Icons.terminal),
            label: fa ? 'سیستم' : 'System',
            tooltip: fa
                ? 'خروجی خام logcat اندروید'
                : 'Raw Android logcat output',
          ),
        ],
      ),
    );
  }
}
