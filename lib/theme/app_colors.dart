// lib/theme/app_colors.dart
// Tüm ekranlar bu extension'ı kullanır → gece/gündüz otomatik değişir
import 'package:flutter/material.dart';

extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // Arka planlar
  Color get bgScaffold => isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F5FF);
  Color get bgCard     => isDark ? const Color(0xFF161B27) : Colors.white;
  Color get bgCard2    => isDark ? const Color(0xFF1E2535) : const Color(0xFFF5F8FF);
  Color get bgSurface  => isDark ? const Color(0xFF1A2235) : const Color(0xFFEEF3FF);

  // Metinler
  Color get textMain => isDark ? const Color(0xFFE8EDF5) : const Color(0xFF1A1A2E);
  Color get textSub  => isDark ? const Color(0xFF8B97B0) : const Color(0xFF7A8AAA);

  // Kenarlık
  Color get border => isDark ? const Color(0xFF262E42) : const Color(0xFFE8EEFF);

  // Vurgu
  Color get primary          => isDark ? const Color(0xFF4A9EF5) : const Color(0xFF1565C0);
  Color get primaryContainer => isDark ? const Color(0xFF1A2E4A) : const Color(0xFFDBEAFE);
}
