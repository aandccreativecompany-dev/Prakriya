import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens for the Prakriyā design set.
class Brand {
  static const deep = Color(0xFF150C28);
  static const base = Color(0xFF1B0F33);
  static const violet = Color(0xFF4C2A85);
  static const gold = Color(0xFFF2B93B);
  static const goldLight = Color(0xFFE0A419);
  static const goldDeep = Color(0xFFB07E10);
  static const goldPale = Color(0xFFFFE9A8);
  static const cream = Color(0xFFFAF4E9);
  static const creamCard = Color(0xFFFFF7E4);
  static const bodyDark = Color(0xFFE8DFFA);
  static const mutedDark = Color(0xFF8A7BB5);
  static const mutedLight = Color(0xFF9C93AE);
}

/// One selectable app accent color — swaps in for the gold used everywhere
/// an "accent" surface is requested (icons, chips, highlights, the primary
/// button color's glow). [dark]/[light] are the two brightness variants,
/// [pale] is the soft tint used for accent text on a dark background, and
/// [deep] is the darker variant used for eyebrow labels on a light
/// background — mirrors the roles Brand.gold's four shades already played.
class AccentPalette {
  final String id;
  final String label;
  final Color dark;
  final Color light;
  final Color pale;
  final Color deep;
  const AccentPalette({
    required this.id,
    required this.label,
    required this.dark,
    required this.light,
    required this.pale,
    required this.deep,
  });
}

const kAccentPalettes = [
  AccentPalette(
    id: 'gold',
    label: 'Gold',
    dark: Brand.gold,
    light: Brand.goldLight,
    pale: Brand.goldPale,
    deep: Brand.goldDeep,
  ),
  AccentPalette(
    id: 'rose',
    label: 'Rose',
    dark: Color(0xFFF08BA0),
    light: Color(0xFFD9536F),
    pale: Color(0xFFFBD9E1),
    deep: Color(0xFFB23A54),
  ),
  AccentPalette(
    id: 'amethyst',
    label: 'Amethyst',
    dark: Color(0xFFC79BF0),
    light: Color(0xFF9B5DE5),
    pale: Color(0xFFE9D9FB),
    deep: Color(0xFF6E31B0),
  ),
  AccentPalette(
    id: 'emerald',
    label: 'Emerald',
    dark: Color(0xFF6FDCA8),
    light: Color(0xFF23A870),
    pale: Color(0xFFCFF7E4),
    deep: Color(0xFF17754D),
  ),
  AccentPalette(
    id: 'sky',
    label: 'Sky',
    dark: Color(0xFF7FC8F8),
    light: Color(0xFF2E9BE6),
    pale: Color(0xFFD6EEFD),
    deep: Color(0xFF1B6FA8),
  ),
  AccentPalette(
    id: 'coral',
    label: 'Coral',
    dark: Color(0xFFFF9770),
    light: Color(0xFFF06A3F),
    pale: Color(0xFFFFDECE),
    deep: Color(0xFFB8481F),
  ),
  AccentPalette(
    id: 'teal',
    label: 'Teal',
    dark: Color(0xFF6FE0D0),
    light: Color(0xFF1FA396),
    pale: Color(0xFFD2F5F0),
    deep: Color(0xFF0D6D63),
  ),
  AccentPalette(
    id: 'indigo',
    label: 'Indigo',
    dark: Color(0xFF9FA8FF),
    light: Color(0xFF5A64E0),
    pale: Color(0xFFE2E4FF),
    deep: Color(0xFF3A3FA0),
  ),
  AccentPalette(
    id: 'sunset',
    label: 'Sunset',
    dark: Color(0xFFFFB36F),
    light: Color(0xFFE8822E),
    pale: Color(0xFFFFE6CC),
    deep: Color(0xFFA85A14),
  ),
];

