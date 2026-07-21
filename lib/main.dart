import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/user/presentation/user_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();

  // باز کردن باکس‌های لازم
  await Hive.openBox('settings');
  await Hive.openBox('profiles');
  await Hive.openBox('admin');

  // رمز پیش‌فرض ادمین
  final adminBox = Hive.box('admin');
  if (!adminBox.containsKey('password')) {
    await adminBox.put('password', 'admin');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A1628),
    ),
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('fa')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fa'),
      startLocale: const Locale('fa'),
      child: const ProviderScope(
        child: V2rayStkApp(),
      ),
    ),
  );
}

class V2rayStkApp extends ConsumerWidget {
  const V2rayStkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'V2ray Stk',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.darkNeonTheme,
      home: const UserHomePage(),
    );
  }
}
