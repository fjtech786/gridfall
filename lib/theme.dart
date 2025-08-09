
import 'package:flutter/material.dart';

class GFColors {
  static const bg = Color(0xFF0D0F12);
  static const panel = Color(0xFF151923);
  static const grid = Color(0xFF1B2130);
  static const border = Color(0x33FFFFFF);
  static const cyan = Color(0xFF00E5FF);
  static const pink = Color(0xFFFF3DA3);
  static const lime = Color(0xFF7DFF6B);
  static const amber = Color(0xFFFFC857);
  static const purple = Color(0xFFB45CFF);
  static const blue = Color(0xFF5AA9FF);
  static const orange = Color(0xFFFF8C42);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: GFColors.blue,
    brightness: Brightness.dark,
    surface: GFColors.panel,
    background: GFColors.bg,
  );
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: GFColors.bg,
    cardColor: GFColors.panel,
    appBarTheme: const AppBarTheme(
      backgroundColor: GFColors.panel,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    ),
    useMaterial3: true,
  );
}
