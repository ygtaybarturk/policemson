// lib/theme/app_colors.dart – Unified Design System (Light & Dark Mode)
import 'package:flutter/material.dart';

// ── Ana renkler ──────────────────────────────────────
const kPrimary      = Color(0xFF1B4FD8);
const kPrimaryLight = Color(0xFF4F7BF7);
const kPrimaryGlow  = Color(0x1A1B4FD8);

// ── LIGHT MODE RENK PALETİ ──────────────────────────
const kBg           = Color(0xFFF4F6FD);
const kBgCard       = Color(0xFFFFFFFF);
const kBgCard2      = Color(0xFFF0F3FB);

const kText         = Color(0xFF0B1437);
const kTextSub      = Color(0xFF7A87AD);
const kTextHint     = Color(0xFFB2BEDA);

const kBorder       = Color(0xFFE6ECFB);
const kDivider      = Color(0xFFF0F3FB);

const kSuccess      = Color(0xFF00B96B);
const kWarn         = Color(0xFFFF8800);
const kDanger       = Color(0xFFFF3B3B);
const kDangerContainer  = Color(0xFFFFDAD6);

const kGlass        = Color(0xE8FFFFFF);

// ── DARK MODE RENK PALETİ ──────────────────────────
const kBgDark       = Color(0xFF111827);      // Ana arka plan
const kBgCardDark   = Color(0xFF1F2937);      // Kart arka plan
const kBgCard2Dark  = Color(0xFF374151);      // İkincil kart arka plan

const kTextDark     = Color(0xFFE5E7EB);      // Ana yazı rengi
const kTextSubDark  = Color(0xFF9CA3AF);      // Alt yazı rengi
const kTextHintDark = Color(0xFF6B7280);      // İpucu yazı rengi

const kBorderDark   = Color(0xFF4B5563);      // Border rengi
const kDividerDark  = Color(0xFF374151);      // Divider rengi

const kGlassDark    = Color(0xE81F2937);      // Glassmorphism dark

// ── Durum renkleri (dark mode'de aynı) ───────────────
const kSuccessDark  = Color(0xFF10B981);      // Yeşil (biraz daha açık)
const kWarnDark     = Color(0xFFF59E0B);      // Turuncu (biraz daha açık)
const kDangerDark   = Color(0xFFEF4444);      // Kırmızı (biraz daha açık)

// ── Theme Sınıfı ──────────────────────────────────────
class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        primary: kPrimary,
        brightness: Brightness.light,
        surface: kBg,
        surfaceContainerHighest: kBgCard2,
      ),
      scaffoldBackgroundColor: kBg,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: kBgCard,
        foregroundColor: kText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: kText,
        ),
      ),
      cardTheme: CardThemeData(
        color: kBgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kBgCard2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: kTextSub),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(color: kDivider, thickness: 1),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        primary: kPrimary,
        brightness: Brightness.dark,
        surface: kBgDark,
        surfaceContainerHighest: kBgCard2Dark,
      ),
      scaffoldBackgroundColor: kBgDark,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: kBgCardDark,
        foregroundColor: kTextDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: kTextDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: kBgCardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kBgCard2Dark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kBorderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: kTextSubDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(color: kDividerDark, thickness: 1),
    );
  }
}

// ── Extension (context.bgCard vb. – eski ekranlarla uyum) ─────
extension AppColors on BuildContext {
  Color get bgScaffold       => kBg;
  Color get bgCard           => kBgCard;
  Color get bgCard2          => kBgCard2;
  Color get bgSurface        => kBgCard2;
  Color get textMain         => kText;
  Color get textSub          => kTextSub;
  Color get border           => kBorder;
  Color get primary          => kPrimary;
  Color get primaryContainer => const Color(0xFFDDE6FF);
}
