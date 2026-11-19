import 'package:material_ui/material_ui.dart';

/// Design tokens from the Figma file (Foundations page), exported to
/// mypet/design/mypet-tokens.json version 1.0, 19 Nov 2026.
/// https://www.figma.com/design/EnOiOvzCCsTz5ANcwmHfJj
class Tokens {
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;

  static const radiusChip = 8.0;
  static const radiusInput = 12.0;
  static const radiusCard = 16.0;
  static const radiusSheet = 24.0;
  static const radiusButton = 999.0;

  /// Smallest touch target (WCAG 2.5.5 and Material: 48 x 48).
  static const minTarget = 48.0;

  static const headingFont = 'Nunito';
  static const bodyFont = 'Atkinson Hyperlegible Next';
}

/// Tonal buttons (secondaryContainer) use the light teal, as in the Figma "Later" and
/// "Export for the vet" buttons; apricot stays a fill accent (pet avatar).
///
/// Colours the Material scheme has no role for.
/// A change flag is amber, never red: red is only for errors (token rules).
@immutable
class MyPetColors extends ThemeExtension<MyPetColors> {
  const MyPetColors({
    required this.background,
    required this.surfaceTint,
    required this.changeContainer,
    required this.onChangeContainer,
    required this.loggedContainer,
    required this.onLoggedContainer,
  });

  final Color background;
  final Color surfaceTint;
  final Color changeContainer;
  final Color onChangeContainer;
  final Color loggedContainer;
  final Color onLoggedContainer;

  static const light = MyPetColors(
    background: Color(0xFFFAF8F5),
    surfaceTint: Color(0xFFE9F6F7),
    changeContainer: Color(0xFFFFEFD3),
    onChangeContainer: Color(0xFF7A4A00),
    loggedContainer: Color(0xFFDCF1E5),
    onLoggedContainer: Color(0xFF1F6B4A),
  );

  static const dark = MyPetColors(
    background: Color(0xFF121A1C),
    surfaceTint: Color(0xFF16282A),
    changeContainer: Color(0xFF3A2A0E),
    onChangeContainer: Color(0xFFFFD08A),
    loggedContainer: Color(0xFF0F3424),
    onLoggedContainer: Color(0xFF9FE0BE),
  );

  static MyPetColors of(BuildContext context) =>
      Theme.of(context).extension<MyPetColors>()!;

  @override
  MyPetColors copyWith() => this;

  @override
  MyPetColors lerp(MyPetColors? other, double t) => t < 0.5 || other == null ? this : other;
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF0E6B73),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD3ECEE),
  onPrimaryContainer: Color(0xFF0A4F55),
  secondary: Color(0xFFF4B27A),
  onSecondary: Color(0xFF3D2A12),
  secondaryContainer: Color(0xFFD3ECEE),
  onSecondaryContainer: Color(0xFF0A4F55),
  tertiary: Color(0xFF7A4A00),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFDE7E5),
  onErrorContainer: Color(0xFF8C1D18),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF1B2426),
  onSurfaceVariant: Color(0xFF4F5B5E),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFF1EFEA),
  surfaceContainerHigh: Color(0xFFF1EFEA),
  surfaceContainerHighest: Color(0xFFE9E6E0),
  outline: Color(0xFF6E7B7E),
  outlineVariant: Color(0xFFC9CFD0),
  scrim: Color(0xFF1B2426),
  shadow: Color(0xFF0F2426),
  surfaceTint: Color(0x00000000),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF7FD3DA),
  onPrimary: Color(0xFF0B2E31),
  primaryContainer: Color(0xFF0A4F55),
  onPrimaryContainer: Color(0xFFD3ECEE),
  secondary: Color(0xFFF4B27A),
  onSecondary: Color(0xFF3D2A12),
  secondaryContainer: Color(0xFF0A4F55),
  onSecondaryContainer: Color(0xFFD3ECEE),
  tertiary: Color(0xFFFFD08A),
  onTertiary: Color(0xFF3A2A0E),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF5C1410),
  errorContainer: Color(0xFF5C1410),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF1C2628),
  onSurface: Color(0xFFE3EAEB),
  onSurfaceVariant: Color(0xFFB8C4C6),
  surfaceContainerLowest: Color(0xFF121A1C),
  surfaceContainerLow: Color(0xFF1C2628),
  surfaceContainer: Color(0xFF243032),
  surfaceContainerHigh: Color(0xFF243032),
  surfaceContainerHighest: Color(0xFF2C3A3C),
  outline: Color(0xFF8A9799),
  outlineVariant: Color(0xFF3A4648),
  scrim: Color(0xFF000000),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0x00000000),
);

TextStyle _style(String font, double weight, double size, double height) => TextStyle(
      fontFamily: font,
      fontSize: size,
      height: height / size,
      fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
      // Variable fonts: set the weight axis too, so iOS and Android draw the same weight.
      fontVariations: [FontVariation.weight(weight)],
      letterSpacing: 0,
    );

/// Type scale from the tokens. Body text is never below 16 (token rules); captions 13.
TextTheme _textTheme(Color on, Color onVariant) {
  final number = _style(Tokens.headingFont, 800, 40, 44);
  final display = _style(Tokens.headingFont, 700, 28, 34);
  final title = _style(Tokens.headingFont, 700, 22, 28);
  final heading = _style(Tokens.headingFont, 700, 18, 24);
  final body = _style(Tokens.bodyFont, 400, 16, 24);
  final bodyStrong = _style(Tokens.bodyFont, 600, 16, 24);
  final label = _style(Tokens.bodyFont, 600, 14, 20);
  final caption = _style(Tokens.bodyFont, 400, 13, 18);
  return TextTheme(
    displayLarge: number,
    displayMedium: number,
    displaySmall: number,
    headlineLarge: display,
    headlineMedium: display,
    headlineSmall: title,
    titleLarge: title,
    titleMedium: heading,
    titleSmall: bodyStrong,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption.copyWith(color: onVariant),
    labelLarge: label,
    labelMedium: label,
    labelSmall: caption,
  ).apply(bodyColor: on, displayColor: on);
}

ThemeData buildTheme(Brightness b) {
  final light = b == Brightness.light;
  final scheme = light ? _lightScheme : _darkScheme;
  final extra = light ? MyPetColors.light : MyPetColors.dark;
  final text = _textTheme(scheme.onSurface, scheme.onSurfaceVariant);
  const pill = StadiumBorder();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: [extra],
    scaffoldBackgroundColor: extra.background,
    fontFamily: Tokens.bodyFont,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: extra.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      // Figma card shadow: y 2, blur 8, 8%.
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: light ? 0.12 : 0.5),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusCard), side: BorderSide.none),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: pill,
        textStyle: text.titleSmall,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(Tokens.minTarget, Tokens.minTarget),
        shape: pill,
        side: BorderSide(color: scheme.outline),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(Tokens.minTarget, Tokens.minTarget),
        textStyle: text.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusChip)),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: scheme.surface,
      selectedColor: scheme.primary,
      labelStyle: text.labelLarge,
      secondaryLabelStyle: text.labelLarge!.copyWith(color: scheme.onPrimary),
      checkmarkColor: scheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.space3, vertical: Tokens.space2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusInput),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      height: 72,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusSheet))),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusSheet)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      iconColor: scheme.onSurfaceVariant,
    ),
  );
}
