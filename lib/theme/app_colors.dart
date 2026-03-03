// lib/theme/app_colors.dart – v5 (gece modu kaldırıldı, sabit sigorta mavisi)
import 'package:flutter/material.dart';

extension AppColors on BuildContext {
  // Arka planlar – sadece açık mod
  Color get bgScaffold => const Color(0xFFF0F5FF);
  Color get bgCard     => Colors.white;
  Color get bgCard2    => const Color(0xFFF5F8FF);
  Color get bgSurface  => const Color(0xFFEEF3FF);

  // Metinler
  Color get textMain => const Color(0xFF1A1A2E);
  Color get textSub  => const Color(0xFF7A8AAA);

  // Kenarlık
  Color get border => const Color(0xFFE8EEFF);

  // Vurgu – sigorta mavisi
  Color get primary          => const Color(0xFF1565C0);
  Color get primaryContainer => const Color(0xFFDBEAFE);
}
