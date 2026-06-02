import 'package:flutter/material.dart';

/// Centralized design tokens for the app.
/// Edit values here to change the look across the entire app.
///
/// Usage:
///   - Colors:   `AppColors.success`, `AppColors.danger`, ...
///   - Spacing:  `AppSpacing.md`, `AppSpacing.lg`, ...
///   - Radii:    `AppRadius.card`, `AppRadius.button`, ...
///   - Type:     `AppText.titleLg`, `AppText.bodyMd`, ...
///   - Icons:    `AppIconSizes.sm`, `AppIconSizes.md`, ...

// ─── Brand & status colors ───────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand (light + dark variants)
  static const Color brandPrimary = Color(0xFF5C6BC0); // indigo (light)
  static const Color brandPrimaryDark = Color(0xFF7C8AE3); // brighter indigo (dark mode)
  static const Color brandSecondary = Color(0xFF26A69A); // teal

  // Status (availability) — used everywhere
  static const Color available = Color(0xFF26A69A); // solid green/teal
  static const Color likely = Color(0xFF66BB6A); // light green
  static const Color maybe = Color(0xFFFFB74D); // amber
  static const Color unavailable = Color(0xFFEF5350); // red

  // Semantic accents
  static const Color success = available;
  static const Color warning = maybe;
  static const Color danger = unavailable;
  static const Color info = Color(0xFF42A5F5); // blue
  static const Color accent = Color(0xFFFF7043); // orange
  static const Color purple = Color(0xFFAB47BC);

  // ─── Light theme surfaces ────────────────────────────────────
  static const Color lightBg = Color(0xFFF6F7FB);
  static const Color lightSurface = Colors.white;
  static const Color lightOnSurface = Color(0xFF1A1A2E);
  static const Color lightSurfaceVariant = Color(0xFFF0F1F8);
  static const Color lightUnselected = Color(0xFFB0B8C9);

  // ─── Dark theme surfaces ─────────────────────────────────────
  // Tuned for visibility — cards pop against background.
  static const Color darkBg = Color(0xFF0F0F17);
  static const Color darkSurface = Color(0xFF22222C);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkSurfaceVariant = Color(0xFF2E2E3A);
  static const Color darkBottomNav = Color(0xFF161622);
  static const Color darkUnselected = Color(0xFF666670);

  // Avatar palette — used to pick a stable color from a name's first char
  static const List<Color> avatarPalette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFFF7043),
    Color(0xFF42A5F5),
    Color(0xFFAB47BC),
    Color(0xFF66BB6A),
    Color(0xFFFFB74D),
    Color(0xFF7E57C2),
  ];

  /// Stable color from a key (e.g. a user's display name).
  static Color avatarFor(String key) {
    if (key.isEmpty) return avatarPalette[0];
    return avatarPalette[key.codeUnitAt(0) % avatarPalette.length];
  }
}

// ─── Spacing scale ───────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 14;
  static const double xxl = 16;
  static const double x3 = 20;
  static const double x4 = 24;
  static const double x5 = 32;
  static const double x6 = 40;
  static const double x7 = 48;
}

// ─── Border radii ────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double button = 14;
  static const double card = 16;
  static const double sheet = 20;
  static const double pill = 999;
}

// ─── Typography ──────────────────────────────────────────────────────────────

class AppText {
  AppText._();

  // Display
  static const titleXl = TextStyle(
      fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5);
  static const titleLg = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const titleMd = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);
  static const titleSm = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  // Body
  static const bodyLg = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
  static const bodyMd = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  static const bodySm = TextStyle(fontSize: 14);
  static const bodyXs = TextStyle(fontSize: 13);

  // Labels (small uppercase-ish meta text)
  static const labelLg = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2);
  static const labelMd = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
  static const labelSm = TextStyle(fontSize: 11, fontWeight: FontWeight.w500);

  // Numbers & code (e.g. invite code)
  static const codeLg = TextStyle(
      fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 6);
}

// ─── Icon sizes ──────────────────────────────────────────────────────────────

class AppIconSize {
  AppIconSize._();

  static const double xs = 13;
  static const double sm = 16;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
}

// ─── Opacity tokens ──────────────────────────────────────────────────────────

class AppOpacity {
  AppOpacity._();

  /// Faint background tint (e.g. status pill)
  static const double tintFaint = 0.06;
  static const double tintLight = 0.12;
  static const double tintMedium = 0.18;
  static const double tintStrong = 0.30;

  /// Disabled text/icons
  static const double disabled = 0.35;

  /// Secondary text on a surface
  static const double secondary = 0.5;
  static const double secondaryStrong = 0.65;
}

// ─── Common decorations (helpers) ────────────────────────────────────────────

class AppDecorations {
  AppDecorations._();

  /// Standard card background (uses surface color from theme)
  static BoxDecoration card(BuildContext context) => BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      );

  /// Small tinted icon background (e.g. for _InfoIcon)
  static BoxDecoration tintedIcon(Color color) => BoxDecoration(
        color: color.withValues(alpha: AppOpacity.tintLight),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      );

  /// Pill (e.g. status chip)
  static BoxDecoration pill(Color color) => BoxDecoration(
        color: color.withValues(alpha: AppOpacity.tintLight),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      );
}

// ─── Standard insets ─────────────────────────────────────────────────────────

class AppInsets {
  AppInsets._();

  static const EdgeInsets screenPadding = EdgeInsets.all(AppSpacing.x3);
  static const EdgeInsets listPadding =
      EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.x6);
  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.xs);
}
