import 'package:material_ui/material_ui.dart';

import '../models/pet.dart';

/// Design tokens v3: violet, pink, sky blue and sun yellow from Erwyna's pitch
/// slides and her September SwiftUI MyPet. Source of truth: mypet/design/mypet-tokens-v3.json.
/// Violet is the trusted main colour; pink, sky and sun are accents only.
/// Every text pair passes WCAG AA (4.5:1).
class Tokens {
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 24.0;
  static const space6 = 32.0;

  static const radiusChip = 12.0;
  static const radiusInput = 14.0;
  static const radiusCard = 18.0;

  /// Inner edge of every text field: text, units and icons sit this far from the border.
  static const fieldEdge = 16.0;

  /// Right inset of a field's trailing unit or button ("kg", the mic circle): the same for
  /// every field, so their right edges line up down the page.
  static const fieldTrail = 12.0;
  static const radiusHero = 24.0;
  static const radiusSheet = 24.0;
  static const radiusButton = 999.0;

  /// Coloured left edge that ties a card to a pet or a status.
  static const accentEdge = 4.0;

  /// Smallest touch target (WCAG 2.5.5 and Material: 48 x 48).
  static const minTarget = 48.0;

  static const headingFont = 'Nunito';
  static const bodyFont = 'Atkinson Hyperlegible Next';
}

/// Colours the Material scheme has no role for.
/// A change flag is amber, never red: red is only for errors.
@immutable
class MyPetColors extends ThemeExtension<MyPetColors> {
  const MyPetColors({
    required this.brand,
    required this.brandStrong,
    required this.brandContainer,
    required this.onBrandContainer,
    required this.hero,
    required this.page,
    required this.sun,
    required this.sunContainer,
    required this.onSunContainer,
    required this.lavender,
    required this.lavenderContainer,
    required this.onLavenderContainer,
    required this.pink,
    required this.pinkContainer,
    required this.onPinkContainer,
    required this.sky,
    required this.skyContainer,
    required this.onSkyContainer,
    required this.cardBorder,
    required this.changeContainer,
    required this.onChangeContainer,
    required this.changeEdge,
    required this.loggedContainer,
    required this.onLoggedContainer,
    required this.loggedEdge,
    required this.petAccents,
    required this.surfaceTint,
  });

  final Color brand, brandStrong, brandContainer, onBrandContainer;
  final List<Color> hero, page;
  final Color sun, sunContainer, onSunContainer;
  final Color lavender, lavenderContainer, onLavenderContainer;
  final Color pink, pinkContainer, onPinkContainer;
  final Color sky, skyContainer, onSkyContainer;
  final Color cardBorder;
  final Color changeContainer, onChangeContainer, changeEdge;
  final Color loggedContainer, onLoggedContainer, loggedEdge;
  final List<Color> petAccents;

  /// Light sky wash used for notes and tips (calm, not alarming).
  final Color surfaceTint;

  LinearGradient get heroGradient =>
      LinearGradient(colors: hero, begin: Alignment.topLeft, end: Alignment.bottomRight);
  LinearGradient get pageGradient =>
      LinearGradient(colors: page, begin: Alignment.topCenter, end: Alignment.bottomCenter);

  /// A stable colour for a pet, so each pet keeps its colour on every screen.
  Color petAccent(Pet p) => petAccents[petColourIndex(p) % petAccents.length];

  static const light = MyPetColors(
    brand: Color(0xFF6A4FD6),
    brandStrong: Color(0xFF5B47C7),
    brandContainer: Color(0xFFEEEAFF),
    onBrandContainer: Color(0xFF4A36B0),
    hero: [Color(0xFF6A4FD6), Color(0xFFB5488A)],
    page: [Color(0xFFF1ECFF), Color(0xFFFCEFF6)],
    sun: Color(0xFFFFC94D),
    sunContainer: Color(0xFFFFF3CF),
    onSunContainer: Color(0xFF6B4A00),
    lavender: Color(0xFF9C86F5),
    lavenderContainer: Color(0xFFF1EDFF),
    onLavenderContainer: Color(0xFF4A36B0),
    pink: Color(0xFFC23F7E),
    pinkContainer: Color(0xFFFDE6F0),
    onPinkContainer: Color(0xFF8A2A5C),
    sky: Color(0xFF4A62C9),
    skyContainer: Color(0xFFE6EAFB),
    onSkyContainer: Color(0xFF2E3F8F),
    cardBorder: Color(0xFFE6DEFA),
    changeContainer: Color(0xFFFFF1D6),
    onChangeContainer: Color(0xFF7A4A00),
    changeEdge: Color(0xFFF2B544),
    loggedContainer: Color(0xFFEDE7FF),
    onLoggedContainer: Color(0xFF4A36B0),
    loggedEdge: Color(0xFF8E7CF0),
    petAccents: [
      Color(0xFF6A4FD6), Color(0xFFC23F7E), Color(0xFF4A62C9), Color(0xFF8E44AD), Color(0xFF2F6FA8), Color(0xFFB8476A), Color(0xFFA86500), Color(0xFFA0527A),
    ],
    surfaceTint: Color(0xFFF7F4FF),
  );

