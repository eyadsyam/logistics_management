import 'package:flutter/material.dart';

/// Edita Food Industries — Official Brand Color Palette.
/// Warm orange-first design — no red anywhere in the UI.
/// Light theme with warm orange, deep brown, and clean whites.
class AppColors {
  AppColors._();

  // ── Brand Primaries ──
  static const Color primary = Color(0xFFFF8611); // Edita Orange (West Side)
  static const Color primaryDark = Color(0xFFD7802C); // Brandy Punch
  static const Color primaryLight = Color(0xFFFCBD6B); // Koromiko / Gold
  static const Color accent = Color(0xFFE67E22); // Deep Orange accent
  static const Color accentLight = Color(0xFFF5A623); // Warm Amber

  // ── Background & Surfaces (Light Theme) ──
  static const Color backgroundLight = Color(0xFFF1F3F5); // Athens Gray
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White
  static const Color cardLight = Color(0xFFFFFBF5); // Warm White
  static const Color cardElevated = Color(0xFFF0EEE9); // Pampas / Cream

  // ── Edita Earth Tones ──
  static const Color brown = Color(0xFF865135); // Potters Clay
  static const Color brownDark = Color(0xFF381E11); // Sambuca
  static const Color brownMedium = Color(0xFF645440); // Kabul
  static const Color greenDark = Color(0xFF102111); // Racing Green

  // ── Glass / Frosted UI ──
  static const Color glassBackground = Color(0x0A000000); // 4% black
  static const Color glassBorder = Color(0x14000000); // 8% black
  static const Color glassHighlight = Color(0x08000000); // 3% black

  // ── Text ──
  static const Color textPrimary = Color(0xFF191919); // Cod Gray
  static const Color textSecondary = Color(0xFF645440); // Kabul
  static const Color textHint = Color(0xFF959595); // Dusty Gray

  // ── Status Colors ──
  static const Color success = Color(0xFF388E3C); // Green
  static const Color warning = Color(0xFFFF8611); // Edita Orange
  static const Color error = Color(0xFFD7802C); // Brandy Punch (was red)
  static const Color info = Color(0xFF1976D2); // Blue

  // ── Shipment Status ──
  static const Color statusPending = Color(0xFFFF8611); // Orange
  static const Color statusAccepted = Color(0xFF1976D2); // Blue
  static const Color statusInProgress = Color(0xFFDA9144); // Raw Sienna
  static const Color statusCompleted = Color(0xFF388E3C); // Green
  static const Color statusCancelled = Color(0xFF865135); // Brown (was red)

  // ── Gradients ──
  static const List<Color> primaryGradient = [
    Color(0xFFFF8611), // West Side Orange
    Color(0xFFD7802C), // Brandy Punch
  ];

  static const List<Color> accentGradient = [
    Color(0xFFE67E22), // Deep Orange
    Color(0xFFD7802C), // Brandy Punch
  ];

  static const List<Color> warmGradient = [
    Color(0xFFFCBD6B), // Koromiko
    Color(0xFFFF8611), // West Side
  ];

  static const List<Color> backgroundGradient = [
    Color(0xFFF1F3F5), // Athens Gray
    Color(0xFFF0EEE9), // Pampas
  ];

  static const List<Color> cardGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFF0EEE9),
  ];

  // ── Backward compat aliases used by old screens ──
  // These map old dark-theme names to light-theme equivalents
  static const Color backgroundDark = backgroundLight;
  static const Color surfaceDark = surfaceLight;
  static const Color cardDark = cardLight;
}
