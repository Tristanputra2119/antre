import 'package:material_ui/material_ui.dart';

/// Design tokens from Antre.pen (variables, light/dark). Widgets read colors
/// and number styles from here instead of writing hex or font sizes inline.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkMuted,
    required this.rule,
    required this.signal,
    required this.onSignal,
    required this.onPrimary,
    required this.done,
    required this.onDone,
    required this.skipped,
    required this.cancelled,
    required this.error,
    required this.chipWaiting,
    required this.doneTint,
    required this.skippedTint,
    required this.cancelledTint,
    required this.scrim,
  });

  static const light = AppTokens(
    paper: Color(0xFFF4F6F7),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1B2A41),
    inkMuted: Color(0xFF5A6779),
    rule: Color(0xFFD5DBE1),
    signal: Color(0xFFFFC531),
    onSignal: Color(0xFF1B2A41),
    onPrimary: Color(0xFFFFFFFF),
    done: Color(0xFF196F49),
    onDone: Color(0xFFFFFFFF),
    skipped: Color(0xFF994D15),
    cancelled: Color(0xFF9B3D3D),
    error: Color(0xFFB83A2E),
    chipWaiting: Color(0x99D5DBE1),
    doneTint: Color(0x24196F49),
    skippedTint: Color(0x24994D15),
    cancelledTint: Color(0x249B3D3D),
    scrim: Color(0x6610161F),
  );

  static const dark = AppTokens(
    paper: Color(0xFF10161F),
    card: Color(0xFF1A2330),
    ink: Color(0xFFE7ECF2),
    inkMuted: Color(0xFF9AA6B5),
    rule: Color(0xFF2C3746),
    signal: Color(0xFFFFCF4D),
    onSignal: Color(0xFF1B2A41),
    onPrimary: Color(0xFF10161F),
    done: Color(0xFF4CC38A),
    onDone: Color(0xFF10161F),
    skipped: Color(0xFFF0954A),
    cancelled: Color(0xFFE18080),
    error: Color(0xFFF08A7E),
    chipWaiting: Color(0x992C3746),
    doneTint: Color(0x244CC38A),
    skippedTint: Color(0x24F0954A),
    cancelledTint: Color(0x24E18080),
    scrim: Color(0x99000000),
  );

  final Color paper;
  final Color card;
  final Color ink;
  final Color inkMuted;
  final Color rule;

  /// Reserved for the "called" status only.
  final Color signal;
  final Color onSignal;
  final Color onPrimary;
  final Color done;
  final Color onDone;
  final Color skipped;
  final Color cancelled;
  final Color error;
  final Color chipWaiting;
  final Color doneTint;
  final Color skippedTint;
  final Color cancelledTint;
  final Color scrim;

  /// Card shadows stay dark in both themes; a light shadow reads as a glow.
  static const shadow = Color(0xFF1B2A41);

  /// Condensed numerals: ticket 128, mini ticket 112, dashboard 80, panel 56, row 28.
  TextStyle number(double size, {Color? color}) => TextStyle(
    fontFamily: AppFonts.number,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: size >= 80 ? 0.9 : 1,
    letterSpacing: size >= 100 ? -2 : 0,
    color: color ?? ink,
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

abstract final class AppFonts {
  static const text = 'Plus Jakarta Sans';
  static const number = 'Sofia Sans Extra Condensed';
}

abstract final class AppRadius {
  static const button = 14.0;
  static const field = 12.0;
  static const panel = 16.0;
  static const ticket = 20.0;
  static const dialog = 24.0;
}

/// Horizontal screen margin used by every page.
const kScreenPadding = 20.0;

/// Widest the app lays out; larger screens center this column.
const kMaxContentWidth = 480.0;

extension AppThemeX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  TextTheme get text => Theme.of(this).textTheme;
}

ThemeData buildTheme(Brightness brightness) {
  final t = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;

  TextStyle style(double size, FontWeight weight, double height, Color color) =>
      TextStyle(
        fontFamily: AppFonts.text,
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color,
      );
  const regular = FontWeight.w400;
  const semi = FontWeight.w600;
  const bold = FontWeight.w700;

  final textTheme = TextTheme(
    headlineSmall: style(24, bold, 1.25, t.ink),
    titleMedium: style(17, semi, 1.35, t.ink),
    titleSmall: style(16, semi, 1.35, t.ink),
    bodyLarge: style(16, regular, 1.5, t.ink),
    bodyMedium: style(14, regular, 1.45, t.inkMuted),
    bodySmall: style(13, regular, 1.4, t.inkMuted),
    labelLarge: style(16, semi, 1.2, t.ink),
    labelMedium: style(13, semi, 1.2, t.ink),
    labelSmall: style(12, semi, 1.4, t.inkMuted),
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
  );
  OutlineInputBorder fieldBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    brightness: brightness,
    fontFamily: AppFonts.text,
    scaffoldBackgroundColor: t.paper,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: t.ink,
      onPrimary: t.onPrimary,
      secondary: t.done,
      onSecondary: t.onDone,
      error: t.error,
      onError: t.onPrimary,
      surface: t.paper,
      onSurface: t.ink,
      onSurfaceVariant: t.inkMuted,
      outline: t.rule,
      outlineVariant: t.rule,
      surfaceContainerHigh: t.card,
      scrim: t.scrim,
    ),
    textTheme: textTheme,
    dividerTheme: DividerThemeData(color: t.rule, thickness: 1, space: 1),
    iconTheme: IconThemeData(color: t.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: t.paper,
      foregroundColor: t.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.onPrimary,
        disabledBackgroundColor: t.rule,
        disabledForegroundColor: t.inkMuted,
        minimumSize: const Size.fromHeight(56),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: t.rule),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.ink,
        minimumSize: const Size(48, 48),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: textTheme.bodyLarge!.copyWith(color: t.inkMuted),
      // Muted at rest, ink when focused (matches the outline weight change).
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (states) => textTheme.titleSmall!.copyWith(
          color: states.contains(WidgetState.error)
              ? t.error
              : states.contains(WidgetState.focused)
              ? t.ink
              : t.inkMuted,
        ),
      ),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall!.copyWith(color: t.error),
      // inkMuted, not rule: field outlines need 3:1 to be seen (WCAG 1.4.11).
      enabledBorder: fieldBorder(t.inkMuted, 1),
      disabledBorder: fieldBorder(t.rule, 1),
      focusedBorder: fieldBorder(t.ink, 2),
      errorBorder: fieldBorder(t.error, 1),
      focusedErrorBorder: fieldBorder(t.error, 2),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      barrierColor: t.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyLarge!.copyWith(color: t.inkMuted),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: t.scrim,
      showDragHandle: true,
      dragHandleColor: t.rule,
      dragHandleSize: const Size(32, 4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.card,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyLarge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.ink,
      contentTextStyle: textTheme.bodyMedium!.copyWith(color: t.onPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: t.ink),
    extensions: [t],
  );
}
