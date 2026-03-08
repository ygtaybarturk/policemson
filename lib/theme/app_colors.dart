// lib/theme/app_colors.dart – Light Mode Renk Sistemi
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

// ── Theme Sınıfı ──────────────────────────────────────
class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: kPrimary,
        secondary: kWarn,
        error: kDanger,
      ),
      scaffoldBackgroundColor: kBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: kBgCard,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
          color: kText,
        ),
        iconTheme: IconThemeData(color: kPrimary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: kPrimary,
        unselectedLabelColor: kTextSub,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: kPrimary, width: 2.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimary,
          side: const BorderSide(color: kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: kTextHint, fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: kText, fontWeight: FontWeight.w600),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: kText,
          letterSpacing: -0.8,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: kText,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: kText,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: kText,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: kText,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: kText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: kTextSub,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: kText,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: kText,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: kTextSub,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kBgCard2,
        labelStyle: const TextStyle(color: kText, fontWeight: FontWeight.w600),
        side: const BorderSide(color: kBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: kDivider,
      dividerTheme: const DividerThemeData(
        color: kDivider,
        thickness: 0.8,
        space: 0,
      ),
      cardTheme: CardThemeData(
        color: kBgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorder, width: 0.8),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kText.withOpacity(0.9),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kGlass,
        selectedItemColor: kPrimary,
        unselectedItemColor: kTextHint,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
