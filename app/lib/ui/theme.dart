import 'package:material_ui/material_ui.dart';

/// Design tokens v2: the colourful look of the September SwiftUI MyPet
/// (MyPet/Support/Theme.swift), kept accessible. Source of truth:
/// mypet/design/mypet-tokens-v2.json. Text colours are darkened where needed so
/// text passes WCAG AA; the bright brand colours are used for fills and edges.
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
  final Color cardBorder;
  final Color changeContainer, onChangeContainer, changeEdge;
  final Color loggedContainer, onLoggedContainer, loggedEdge;
  final List<Color> petAccents;

  /// Light teal wash used for notes and tips (calm, not alarming).
  final Color surfaceTint;

  LinearGradient get heroGradient =>
      LinearGradient(colors: hero, begin: Alignment.topLeft, end: Alignment.bottomRight);
  LinearGradient get pageGradient =>
      LinearGradient(colors: page, begin: Alignment.topCenter, end: Alignment.bottomCenter);

  /// A stable colour for a pet, so each pet keeps its colour on every screen.
  Color petAccent(String petId) => petAccents[petId.codeUnits.fold(0, (a, b) => a + b) % petAccents.length];

  static const light = MyPetColors(
    brand: Color(0xFFFA7361),
    brandStrong: Color(0xFFC9452F),
    brandContainer: Color(0xFFFFE3DA),
    onBrandContainer: Color(0xFF8A2E20),
    hero: [Color(0xFFD9503C), Color(0xFFF27A55)],
    page: [Color(0xFFFCEFE8), Color(0xFFF6F4F1)],
    sun: Color(0xFFFFC24D),
    sunContainer: Color(0xFFFFF1CC),
    onSunContainer: Color(0xFF6B4A00),
    lavender: Color(0xFF8F7AE6),
    lavenderContainer: Color(0xFFECE8FC),
    onLavenderContainer: Color(0xFF4B3BA0),
    cardBorder: Color(0xFFE3E3DE),
    changeContainer: Color(0xFFFFEFD3),
    onChangeContainer: Color(0xFF7A4A00),
    changeEdge: Color(0xFFE0A030),
    loggedContainer: Color(0xFFDCF1E5),
    onLoggedContainer: Color(0xFF1F6B4A),
    loggedEdge: Color(0xFF34875F),
    petAccents: [
      Color(0xFF2E877A), Color(0xFF8C54A3), Color(0xFFB8602F),
      Color(0xFF3D73B8), Color(0xFF9E4F6B), Color(0xFF4F7A34),
    ],
    surfaceTint: Color(0xFFE6F3F2),
  );

  static const dark = MyPetColors(
    brand: Color(0xFFFF9480),
    brandStrong: Color(0xFFFF9480),
    brandContainer: Color(0xFF5A2418),
    onBrandContainer: Color(0xFFFFDAD0),
    hero: [Color(0xFF8E2F20), Color(0xFFB4472F)],
    page: [Color(0xFF1A1416), Color(0xFF0F1517)],
    sun: Color(0xFFFFD173),
    sunContainer: Color(0xFF4A3800),
    onSunContainer: Color(0xFFFFE7A8),
    lavender: Color(0xFFB8A8FA),
    lavenderContainer: Color(0xFF352A73),
    onLavenderContainer: Color(0xFFE3DDFF),
    cardBorder: Color(0xFF38383F),
    changeContainer: Color(0xFF3A2A0E),
    onChangeContainer: Color(0xFFFFD08A),
    changeEdge: Color(0xFFF0C761),
    loggedContainer: Color(0xFF0F3424),
    onLoggedContainer: Color(0xFF9FE0BE),
    loggedEdge: Color(0xFF6BC799),
    petAccents: [
      Color(0xFF5FBFAD), Color(0xFFBD8FDB), Color(0xFFF0A878),
      Color(0xFF7DADED), Color(0xFFDB87A6), Color(0xFF99C770),
    ],
    surfaceTint: Color(0xFF16282A),
  );

  static MyPetColors of(BuildContext context) => Theme.of(context).extension<MyPetColors>()!;

  @override
  MyPetColors copyWith() => this;

  @override
  MyPetColors lerp(MyPetColors? other, double t) => t < 0.5 || other == null ? this : other;
}

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF17706F),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFDDF2F2),
  onPrimaryContainer: Color(0xFF0F4F4F),
  secondary: Color(0xFFC9452F),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDDF2F2),
  onSecondaryContainer: Color(0xFF0F4F4F),
  tertiary: Color(0xFF7A4A00),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFDE7E5),
  onErrorContainer: Color(0xFF8C1D18),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF2B1D1A),
  onSurfaceVariant: Color(0xFF6E5F5A),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFF6F0EC),
  surfaceContainerHigh: Color(0xFFF6F0EC),
  surfaceContainerHighest: Color(0xFFEDE5E0),
  outline: Color(0xFF8A7B76),
  outlineVariant: Color(0xFFE3E3DE),
  scrim: Color(0xFF2B1D1A),
  shadow: Color(0xFF8A2E20),
  surfaceTint: Color(0x00000000),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF5DCCC7),
  onPrimary: Color(0xFF00302F),
  primaryContainer: Color(0xFF124B4A),
  onPrimaryContainer: Color(0xFFBFF0EE),
  secondary: Color(0xFFFF9480),
  onSecondary: Color(0xFF4A1206),
  secondaryContainer: Color(0xFF124B4A),
  onSecondaryContainer: Color(0xFFBFF0EE),
  tertiary: Color(0xFFFFD08A),
  onTertiary: Color(0xFF3A2A0E),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF5C1410),
  errorContainer: Color(0xFF5C1410),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF211D20),
  onSurface: Color(0xFFF2ECEA),
  onSurfaceVariant: Color(0xFFC4B8B4),
  surfaceContainerLowest: Color(0xFF1A1416),
  surfaceContainerLow: Color(0xFF211D20),
  surfaceContainer: Color(0xFF2B2629),
  surfaceContainerHigh: Color(0xFF2B2629),
  surfaceContainerHighest: Color(0xFF353033),
  outline: Color(0xFF9A8D89),
  outlineVariant: Color(0xFF38383F),
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
      // Floating pill bar: selected tab on a pale grey-teal highlight, icon and label in coral.
      backgroundColor: Colors.transparent,
      indicatorColor: light ? const Color(0xFFE5ECEC) : const Color(0xFF2E3A3A),
      iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(
          color: st.contains(WidgetState.selected) ? extra.brandStrong : scheme.onSurface)),
      labelTextStyle: WidgetStateProperty.resolveWith((st) => text.labelMedium!.copyWith(
          color: st.contains(WidgetState.selected) ? extra.brandStrong : scheme.onSurface)),
      height: 72,
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
        backgroundColor: light ? const Color(0xFFEAE4DF) : scheme.surfaceContainer,
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