/// The currently selected accent, module-level so [Surfaces] (a pure,
/// no-context helper used everywhere) can read it without needing access
/// to the store — store.dart calls [setAccentId] whenever the user changes
/// it in Settings, then notifies listeners so every AnimatedBuilder(store)
/// screen repaints with the new colors.
String _accentId = 'gold';

void setAccentId(String id) {
  if (kAccentPalettes.any((p) => p.id == id)) _accentId = id;
}

String get currentAccentId => _accentId;

AccentPalette get currentAccent =>
    kAccentPalettes.firstWhere((p) => p.id == _accentId, orElse: () => kAccentPalettes.first);

/// One selectable reading font for body copy — the display/headline font
/// (Archivo Black) stays fixed as the app's brand identity regardless of
/// this choice; only everyday body/label text switches.
class AppFont {
  final String id;
  final String label;
  final String googleFontsFamily;
  const AppFont(this.id, this.label, this.googleFontsFamily);
}

const kFontFamilies = [
  AppFont('inter', 'Inter', 'Inter'),
  AppFont('poppins', 'Poppins', 'Poppins'),
  AppFont('nunito', 'Nunito', 'Nunito'),
  AppFont('quicksand', 'Quicksand', 'Quicksand'),
  AppFont('workSans', 'Work Sans', 'Work Sans'),
  AppFont('montserrat', 'Montserrat', 'Montserrat'),
  AppFont('lora', 'Lora', 'Lora'),
  AppFont('merriweather', 'Merriweather', 'Merriweather'),
  AppFont('dmSans', 'DM Sans', 'DM Sans'),
  AppFont('spaceGrotesk', 'Space Grotesk', 'Space Grotesk'),
  AppFont('sourceSans', 'Source Sans 3', 'Source Sans 3'),
  AppFont('fraunces', 'Fraunces', 'Fraunces'),
];

/// One selectable text size scale. Kept to a small, hand-picked set of
/// conservative multipliers (rather than an open slider) because a lot of
/// this app's UI — chips, badges, circular icons — was tuned tightly around
/// the default text size; a wide-open scale risks overflow in those spots.
class AppFontScale {
  final String id;
  final String label;
  final double factor;
  const AppFontScale(this.id, this.label, this.factor);
}

const kFontScales = [
  AppFontScale('small', 'Small', 0.92),
  AppFontScale('default', 'Default', 1.0),
  AppFontScale('large', 'Large', 1.12),
];

String _fontFamilyId = 'inter';
String _fontScaleId = 'default';

void setFontFamily(String id) {
  if (kFontFamilies.any((f) => f.id == id)) _fontFamilyId = id;
}

void setFontScale(String id) {
  if (kFontScales.any((s) => s.id == id)) _fontScaleId = id;
}

String get currentFontFamilyId => _fontFamilyId;
String get currentFontScaleId => _fontScaleId;

/// A curated, one-tap bundle of accent color + font + text size — for
/// people who'd rather pick a whole look than tune three separate pickers.
/// The independent pickers below (APP THEME COLOR / TEXT STYLE in Settings)
/// stay fully available for anyone who wants to fine-tune from here.
class AppThemePreset {
  final String id;
  final String label;
  final String description;
  final String accentId;
  final String fontFamilyId;
  final String fontScaleId;
  const AppThemePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.accentId,
    required this.fontFamilyId,
    required this.fontScaleId,
  });
}

