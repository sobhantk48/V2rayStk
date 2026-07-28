import 'package:flutter/material.dart';

/// رنگ‌های اختصاصی دکمه اتصال و نشانگر وضعیت.
/// آبی = حالت عادی، نارنجی = در حال کار، سبز = متصل، سرخ = قطع‌شده.
@immutable
class VpnStatusColors extends ThemeExtension<VpnStatusColors> {
  const VpnStatusColors({
    required this.idle,
    required this.connecting,
    required this.connected,
    required this.disconnected,
  });

  final Color idle;
  final Color connecting;
  final Color connected;
  final Color disconnected;

  static const VpnStatusColors light = VpnStatusColors(
    idle: Color(0xFF1E6FE0),
    connecting: Color(0xFFF29D38),
    connected: Color(0xFF1FA45B),
    disconnected: Color(0xFFD8393B),
  );

  static const VpnStatusColors dark = VpnStatusColors(
    idle: Color(0xFF4C93F5),
    connecting: Color(0xFFFFB65C),
    connected: Color(0xFF3ECB7C),
    disconnected: Color(0xFFF25E60),
  );

  @override
  VpnStatusColors copyWith({
    Color? idle,
    Color? connecting,
    Color? connected,
    Color? disconnected,
  }) {
    return VpnStatusColors(
      idle: idle ?? this.idle,
      connecting: connecting ?? this.connecting,
      connected: connected ?? this.connected,
      disconnected: disconnected ?? this.disconnected,
    );
  }

  @override
  VpnStatusColors lerp(ThemeExtension<VpnStatusColors>? other, double t) {
    if (other is! VpnStatusColors) {
      return this;
    }
    return VpnStatusColors(
      idle: Color.lerp(idle, other.idle, t)!,
      connecting: Color.lerp(connecting, other.connecting, t)!,
      connected: Color.lerp(connected, other.connected, t)!,
      disconnected: Color.lerp(disconnected, other.disconnected, t)!,
    );
  }

  /// دسترسی امن از هر جای UI؛ اگر extension ثبت نشده باشد fallback می‌دهد.
  static VpnStatusColors of(BuildContext context) {
    final VpnStatusColors? ext =
        Theme.of(context).extension<VpnStatusColors>();
    if (ext != null) {
      return ext;
    }
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}

const Color _seedColor = Color(0xFF1E6FE0);

ThemeData buildAppTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: _seedColor);
  return _base(scheme, VpnStatusColors.light);
}

ThemeData buildAppDarkTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: Brightness.dark,
  );
  return _base(scheme, VpnStatusColors.dark);
}

ThemeData _base(ColorScheme scheme, VpnStatusColors statusColors) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    extensions: <ThemeExtension<dynamic>>[statusColors],
  );
}
