import 'package:flutter/material.dart';

/// Couleurs de la marque, tirées du logo.
abstract final class BrandColors {
  /// Moitié gauche du bouclier : actions principales.
  static const signal = Color(0xFF0262F4);

  /// Moitié droite du bouclier.
  static const deep = Color(0xFF023EB8);

  /// Couleur du mot « SecurePass » : texte et fond du thème sombre.
  static const midnight = Color(0xFF080E28);

  static const ice = Color(0xFFEEF3FD);
  static const mist = Color(0xFFC9D6F2);
  static const danger = Color(0xFFD93636);
}

abstract final class AppTheme {
  static const fontFamily = 'Sora';
  static const monoFamily = 'JetBrainsMono';

  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: BrandColors.signal,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCE7FD),
      onPrimaryContainer: BrandColors.deep,
      secondary: BrandColors.deep,
      onSecondary: Colors.white,
      error: BrandColors.danger,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: BrandColors.midnight,
      onSurfaceVariant: Color(0xFF4A5578),
      surfaceContainerHighest: Color(0xFFE3EAF8),
      outline: BrandColors.mist,
      outlineVariant: Color(0xFFDCE3F3),
      inverseSurface: BrandColors.midnight,
      onInverseSurface: Colors.white,
    ),
    background: BrandColors.ice,
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF5C97FF),
      onPrimary: Color(0xFF021447),
      primaryContainer: Color(0xFF14306F),
      onPrimaryContainer: Color(0xFFDCE7FD),
      secondary: Color(0xFF8DB4FF),
      onSecondary: Color(0xFF021447),
      error: Color(0xFFFF6B6B),
      onError: Color(0xFF3A0000),
      surface: Color(0xFF111A3A),
      onSurface: Color(0xFFE8EEFC),
      onSurfaceVariant: Color(0xFF9AA8CC),
      surfaceContainerHighest: Color(0xFF1A2550),
      outline: Color(0xFF2A3766),
      outlineVariant: Color(0xFF1E2A55),
      inverseSurface: Color(0xFFE8EEFC),
      onInverseSurface: BrandColors.midnight,
    ),
    background: BrandColors.midnight,
  );

  static ThemeData _build(ColorScheme scheme, {required Color background}) {
    final base = ThemeData(colorScheme: scheme, fontFamily: fontFamily);
    final text = base.textTheme
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.15,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.2,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.outline, width: 1.2),
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: scheme.error, width: 1.5)),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.error)
                ? scheme.error
                : states.contains(WidgetState.focused)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: scheme.outline, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(fontFamily: monoFamily, color: scheme.onSurface),
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    );
  }
}
