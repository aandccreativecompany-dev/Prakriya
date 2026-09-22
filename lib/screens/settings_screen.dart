import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_version.dart';
import '../models.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync.dart';
import '../services/home_widget_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'feedback_screen.dart';
import 'lock_screen.dart';
import 'module_picker_screen.dart';
import 'weekly_review_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _export(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Backup copied. Paste it somewhere safe.')));
  }

  Future<void> _import(BuildContext context) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore a backup',
            style: display(18, Surfaces.heading(dark))),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
              hintText: 'Paste your backup text here'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Restore')),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    final ok = await store.importJson(raw);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Backup restored.'
            : "That doesn't look like a Prakriyā backup.")));
  }

  Future<void> _retakeQuiz(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retake the setup quiz?'),
        content: const Text(
            'Your tasks, habits and history stay put — only your preset and card picks reset.',
            textAlign: TextAlign.justify),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retake')),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.retakeOnboarding();
    if (!context.mounted) return;
    // The root widget swaps to OnboardingScreen on its own once
    // onboardingComplete flips — just pop back to it.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final user = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (user != null) {
      toastSaved(context, label: 'Signed in — syncing your data');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't sign in — try again.")));
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await AuthService.instance.signOut();
    if (!mounted) return;
    setState(() => _busy = false);
    toastSaved(context, label: 'Signed out');
  }

  Future<void> _backUpNow() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    await CloudSync.instance.backUpNow(user.uid);
    if (!mounted) return;
    setState(() => _busy = false);
    toastSaved(context, label: 'Backed up to your account');
  }

  Future<void> _restoreFromCloud() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore from cloud backup?', style: display(16, Surfaces.heading(dark))),
        content: Text(
          'This replaces everything on this phone with your last cloud backup. '
          "Anything entered here since then that hasn't synced will be lost.",
          style: body(13, Surfaces.muted(dark)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Restore', style: body(13, Colors.redAccent, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    await CloudSync.instance.pullAndApply(user.uid);
    if (!mounted) return;
    setState(() => _busy = false);
    toastSaved(context, label: 'Restored from cloud');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: Surfaces.pageBackground(dark),
            child: SafeArea(
              child: FadeSlideIn(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                  children: [
                    const ScreenHeader(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('APPEARANCE', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              children: [
                                for (final option in const [
                                  ['system', 'Follow the phone'],
                                  ['light', 'Always light'],
                                  ['dark', 'Always dark'],
                                ])
                                  InkWell(
                                    onTap: () async {
                                      await store.setThemeMode(option[0]);
                                      if (context.mounted) toastSaved(context);
                                    },
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(option[1],
                                                style: body(
                                                    13.5, Surfaces.bodyText(dark),
                                                    weight: FontWeight.w500)),
                                          ),
                                          if (store.state.themeMode == option[0])
                                            Icon(Icons.check,
                                                size: 18,
                                                color: Surfaces.accent(dark)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('THEMES', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A quick-pick look — sets the color, font and text size together in one tap. Fine-tune each below if you want.',
                                  textAlign: TextAlign.justify,
                                  style: body(12, Surfaces.muted(dark)).copyWith(height: 1.4),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final preset in kThemePresets)
                                      _ThemePresetCard(
                                        preset: preset,
                                        selected: store.themeAccentId == preset.accentId &&
                                            store.fontFamilyId == preset.fontFamilyId &&
                                            store.fontScaleId == preset.fontScaleId,
                                        dark: dark,
                                        onTap: () async {
                                          await store.applyThemePreset(preset);
                                          if (context.mounted) {
                                            toastSaved(context, label: preset.label);
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('APP THEME COLOR', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pick the accent color used for icons, highlights and buttons throughout the app.',
                                  textAlign: TextAlign.justify,
                                  style: body(12, Surfaces.muted(dark)).copyWith(height: 1.4),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    for (final palette in kAccentPalettes)
                                      _ThemeColorSwatch(
                                        palette: palette,
                                        selected: store.themeAccentId == palette.id,
                                        dark: dark,
                                        onTap: () async {
                                          await store.setThemeAccent(palette.id);
                                          if (context.mounted) toastSaved(context);
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('TEXT STYLE', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose the reading font and text size used across the app.',
                                  style: body(12, Surfaces.muted(dark)),
                                ),
                                const SizedBox(height: 14),
                                Text('FONT', style: label(Surfaces.eyebrow(dark))),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    for (final font in kFontFamilies)
                                      _FontChip(
                                        label: font.label,
                                        googleFontsFamily: font.googleFontsFamily,
                                        selected: store.fontFamilyId == font.id,
                                        dark: dark,
                                        onTap: () async {
                                          await store.setFontFamilyChoice(font.id);
                                          if (context.mounted) toastSaved(context);
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text('TEXT SIZE', style: label(Surfaces.eyebrow(dark))),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    for (final scale in kFontScales) ...[
                                      Expanded(
                                        child: _FontSizeOption(
                                          scaleLabel: scale.label,
                                          selected: store.fontScaleId == scale.id,
                                          dark: dark,
                                          onTap: () async {
                                            await store.setFontScaleChoice(scale.id);
                                            if (context.mounted) toastSaved(context);
                                          },
                                        ),
                                      ),
                                      if (scale.id != kFontScales.last.id)
                                        const SizedBox(width: 10),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('STARTING SCREEN', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose which section opens first when you launch the app.',
                                  style: body(12, Surfaces.muted(dark)),
                                ),
                                const SizedBox(height: 10),
                                for (final section in kHomePageSections)
                                  InkWell(
                                    onTap: () async {
                                      await store.setDefaultPage(section.key);
                                      if (context.mounted) toastSaved(context);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(section.title,
                                                style: body(13.5, Surfaces.bodyText(dark),
                                                    weight: FontWeight.w500)),
                                          ),
                                          if (store.defaultPageKey == section.key)
                                            Icon(Icons.check,
                                                size: 18, color: Surfaces.accent(dark)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('YOUR RITUAL', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _NavRow(
                                  icon: Icons.view_agenda_outlined,
                                  title: 'Customize your cards',
                                  subtitle: 'Reorder or hide what shows on Today',
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const ModulePickerScreen())),
                                ),
                                _divider(dark),
                                _NavRow(
                                  icon: Icons.insights_outlined,
                                  title: 'Weekly momentum review',
                                  subtitle: 'The last 7 days, at a glance',
                                  onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const WeeklyReviewScreen())),
                                ),
                                _divider(dark),
                                _NavRow(
                                  icon: Icons.replay_outlined,
                                  title: 'Retake the setup quiz',
                                  subtitle: 'Reset your preset and card picks',
                                  onTap: () => _retakeQuiz(context),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('JOURNAL LOCK', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Local only — a privacy nudge for your evening reflection, not encryption.',
                                  style: body(12.5, Surfaces.muted(dark)),
                                ),
                                const SizedBox(height: 16),
                                if (store.hasPin) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('Unlock with biometrics',
                                            style: body(13.5, Surfaces.bodyText(dark),
                                                weight: FontWeight.w500)),
                                      ),
                                      Switch(
                                        value: store.biometricEnabled,
                                        activeTrackColor: Surfaces.accent(dark),
                                        onChanged: (v) async {
                                          await store.setBiometricEnabled(v);
                                          if (context.mounted) toastSaved(context);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(
                                    onPressed: () async {
                                      await store.clearPin();
                                      if (context.mounted) {
                                        toastSaved(context, label: 'PIN removed');
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        alignment: Alignment.centerLeft),
                                    child: Text('Remove PIN lock',
                                        style: body(13, Colors.redAccent,
                                            weight: FontWeight.w600)),
                                  ),
                                ] else
                                  GoldButton(
                                    labelText: 'Set a PIN',
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const LockScreen(mode: LockMode.setup))),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('HOME SCREEN WIDGET', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add the Prakriyā widget to your Android home screen, then choose what shows on it.',
                                  textAlign: TextAlign.justify,
                                  style: body(12.5, Surfaces.muted(dark)).copyWith(height: 1.4),
                                ),
                                const SizedBox(height: 14),
                                _WidgetToggleRow(
                                  label: "Today's habits checklist",
                                  value: store.widgetShowHabits,
                                  onChanged: (v) => store.setWidgetShowHabits(v),
                                ),
                                _divider(dark),
                                _WidgetToggleRow(
                                  label: 'Top to-do / priority',
                                  value: store.widgetShowPriorities,
                                  onChanged: (v) => store.setWidgetShowPriorities(v),
                                ),
                                _divider(dark),
                                _WidgetToggleRow(
                                  label: "Today's mantra",
                                  value: store.widgetShowMantra,
                                  onChanged: (v) => store.setWidgetShowMantra(v),
                                ),
                                if (store.widgetShowHabits && store.habits.isNotEmpty) ...[
                                  _divider(dark),
                                  const SizedBox(height: 4),
                                  Text('WHICH HABITS SHOW',
                                      style: label(Surfaces.eyebrow(dark))),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Pick specific habits, or leave all selected — the widget shows up to 5.',
                                    style: body(11.5, Surfaces.muted(dark)),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final h in store.habits)
                                        InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: () async {
                                            await store.toggleWidgetHabit(h.id);
                                            if (context.mounted) toastSaved(context);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: store.widgetHabitSelected(h.id)
                                                  ? Surfaces.accent(dark)
                                                      .withValues(alpha: 0.16)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: store.widgetHabitSelected(h.id)
                                                    ? Surfaces.accent(dark)
                                                    : Surfaces.accentBorder(dark),
                                              ),
                                            ),
                                            child: Text(h.name,
                                                style: body(
                                                    11.5,
                                                    store.widgetHabitSelected(h.id)
                                                        ? Surfaces.accent(dark)
                                                        : Surfaces.muted(dark),
                                                    weight: FontWeight.w600)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 14),
                                TextButton.icon(
                                  onPressed: () async {
                                    await HomeWidgetService.instance.forceRefresh();
                                    if (context.mounted) {
                                      toastSaved(context, label: 'Widget refreshed');
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft),
                                  icon: Icon(Icons.refresh,
                                      size: 16, color: Surfaces.accent(dark)),
                                  label: Text('Refresh widget now',
                                      style: body(13, Surfaces.accent(dark),
                                          weight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('FEEDBACK', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            padding: EdgeInsets.zero,
                            child: _NavRow(
                              icon: Icons.forum_outlined,
                              title: 'Send feedback or a fix request',
                              subtitle: 'Goes straight to the team\'s inbox',
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const FeedbackScreen())),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('ACCOUNT', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (AuthService.instance.isSignedIn) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.account_circle,
                                          size: 36, color: Brand.gold),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AuthService.instance.currentUser
                                                      ?.displayName ??
                                                  'Signed in',
                                              style: body(14,
                                                  Surfaces.heading(dark),
                                                  weight: FontWeight.w700),
                                            ),
                                            Text(
                                              AuthService.instance.currentUser
                                                      ?.email ??
                                                  '',
                                              style: body(
                                                  11.5, Surfaces.muted(dark)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Your data syncs to this account and follows you to any device you sign into.',
                                    textAlign: TextAlign.justify,
                                    style: body(12, Surfaces.muted(dark)).copyWith(height: 1.4),
                                  ),
                                  const SizedBox(height: 14),
                                  TextButton(
                                    onPressed: _busy ? null : _backUpNow,
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        alignment: Alignment.centerLeft),
                                    child: Text('Back up now',
                                        style: body(13, Surfaces.accent(dark),
                                            weight: FontWeight.w600)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(
                                    onPressed: _busy ? null : _restoreFromCloud,
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        alignment: Alignment.centerLeft),
                                    child: Text('Restore from cloud backup',
                                        style: body(13, Surfaces.muted(dark),
                                            weight: FontWeight.w600)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(
                                    onPressed: _busy ? null : _signOut,
                                    style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        alignment: Alignment.centerLeft),
                                    child: Text('Sign out',
                                        style: body(13, Colors.redAccent,
                                            weight: FontWeight.w600)),
                                  ),
                                ] else ...[
                                  Text(
                                    "You're signed out. Sign back in with Google to back your data up and sync it across your devices — your local entries on this phone are untouched either way.",
                                    textAlign: TextAlign.justify,
                                    style: body(12.5, Surfaces.muted(dark)).copyWith(height: 1.4),
                                  ),
                                  const SizedBox(height: 16),
                                  GoldButton(
                                    labelText: _busy
                                        ? 'Signing in…'
                                        : 'Sign in with Google',
                                    onPressed: _busy ? () {} : _signIn,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('YOUR DATA', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    AuthService.instance.isSignedIn
                                        ? 'Synced to your account, plus stored on this phone. You can still keep a manual backup below.'
                                        : 'Everything stays on this phone. There is no account and nothing is uploaded, so a lost or wiped phone loses your entries unless you keep a backup.',
                                    style: body(12.5, Surfaces.muted(dark))),
                                const SizedBox(height: 16),
                                GoldButton(
                                    labelText: 'Copy a backup',
                                    onPressed: () => _export(context)),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => _import(context),
                                  child: Text('Restore from a backup',
                                      style: body(13, Surfaces.accent(dark),
                                          weight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text('ABOUT', style: label(Surfaces.muted(dark))),
                          const SizedBox(height: 12),
                          ModuleCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
Text('Prakriyā $kAppVersion',
                                    style: body(13.5, Surfaces.bodyText(dark),
                                        weight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text('A and C Creative Ventures',
                                    style: body(12.5, Surfaces.muted(dark))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WidgetToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final Future<void> Function(bool) onChanged;
  const _WidgetToggleRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: body(13.5, Surfaces.bodyText(dark), weight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            activeTrackColor: Surfaces.accent(dark),
            onChanged: (v) async {
              await onChanged(v);
              if (context.mounted) toastSaved(context);
            },
          ),
        ],
      ),
    );
  }
}

Widget _divider(bool dark) => Divider(
      height: 1,
      color: Surfaces.cardBorder(dark),
      indent: 52,
    );

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Surfaces.accent(dark), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: body(13.5, Surfaces.bodyText(dark),
                          weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: body(11.5, Surfaces.muted(dark))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Surfaces.muted(dark), size: 18),
          ],
        ),
      ),
    );
  }
}

/// One curated theme preset — a small swatch-plus-"Aa" preview card so the
/// pick previews both the color and the font at a glance.
class _ThemePresetCard extends StatelessWidget {
  final AppThemePreset preset;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _ThemePresetCard({
    required this.preset,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = kAccentPalettes.firstWhere((p) => p.id == preset.accentId,
        orElse: () => kAccentPalettes.first);
    final font = kFontFamilies.firstWhere((f) => f.id == preset.fontFamilyId,
        orElse: () => kFontFamilies.first);
    final accentColor = dark ? palette.dark : palette.light;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? accentColor.withValues(alpha: 0.14) : Surfaces.card(dark),
          border: Border.all(
            color: selected ? accentColor : Surfaces.cardBorder(dark),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accentColor),
                ),
                const Spacer(),
                if (selected) Icon(Icons.check_circle, size: 16, color: accentColor),
              ],
            ),
            const SizedBox(height: 8),
            Text('Aa',
                style: GoogleFonts.getFont(font.googleFontsFamily,
                    fontSize: 18, fontWeight: FontWeight.w700, color: Surfaces.heading(dark))),
            const SizedBox(height: 4),
            Text(preset.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(11.5, Surfaces.bodyText(dark), weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(preset.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: body(10, Surfaces.muted(dark))),
          ],
        ),
      ),
    );
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  final AccentPalette palette;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _ThemeColorSwatch({
    required this.palette,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final swatchColor = dark ? palette.dark : palette.light;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: swatchColor,
              border: Border.all(
                color: selected ? Surfaces.heading(dark) : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: swatchColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: selected
                ? Icon(Icons.check,
                    color: dark ? Brand.base : Colors.white, size: 20)
                : null,
          ),
          const SizedBox(height: 6),
          Text(palette.label, style: body(10.5, Surfaces.muted(dark), weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A font-family option rendered IN that font, so the pick is a preview.
class _FontChip extends StatelessWidget {
  final String label;
  final String googleFontsFamily;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _FontChip({
    required this.label,
    required this.googleFontsFamily,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Surfaces.accent(dark).withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Surfaces.accent(dark) : Surfaces.accentBorder(dark),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.getFont(googleFontsFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Surfaces.accent(dark) : Surfaces.bodyText(dark)),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check, size: 14, color: Surfaces.accent(dark)),
            ],
          ],
        ),
      ),
    );
  }
}

/// One of the three text-size presets (Small / Default / Large).
class _FontSizeOption extends StatelessWidget {
  final String scaleLabel;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;
  const _FontSizeOption({
    required this.scaleLabel,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Surfaces.accent(dark).withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Surfaces.accent(dark) : Surfaces.accentBorder(dark),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(scaleLabel,
            style: body(13, selected ? Surfaces.accent(dark) : Surfaces.bodyText(dark),
                weight: FontWeight.w700)),
      ),
    );
  }
}