  static const dark = MyPetColors(
    brand: Color(0xFFB9A8FF),
    brandStrong: Color(0xFFCFC2FF),
    brandContainer: Color(0xFF3A2E6E),
    onBrandContainer: Color(0xFFE5DEFF),
    hero: [Color(0xFF5B47C7), Color(0xFFA9457F)],
    page: [Color(0xFF17141F), Color(0xFF141824)],
    sun: Color(0xFFFFD173),
    sunContainer: Color(0xFF3A2E1A),
    onSunContainer: Color(0xFFFFD9A0),
    lavender: Color(0xFFC9B8FF),
    lavenderContainer: Color(0xFF322A55),
    onLavenderContainer: Color(0xFFE5DEFF),
    pink: Color(0xFFF7A8CB),
    pinkContainer: Color(0xFF4A2338),
    onPinkContainer: Color(0xFFFFD6E7),
    sky: Color(0xFFA8B8F5),
    skyContainer: Color(0xFF26304F),
    onSkyContainer: Color(0xFFD6DEFB),
    cardBorder: Color(0xFF363044),
    changeContainer: Color(0xFF3A2E1A),
    onChangeContainer: Color(0xFFFFD9A0),
    changeEdge: Color(0xFFF2C261),
    loggedContainer: Color(0xFF2E2A48),
    onLoggedContainer: Color(0xFFD9D1FF),
    loggedEdge: Color(0xFFB9A8FF),
    petAccents: [
      Color(0xFFB9A8FF), Color(0xFFF2A6C8), Color(0xFFA8B8F5), Color(0xFFD9A8F0), Color(0xFF9CC4EA), Color(0xFFF0A8BC), Color(0xFFFFD173), Color(0xFFE3B0CC),
    ],
    surfaceTint: Color(0xFF2A2538),
  );

  /// Text or icon colour on a pet colour: white in light mode; dark ink only on
  /// the pastel dark-mode accents.
  static Color onAccent(Color fill) =>
      fill.computeLuminance() > 0.4 ? const Color(0xFF1B1530) : Colors.white;

  static MyPetColors of(BuildContext context) => Theme.of(context).extension<MyPetColors>()!;

  @override
  MyPetColors copyWith() => this;

  @override
  MyPetColors lerp(MyPetColors? other, double t) => t < 0.5 || other == null ? this : other;
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF6A4FD6),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFEEEAFF),
  onPrimaryContainer: Color(0xFF4A36B0),
  secondary: Color(0xFF8A2A5C),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFFDE6F0),
  onSecondaryContainer: Color(0xFF8A2A5C),
  tertiary: Color(0xFF1E5C8F),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFDE7E5),
  onErrorContainer: Color(0xFF8C1D18),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF2B2340),
  onSurfaceVariant: Color(0xFF6B6480),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFF7F4FF),
  surfaceContainerHigh: Color(0xFFF4F1FB),
  surfaceContainerHighest: Color(0xFFEAE6F4),
  outline: Color(0xFF8A84A0),
  outlineVariant: Color(0xFFE6DEFA),
  scrim: Color(0xFF2B2340),
  shadow: Color(0xFF4A36B0),
  surfaceTint: Color(0x00000000),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFB9A8FF),
  onPrimary: Color(0xFF1B1530),
  primaryContainer: Color(0xFF3A2E6E),
  onPrimaryContainer: Color(0xFFE5DEFF),
  secondary: Color(0xFFF7A8CB),
  onSecondary: Color(0xFF3A1229),
  secondaryContainer: Color(0xFF4A2338),
  onSecondaryContainer: Color(0xFFFFD6E7),
  tertiary: Color(0xFF8CC8F2),
  onTertiary: Color(0xFF0F2A40),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF5C1410),
  errorContainer: Color(0xFF5C1410),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF231F2D),
  onSurface: Color(0xFFF3F0FA),
  onSurfaceVariant: Color(0xFFC5BFD6),
  surfaceContainerLowest: Color(0xFF17141F),
  surfaceContainerLow: Color(0xFF231F2D),
  surfaceContainer: Color(0xFF2C2738),
  surfaceContainerHigh: Color(0xFF2C2738),
  surfaceContainerHighest: Color(0xFF363044),
  outline: Color(0xFF9A93AE),
  outlineVariant: Color(0xFF363044),
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
    scaffoldBackgroundColor: extra.page.first,
    fontFamily: Tokens.bodyFont,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // Big bold page titles on the left, as in the old app.
      titleTextStyle: text.headlineMedium,
      toolbarHeight: 64,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      // White card, large corners, a soft shadow and no visible border (old SwiftUI app).
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: light ? 0.10 : 0.5),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          side: light ? BorderSide.none : BorderSide(color: extra.cardBorder)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: Tokens.fieldEdge, vertical: Tokens.space4),
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
      surfaceTintColor: Colors.transparent,
      // Floating pill bar: selected tab on a pale violet highlight.
      backgroundColor: Colors.transparent,
      indicatorColor: extra.brandContainer,
      iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(
          color: st.contains(WidgetState.selected) ? extra.brandStrong : scheme.onSurface)),
      labelTextStyle: WidgetStateProperty.resolveWith((st) => text.labelMedium!.copyWith(fontSize: 12,
          color: st.contains(WidgetState.selected) ? extra.brandStrong : scheme.onSurface)),
      height: 72,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 3,
      shape: pill,
      extendedTextStyle: text.titleSmall,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Tokens.radiusSheet))),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radiusSheet)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedBackgroundColor: scheme.surface,
        selectedForegroundColor: scheme.onSurface,
        side: BorderSide.none,
        textStyle: text.labelLarge,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    listTileTheme: ListTileThemeData(
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodySmall,
      iconColor: scheme.onSurfaceVariant,
    ),
  );
}
