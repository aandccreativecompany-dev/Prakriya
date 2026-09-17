/// Single source of truth for the app's own version, as shown to the user
/// (Settings > About) and compared against GitHub Releases by
/// [UpdateChecker]. `pubspec.yaml`'s `version:` field is what Android/iOS
/// actually ship and is bumped separately at build time — this constant is
/// the one extra manual step release day needs, kept deliberately simple
/// (no plugin, no platform channel) so a version check never costs the app
/// a single extra byte of native code.
const String kAppVersion = '0.8.0';
