import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'models/profile.dart';
import 'screens/user/user_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EasyLocalization.ensureInitialized();
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ProfileAdapter());
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bg,
  ));

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('fa'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('fa'),
      startLocale: const Locale('fa'),
      child: const ProviderScope(
        child: V2rayStkApp(),
      ),
    ),
  );
}

class V2rayStkApp extends StatelessWidget {
  const V2rayStkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V2ray Stk',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const UserHomePage(),
    );
  }
}
