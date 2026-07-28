import 'package:flutter/material.dart';

/// رنگ‌های وضعیت اتصال — دکمه اتصال از همین‌ها استفاده می‌کند.
/// Connection state colors used by the connect button.
class VpnStatusColors {
  const VpnStatusColors._();

  /// حالت عادی / قطع‌شده اولیه
  static const Color idle = Color(0xFF1565C0);

  /// در حال اتصال
  static const Color connecting = Color(0xFFF9A825);

  /// وصل شده
  static const Color connected = Color(0xFF2E7D32);

  /// قطع شده / خطا
  static const Color disconnected = Color(0xFFC62828);
}

const Color _seed = Color(0xFF1565C0);

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: _seed);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    appBarTheme: const AppBarTheme(centerTitle: true),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  );
}

ThemeData buildAppDarkTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(centerTitle: true),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1),
  );
}
