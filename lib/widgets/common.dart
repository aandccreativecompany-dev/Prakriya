import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Small "Saved." toast — a light, consistent confirmation after any quick
/// edit across the app, so saving never feels invisible without forcing a
/// manual save step for every tiny action.
void toastSaved(BuildContext context, {String label = 'Saved'}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 1100),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Brand.deep,
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Brand.gold, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    ));
}

/// Consistent page header used across the app's secondary screens — a back
/// button, an icon in a soft color badge, a big title, and an optional
/// one-line subtitle. Replaces the old plain "back arrow + small label" row
/// with something that reads as a designed screen rather than a stub.
class ScreenHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  /// False for a screen reached via a bottom-nav tab rather than pushed on
  /// the Navigator — there's nothing to pop back to, so showing the arrow
  /// would just be a dead button.
  final bool showBackButton;
  const ScreenHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBackButton)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: Surfaces.bodyText(dark)),
              ),
            const Spacer(),
            if (actions != null) ...actions!,
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Surfaces.accent(dark).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Surfaces.accent(dark), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: display(22, Surfaces.heading(dark))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: body(12.5, Surfaces.muted(dark))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Wraps a screen's body in a gentle fade + rise-in on first appearance —
/// the small bit of "the app is alive" motion used consistently across
/// secondary screens instead of content just snapping into place.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
      .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Icon lookup for `kHabitIconNames` — kept alongside the model so a saved
/// icon name always resolves to something even if the curated set changes.
const Map<String, IconData> kHabitIcons = {
  'edit_note': Icons.edit_note,
  'directions_walk': Icons.directions_walk,
  'self_improvement': Icons.self_improvement,
  'water_drop': Icons.water_drop_outlined,
  'menu_book': Icons.menu_book_outlined,
  'bedtime': Icons.bedtime_outlined,
  'no_cell': Icons.phonelink_erase_outlined,
  'restaurant': Icons.restaurant_outlined,
  'fitness_center': Icons.fitness_center,
  'favorite': Icons.favorite_outline,
  'wb_sunny': Icons.wb_sunny_outlined,
  'volunteer_activism': Icons.volunteer_activism_outlined,
};

IconData habitIconFor(int index) =>
    kHabitIcons[kHabitIconNames[index % kHabitIconNames.length]] ??
    Icons.edit_note;

/// A rotation of on-brand colors a habit can be tagged with.
const List<Color> kHabitColors = [
  Brand.gold,
  Brand.violet,
  Brand.goldDeep,
  Brand.mutedDark,
  Brand.goldLight,
];

Color habitColorFor(int index) => kHabitColors[index % kHabitColors.length];

/// Small colored circle carrying a habit's icon — used on the home card and
/// the detail screen so a habit reads at a glance, not just as a line of text.
class HabitBadge extends StatelessWidget {
  final int iconIndex;
  final int colorIndex;
  final double size;
  const HabitBadge({
    super.key,
    required this.iconIndex,
    required this.colorIndex,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final color = habitColorFor(colorIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(habitIconFor(iconIndex), color: color, size: size * 0.52),
    );
  }
}

/// The card shell every module on the home stack sits in.
class ModuleCard extends StatelessWidget {
  final String? eyebrow;
  final Widget child;
  final bool accent;
  final EdgeInsets padding;

  const ModuleCard({
    super.key,
    this.eyebrow,
    required this.child,
    this.accent = false,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color:
            accent ? Surfaces.accentCard(dark) : Surfaces.card(dark),
        border: Border.all(
            color: accent
                ? Surfaces.accentBorder(dark)
                : Surfaces.cardBorder(dark)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(eyebrow!.toUpperCase(), style: label(Surfaces.eyebrow(dark))),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String labelText;
  final VoidCallback onPressed;

  const GoldButton({super.key, required this.labelText, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Surfaces.accent(dark),
          foregroundColor: Brand.deep,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const StadiumBorder(),
          textStyle: body(14.5, Brand.deep, weight: FontWeight.w700),
        ),
        child: Text(labelText),
      ),
    );
  }
}

class CheckSquare extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final double size;

  const CheckSquare({
    super.key,
    required this.checked,
    required this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Surfaces.accent(dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked ? accent : Colors.transparent,
          border: Border.all(
              color: checked ? accent : accent.withValues(alpha: 0.45),
              width: 1.5),
          borderRadius: BorderRadius.circular(7),
        ),
        child: checked
            ? Icon(Icons.check, size: size * 0.62, color: Brand.deep)
            : null,
      ),
    );
  }
}

/// Bottom-sheet editor for a habit's name, icon and color — used both when
/// adding a new habit and when restyling an existing one. Pops
/// `(name, iconIndex, colorIndex)` on save, or null if dismissed.
class HabitEditorSheet extends StatefulWidget {
  final String initialName;
  final int initialIcon;
  final int initialColor;
  const HabitEditorSheet({
    super.key,
    this.initialName = '',
    this.initialIcon = 0,
    this.initialColor = 0,
  });

