import 'package:flutter/material.dart';

// สีหลักตาม mockup
class Pal {
  static const sidebar = Color(0xFF0B1220);
  static const sidebarHover = Color(0xFF162033);
  static const sidebarActive = Color(0xFF1E3A5F);
  static const primary = Color(0xFF1D4ED8);
  static const primarySoft = Color(0xFFEFF4FF);
  static const bg = Color(0xFFF4F6FA);
  static const line = Color(0xFFE6EAF0);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);

  static const ok = Color(0xFF16A34A);
  static const okBg = Color(0xFFDCFCE7);
  static const warn = Color(0xFFF59E0B);
  static const warnBg = Color(0xFFFEF3C7);
  static const err = Color(0xFFDC2626);
  static const errBg = Color(0xFFFEE2E2);
  static const infoBg = Color(0xFFDBEAFE);

  static const shopee = Color(0xFFEE4D2D);
  static const tiktok = Color(0xFF111111);
  static const tiktokHi = Color(0xFF25F4EE);
  static const lazada = Color(0xFF0F146D);
}

ThemeData buildTheme() {
  const box = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8)));
  final radius = BorderRadius.circular(10);

  final scheme = ColorScheme.fromSeed(seedColor: Pal.primary, primary: Pal.primary).copyWith(
    surface: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF8FAFC),
    surfaceContainer: Pal.bg,
    surfaceContainerHigh: const Color(0xFFEEF2F6),
    surfaceContainerHighest: Pal.line,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    canvasColor: Colors.white,
    cardColor: Colors.white,
    scaffoldBackgroundColor: Pal.bg,
    applyElevationOverlayColor: false,
    splashColor: Pal.primary.withValues(alpha: 0.12),
    highlightColor: Pal.primary.withValues(alpha: 0.08),
    hoverColor: Pal.primary.withValues(alpha: 0.06),
  );

  final text = base.textTheme.apply(
    bodyColor: Pal.text,
    displayColor: Pal.text,
  );

  return base.copyWith(
    textTheme: text,
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Color(0x33000000),
      shape: box,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Color(0x33000000),
      shape: box,
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(Color(0x33000000)),
        elevation: WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(box),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(box),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Pal.line, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Pal.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: Pal.line)),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Pal.primary, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Pal.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) {
        return s.contains(WidgetState.selected) ? Pal.primary : Colors.white;
      }),
      side: const BorderSide(color: Pal.line, width: 1.4),
    ),
  );
}
