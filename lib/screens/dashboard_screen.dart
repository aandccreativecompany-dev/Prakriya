import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'quote_screen.dart';
import 'settings_screen.dart';

/// The true landing page — greeting, today's mantra, and an at-a-glance
/// summary, all in one place instead of being repeated at the top of every
/// section. Each other section is reached from here (or the bottom nav)
/// as its own separate, focused screen.
class DashboardScreen extends StatelessWidget {
  final List<HomePageSection> sections;
  final void Function(String sectionKey) onOpenSection;
  const DashboardScreen({super.key, required this.sections, required this.onOpenSection});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still up';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Winding down';
  }

  IconData _sectionIcon(String key) {
    switch (key) {
      case 'productivity':
        return Icons.checklist_rounded;
      case 'outcome':
        return Icons.auto_awesome;
      case 'finance':
        return Icons.account_balance_wallet_outlined;
      case 'health':
        return Icons.favorite_border;
      case 'mindset':
        return Icons.psychology_alt_outlined;
      case 'relationships':
        return Icons.diversity_1_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateLine =
        '${dayNames[today.weekday - 1]} ${today.day} ${monthNames[today.month - 1]}';
    final done = store.todaysTasks.where((t) => t.done).length;
    final total = store.todaysTasks.length;
    final momentum = store.weeklyMomentum();
    final greeting = _greeting();
    final name = store.userName;
    final mascotGreeting = kMascotGreetings[
        DateTime.now().millisecondsSinceEpoch % kMascotGreetings.length];

    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                key: const ValueKey('dashboardList'),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateLine.toUpperCase(), style: label(Surfaces.muted(dark))),
                            const SizedBox(height: 8),
                            Text(name.isEmpty ? greeting : '$greeting, $name',
                                style: display(26, Surfaces.heading(dark))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        icon: Icon(Icons.settings_outlined, color: Surfaces.muted(dark), size: 22),
                      ),
                    ],
                  ),
                  if (store.updateAvailable != null) ...[
                    const SizedBox(height: 14),
                    _UpdateBanner(dark: dark),
                  ],
                  if (!store.signInBannerDismissed) ...[
                    const SizedBox(height: 14),
                    _SignInBanner(dark: dark),
                  ],
                  const SizedBox(height: 90),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const QuoteScreen())),
                    child: ModuleCard(
                      accent: true,
                      eyebrow: 'Mantra of the day',
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.mantraEntryOfTheDay.text,
                              style: display(17, Surfaces.accentText(dark)),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Text(store.mantraEntryOfTheDay.source,
                              style: body(11, Surfaces.accentText(dark).withValues(alpha: 0.7),
                                  weight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Today',
                          value: total == 0 ? '—' : '$done/$total',
                          sub: 'priorities',
                          icon: Icons.check_circle_outline,
                          dark: dark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Habits',
                          value: '${store.habitsDoneToday}/${store.habits.length}',
                          sub: 'done today',
                          icon: Icons.local_fire_department_outlined,
                          dark: dark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          label: 'Streak',
                          value: '${momentum.bestStreak}',
                          sub: momentum.bestStreak == 1 ? 'day' : 'days',
                          icon: Icons.emoji_events_outlined,
                          dark: dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('YOUR SECTIONS', style: label(Surfaces.muted(dark))),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      for (final section in sections)
                        _SectionTile(
                          title: section.title,
                          icon: _sectionIcon(section.key),
                          performance: store.sectionPerformance(section.key),
                          dark: dark,
                          onTap: () => onOpenSection(section.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const AboutScreen())),
                    child: ModuleCard(
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Surfaces.muted(dark)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('About us — website & socials',
                                style: body(13, Surfaces.bodyText(dark), weight: FontWeight.w600)),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: Surfaces.muted(dark)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: const Alignment(0, -0.62),
                    child: SizedBox(
                      width: double.infinity,
                      height: 118,
                      child: GreetingMascot(
                        avatarGender: store.avatarGender,
                        greeting: mascotGreeting,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dismissible banner shown when [Store.checkForUpdate] finds a newer
/// GitHub release than this build. "Update" opens the Release page in the
/// browser (Play Store distribution isn't wired up, so there's no in-app
/// download path) — this is a notice, not a self-update mechanism.
class _UpdateBanner extends StatelessWidget {
  final bool dark;
  const _UpdateBanner({required this.dark});

  @override
  Widget build(BuildContext context) {
    final info = store.updateAvailable;
    if (info == null) return const SizedBox.shrink();
    return ModuleCard(
      accent: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(Icons.system_update_alt_rounded, color: Surfaces.accent(dark), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version ${info.version} is available',
                    style: body(13, Surfaces.accentText(dark), weight: FontWeight.w700)),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(info.url),
                      mode: LaunchMode.externalApplication),
                  child: Text('See what\'s new',
                      style: body(11.5, Surfaces.accent(dark), weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => store.dismissUpdate(),
            icon: Icon(Icons.close, size: 18, color: Surfaces.muted(dark)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// A dismissible nudge to sign in for cloud backup, shown while the user is
/// both signed out and hasn't already dismissed it (see
/// Store.signInBannerDismissed). Listens to Firebase's own auth stream
/// directly — rather than relying on `store` — so it disappears the moment
/// sign-in succeeds from Settings or onboarding, without needing auth state
/// threaded into the store.
class _SignInBanner extends StatefulWidget {
  final bool dark;
  const _SignInBanner({required this.dark});

  @override
  State<_SignInBanner> createState() => _SignInBannerState();
}

class _SignInBannerState extends State<_SignInBanner> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final user = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't sign in — try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.userChanges,
      initialData: AuthService.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.data != null) return const SizedBox.shrink();
        final dark = widget.dark;
        return ModuleCard(
          accent: true,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_sync_outlined, color: Surfaces.accent(dark), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Back up your data',
                        style: body(13, Surfaces.accentText(dark), weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('Sign in so nothing is lost if you switch phones.',
                        style: body(11.5, Surfaces.accentText(dark).withValues(alpha: 0.8))),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _busy ? null : _signIn,
                      child: Text(_busy ? 'Signing in…' : 'Sign in with Google',
                          style: body(11.5, Surfaces.accent(dark), weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => store.dismissSignInBanner(),
                icon: Icon(Icons.close, size: 18, color: Surfaces.muted(dark)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final bool dark;
  const _StatTile({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return ModuleCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Surfaces.accent(dark)),
          const SizedBox(height: 8),
          Text(value, style: display(18, Surfaces.heading(dark))),
          const SizedBox(height: 2),
          Text('$label · $sub',
              style: body(10, Surfaces.muted(dark), weight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// A section tile showing that section's own live performance — a
/// completion percentage (when the section has something to measure yet)
/// plus a short detail line — instead of just repeating the section name
/// as a second copy of the bottom-nav tab. See Store.sectionPerformance for
/// what each section actually measures.
class _SectionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final ({double? pct, String detail}) performance;
  final bool dark;
  final VoidCallback onTap;
  const _SectionTile({
    required this.title,
    required this.icon,
    required this.performance,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = performance.pct;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Surfaces.card(dark),
          border: Border.all(color: Surfaces.cardBorder(dark)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Surfaces.accent(dark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: body(12.5, Surfaces.heading(dark), weight: FontWeight.w700)),
                ),
                if (pct != null)
                  Text('${(pct * 100).round()}%',
                      style: body(11.5, Surfaces.accent(dark), weight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            if (pct != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: Surfaces.accent(dark).withValues(alpha: 0.12),
                  color: Surfaces.accent(dark),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(performance.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(10.5, Surfaces.muted(dark), weight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