  @override
  State<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends State<HabitEditorSheet> {
  late final _controller = TextEditingController(text: widget.initialName);
  late int _icon = widget.initialIcon;
  late int _color = widget.initialColor;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - keyboard - 60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            // Opaque — a bottom sheet floats over whatever screen is behind
            // it, and Surfaces.card's near-transparent dark-mode fill let
            // that content bleed through and made this sheet's own text
            // unreadable.
            color: Surfaces.sheet(dark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.initialName.isEmpty ? 'New habit' : 'Edit habit',
                  style: display(18, Surfaces.heading(dark))),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: body(15, Surfaces.bodyText(dark), weight: FontWeight.w600),
              decoration: const InputDecoration(hintText: 'Walk 30 minutes'),
            ),
            const SizedBox(height: 18),
            Text('ICON', style: label(Surfaces.eyebrow(dark))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < kHabitIconNames.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _icon = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _icon == i
                            ? habitColorFor(_color).withValues(alpha: 0.22)
                            : Colors.transparent,
                        border: Border.all(
                          color: _icon == i
                              ? habitColorFor(_color)
                              : Surfaces.muted(dark).withValues(alpha: 0.25),
                          width: _icon == i ? 2 : 1,
                        ),
                      ),
                      child: Icon(habitIconFor(i),
                          size: 18,
                          color: _icon == i
                              ? habitColorFor(_color)
                              : Surfaces.muted(dark)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('COLOR', style: label(Surfaces.eyebrow(dark))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                for (var i = 0; i < kHabitColors.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _color = i),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kHabitColors[i],
                        border: Border.all(
                          color: _color == i
                              ? Surfaces.heading(dark)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
                  ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GoldButton(
                labelText: widget.initialName.isEmpty ? 'Add habit' : 'Save',
                onPressed: () {
                  if (_controller.text.trim().isEmpty) return;
                  Navigator.pop(context, (_controller.text, _icon, _color));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Positive greetings the walking mascot can open with. Picked by day so it
/// changes but stays stable through a single session.
const List<String> kMascotGreetings = [
  "Hi! Ready to make today count?",
  "Welcome back — let's build some momentum.",
  "So glad you're here. Small steps, big shifts.",
  "You showed up — that's the hardest part, done.",
  "Today's a clean page. Let's write something good.",
  "Welcome back! Your future self says thanks.",
  "Hello again! One good habit at a time.",
  "Great to see you. Let's keep the streak alive.",
];

/// A small cartoon figure that walks from the left edge to the right edge of
/// the screen once, carrying a speech bubble with a positive greeting. Shown
/// every time the home screen opens (per the onboarding avatar choice).
class GreetingMascot extends StatefulWidget {
  final String avatarGender;
  final String greeting;
  /// Called once, right when the walk-across animation finishes and this
  /// widget collapses to nothing. Lets a parent that reserved layout space
  /// for the animation (see DashboardScreen) shrink that space back down
  /// instead of leaving a permanent empty gap once the mascot is gone.
  final VoidCallback? onDone;
  const GreetingMascot({
    super.key,
    required this.avatarGender,
    required this.greeting,
    this.onDone,
  });

  @override
  State<GreetingMascot> createState() => _GreetingMascotState();
}

class _GreetingMascotState extends State<GreetingMascot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..forward();
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _dismissed = true);
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _emoji => widget.avatarGender == 'boy' ? '🧑' : '👧';

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: SizedBox(
        height: 118,
        width: double.infinity,
        child: LayoutBuilder(
        builder: (context, constraints) {
          final travel = constraints.maxWidth - 64;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_controller.value);
              final x = 12 + travel * t;
              final bounce = (t * 18).remainder(1) < 0.5 ? 0.0 : -4.0;
              return Opacity(
                opacity: _controller.value > 0.92
                    ? (1 - (_controller.value - 0.92) / 0.08).clamp(0.0, 1.0)
                    : 1.0,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: x - 90,
                      top: 0,
                      width: 200,
                      child: Column(
                        children: [
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              // A solid fill regardless of theme, rather than the
                              // page's near-transparent card token — the bubble
                              // needs to read clearly against whatever's behind
                              // it (a busy dark gradient in dark mode included).
                              color: dark ? Brand.violet : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: dark
                                      ? Brand.gold.withValues(alpha: 0.4)
                                      : Brand.base.withValues(alpha: 0.10)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.greeting,
                              textAlign: TextAlign.center,
                              style: body(11.5, dark ? Colors.white : Brand.base,
                                  weight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(Icons.arrow_drop_down,
                              color: dark ? Brand.violet : Colors.white, size: 20),
                        ],
                      ),
                    ),
                    Positioned(
                      left: x,
                      top: 58 + bounce,
                      child: Text(_emoji, style: const TextStyle(fontSize: 34)),
                    ),
                  ],
                ),
              );
            },
          );
        },
        ),
      ),
    );
  }
}

/// Hand-rolled gold-on-ink toggle, matching the designed switches.
class BrandSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const BrandSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Surfaces.accent(dark);
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 25,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value
                  ? accent
                  : Surfaces.muted(dark).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  color: value ? Brand.deep : Surfaces.muted(dark),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
