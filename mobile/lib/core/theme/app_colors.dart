import 'package:flutter/material.dart';

/// Fynexa brand palette — a premium, banking-grade indigo system that mirrors
/// the web app and works in both light and dark themes.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF4F46E5); // indigo-600
  static const Color primaryBright = Color(0xFF6366F1); // indigo-500
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color accent = Color(0xFF8B5CF6); // violet

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color successDark = Color(0xFF16A34A);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF0EA5E9);

  // Category accents
  static const List<Color> palette = [
    Color(0xFF6366F1),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
    Color(0xFFA855F7),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFF84CC16),
    Color(0xFFF97316),
  ];

  // Light theme
  static const Color lightBg = Color(0xFFF7F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF1F3F9);
  static const Color lightBorder = Color(0xFFE5E7EF);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);

  // Dark theme (deep navy — the sidebar look from the web app)
  static const Color darkBg = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF121A2E);
  static const Color darkSurfaceAlt = Color(0xFF1B2540);
  static const Color darkBorder = Color(0xFF26314E);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );

  /// For figures that are an asset rather than a cost — money lent out and
  /// still owed to the user. Same weight as the brand gradient so the two read
  /// as siblings, not as a warning.
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
  );

  static Color hexToColor(String? hex, [Color fallback = primaryBright]) {
    if (hex == null || hex.isEmpty) return fallback;
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? fallback : Color(parsed);
  }
}
