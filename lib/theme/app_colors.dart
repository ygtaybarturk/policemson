// lib/theme/app_colors.dart – Unified Design System
import 'package:flutter/material.dart';

// ── Sabit renkler (kPrimary vb. ile direkt kullanım) ──────────
const kPrimary      = Color(0xFF1B4FD8);
const kPrimaryLight = Color(0xFF4F7BF7);
const kPrimaryGlow  = Color(0x1A1B4FD8);

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