const kThemePresets = [
  AppThemePreset(
    id: 'classic',
    label: 'Classic Gold',
    description: 'The original Prakriyā look.',
    accentId: 'gold',
    fontFamilyId: 'inter',
    fontScaleId: 'default',
  ),
  AppThemePreset(
    id: 'midnight',
    label: 'Midnight Amethyst',
    description: 'Cool, calm, a little mystical.',
    accentId: 'amethyst',
    fontFamilyId: 'poppins',
    fontScaleId: 'default',
  ),
  AppThemePreset(
    id: 'blush',
    label: 'Morning Blush',
    description: 'Soft and warm, rounded reading font.',
    accentId: 'rose',
    fontFamilyId: 'quicksand',
    fontScaleId: 'default',
  ),
  AppThemePreset(
    id: 'forest',
    label: 'Forest Calm',
    description: 'Grounded green, friendly and legible.',
    accentId: 'emerald',
    fontFamilyId: 'nunito',
    fontScaleId: 'default',
  ),
  AppThemePreset(
    id: 'ocean',
    label: 'Ocean Breeze',
    description: 'Clean and modern, slightly larger text.',
    accentId: 'sky',
    fontFamilyId: 'workSans',
    fontScaleId: 'large',
  ),
  AppThemePreset(
    id: 'sunset',
    label: 'Sunset Coral',
    description: 'Warm coral with a classic serif for reading.',
    accentId: 'coral',
    fontFamilyId: 'lora',
    fontScaleId: 'default',
  ),
];

AppFont get _currentFont =>
    kFontFamilies.firstWhere((f) => f.id == _fontFamilyId, orElse: () => kFontFamilies.first);

double get _currentScale =>
    kFontScales.firstWhere((s) => s.id == _fontScaleId, orElse: () => kFontScales[1]).factor;

TextStyle display(double size, Color color) =>
    GoogleFonts.archivoBlack(fontSize: size * _currentScale, color: color, height: 1.25);

TextStyle body(double size, Color color,
        {FontWeight weight = FontWeight.w400, double height = 1.55}) =>
    GoogleFonts.getFont(_currentFont.googleFontsFamily,
        fontSize: size * _currentScale, color: color, fontWeight: weight, height: height);

TextStyle label(Color color) => GoogleFonts.getFont(_currentFont.googleFontsFamily,
    fontSize: 10 * _currentScale,
    color: color,
    fontWeight: FontWeight.w800,
    letterSpacing: 2,
    height: 1.4);

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.violet,
    brightness: brightness,
    primary: dark ? currentAccent.dark : currentAccent.light,
    surface: dark ? Brand.base : Brand.cream,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? Brand.deep : Brand.cream,
    splashFactory: InkSparkle.splashFactory,
    textTheme: GoogleFonts.interTextTheme(
        brightness == Brightness.dark ? ThemeData.dark().textTheme : null),
  );
}

/// Surfaces used by the card stack.
class Surfaces {
  static Color card(bool dark) =>
      dark ? Colors.white.withValues(alpha: 0.04) : Colors.white;

  /// A fully opaque surface for anything that floats above other content —
  /// modal bottom sheets, dialogs — where [card]'s near-transparent dark-mode
  /// fill let whatever's underneath bleed through and made the sheet's own
  /// text unreadable.
  static Color sheet(bool dark) => dark ? Brand.base : Colors.white;

  static Color cardBorder(bool dark) => dark
      ? currentAccent.dark.withValues(alpha: 0.18)
      : Brand.base.withValues(alpha: 0.10);

  static Color accentCard(bool dark) =>
      dark ? currentAccent.dark.withValues(alpha: 0.07) : Brand.creamCard;

  static Color accentBorder(bool dark) => dark
      ? currentAccent.dark.withValues(alpha: 0.28)
      : currentAccent.light.withValues(alpha: 0.42);

  static Color accent(bool dark) => dark ? currentAccent.dark : currentAccent.light;
  static Color accentText(bool dark) => dark ? currentAccent.pale : Brand.base;
  static Color heading(bool dark) => dark ? Colors.white : Brand.base;
  static Color bodyText(bool dark) => dark ? Brand.bodyDark : Brand.base;
  static Color muted(bool dark) => dark ? Brand.mutedDark : Brand.mutedLight;
  static Color eyebrow(bool dark) => dark ? currentAccent.dark : currentAccent.deep;

  static BoxDecoration pageBackground(bool dark) {
    if (!dark) return const BoxDecoration(color: Brand.cream);
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Brand.deep, Brand.base, Brand.violet],
        stops: [0.0, 0.45, 1.0],
      ),
    );
  }
}
