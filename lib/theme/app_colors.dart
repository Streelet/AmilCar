import 'package:flutter/material.dart';

/// Paleta de color tomada **estrictamente** del DESIGN.md
/// (Neo-Minimalist Design Guide). No inventar colores fuera de esta lista.
class AppColors {
  const AppColors._();

  // --- Superficies (canvas cálido off-white + capas tonales) ---
  static const Color surface = Color(0xFFFAF9FE);
  static const Color surfaceDim = Color(0xFFDAD9DF);
  static const Color surfaceBright = Color(0xFFFAF9FE);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F3F8);
  static const Color surfaceContainer = Color(0xFFEEEDF3);
  static const Color surfaceContainerHigh = Color(0xFFE9E7ED);
  static const Color surfaceContainerHighest = Color(0xFFE3E2E7);
  static const Color surfaceVariant = Color(0xFFE3E2E7);

  static const Color background = Color(0xFFFAF9FE);
  static const Color onBackground = Color(0xFF1A1B1F);
  static const Color onSurface = Color(0xFF1A1B1F);
  static const Color onSurfaceVariant = Color(0xFF59413D);

  static const Color inverseSurface = Color(0xFF2F3034);
  static const Color inverseOnSurface = Color(0xFFF1F0F5);

  // --- Contornos ---
  static const Color outline = Color(0xFF8D716B);
  static const Color outlineVariant = Color(0xFFE1BFB9);

  // --- Primary (Coral) ---
  static const Color surfaceTint = Color(0xFFAE311E);
  static const Color primary = Color(0xFFAE311E);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFF6B52);
  static const Color onPrimaryContainer = Color(0xFF6A0700);
  static const Color inversePrimary = Color(0xFFFFB4A6);

  // --- Secondary (Ink) ---
  static const Color secondary = Color(0xFF5F5E5E);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE2DFDE);
  static const Color onSecondaryContainer = Color(0xFF636262);

  // --- Tertiary (Canvas/Neutral) ---
  static const Color tertiary = Color(0xFF5D5F5F);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF999A9A);
  static const Color onTertiaryContainer = Color(0xFF303233);

  // --- Error ---
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // --- Fixed accents ---
  static const Color primaryFixed = Color(0xFFFFDAD4);
  static const Color primaryFixedDim = Color(0xFFFFB4A6);
  static const Color onPrimaryFixed = Color(0xFF3F0300);
  static const Color onPrimaryFixedVariant = Color(0xFF8C1808);
}

/// Radios de esquina del DESIGN.md (sección Shapes / rounded).
class AppRadii {
  const AppRadii._();

  static const double sm = 4; // 0.25rem
  static const double md = 12; // 0.75rem
  static const double lg = 16; // 1rem  -> botones / inputs
  static const double xl = 24; // 1.5rem -> tarjetas / contenedores
  static const double full = 9999;
}

/// Escala de espaciado del DESIGN.md (sección Layout & Spacing).
class AppSpacing {
  const AppSpacing._();

  static const double base = 8;
  static const double gutter = 24;
  static const double marginMobile = 20;
  static const double marginDesktop = 40;
  static const double cardPadding = 24;
}

/// Sistema de elevación "Tonal Layers + Ambient Shadows" del DESIGN.md.
/// Sombras suaves y difusas — nunca bordes duros ni bevels.
class AppShadows {
  const AppShadows._();

  /// Nivel 1 — Tarjetas: `0px 10px 30px rgba(0,0,0,0.04)`.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000), // negro al ~4%
      blurRadius: 30,
      offset: Offset(0, 10),
    ),
  ];

  /// Nivel 2 — Elementos interactivos / flotantes (un poco más marcada).
  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x14000000), // negro al ~8%
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
