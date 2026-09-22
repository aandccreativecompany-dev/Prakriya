import 'package:flutter/material.dart';

import '../models.dart';
import '../services/auth_service.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'module_picker_screen.dart';

/// First-run flow: welcome, name, a short quiz that sets a preset, a
/// time-commitment question, then the module picker. Runs once — retakeable
/// later from Settings.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

const _focusOptions = [
  ('doing', 'Getting things done', 'Top 3, habits, focus'),
  ('outcome', 'Engineering an outcome', 'Journaling, vision board'),
  ('consistent', 'Staying consistent', 'Streaks, gentle reminders'),
  ('steady', 'Feeling steadier', 'Mood, gratitude, reflection'),
];

const _timeOptions = [
  ('5', 'Just a couple minutes', 'One quick check-in a day'),
  ('15', 'About 15 minutes', 'Enough to plan and reflect'),
  ('30', 'Half an hour or so', 'Room for scripting and journaling too'),
  ('60', 'As much as it takes', "I'm building a real practice"),
];

const _totalSteps = 7;

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  late final _nameController =
      TextEditingController(text: store.userName);
  int _step = 0;
  late final Set<String> _focus = store.focusAreas.toSet();
  String _timeCommitment = store.dailyTimeCommitment;
  String _avatarGender = store.avatarGender;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleFocus(String id) {
    // Any number of these can apply at once — there were only ever 4 on
    // offer, so capping at 2 just blocked people from picking what was
    // actually true for them.
    setState(() {
      if (_focus.contains(id)) {
        _focus.remove(id);
      } else {
        _focus.add(id);
      }
    });
  }

  String _presetFromFocus() {
    if (_focus.contains('outcome')) return kPresetManifest;
    if (_focus.contains('doing') && !_focus.contains('steady')) return kPresetFocus;
    return kPresetBalance;
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      store.setAvatarGender(_avatarGender);
      store.completeOnboarding(
        userName: _nameController.text,
        focusAreas: _focus.toList(),
        dailyTimeCommitment: _timeCommitment,
        preset: _presetFromFocus(),
      );
      widget.onDone();
      return;
    }
    setState(() => _step++);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.animateToPage(_step,
        duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _WelcomeStep(onStart: _next),
              _NameStep(controller: _nameController, onBack: _back, onNext: _next),
              _AvatarStep(
                selected: _avatarGender,
                onSelect: (v) => setState(() => _avatarGender = v),
                onBack: _back,
                onNext: _next,
              ),
              _QuizStep(
                selected: _focus,
                onToggle: _toggleFocus,
                onBack: _back,
                onNext: _next,
              ),
              _TimeStep(
                selected: _timeCommitment,
                onSelect: (v) => setState(() => _timeCommitment = v),
                onBack: _back,
                onNext: _next,
              ),
              _ModuleStep(onBack: _back, onNext: _next),
              _SignInStep(onBack: _back, onDone: _next),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step; // 1-based
  final VoidCallback onBack;
  const _StepHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, color: Surfaces.bodyText(dark))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: step / _totalSteps,
              minHeight: 3,
              backgroundColor: Surfaces.muted(dark).withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation(Surfaces.accent(dark)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$step/$_totalSteps',
            style: body(11, Surfaces.muted(dark), weight: FontWeight.w700)),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  final VoidCallback onStart;
  const _WelcomeStep({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 8, 26, 26),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wb_twilight, color: Surfaces.accent(dark), size: 64),
                  const SizedBox(height: 24),
                  Text('PRAKRIYĀ',
                      style: display(30, Surfaces.heading(dark))
                          .copyWith(letterSpacing: .5)),
                  const SizedBox(height: 10),
                  Text('GROWTH MINDSET, MADE PRACTICAL',
                      style: label(Surfaces.accent(dark))),
                  const SizedBox(height: 22),
                  Text(
                    'A daily planner that holds both sides: real tasks and real mindset work. Set it up once — it opens on today, every day after.',
                    textAlign: TextAlign.center,
                    style: body(14, Surfaces.bodyText(dark), height: 1.7),
                  ),
                ],
              ),
            ),
          ),
          GoldButton(labelText: "Let's set it up", onPressed: onStart),
          const SizedBox(height: 10),
          Text('No account needed — everything stays on this phone.',
              style: body(11.5, Surfaces.muted(dark)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _NameStep({required this.controller, required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 1, onBack: onBack),
          const SizedBox(height: 22),
          Text('FIRST THINGS FIRST', style: label(Surfaces.eyebrow(dark))),
          const SizedBox(height: 12),
          Text('What should we call you?',
              style: display(23, Surfaces.heading(dark))),
          const SizedBox(height: 8),
          Text("We'll use it to greet you here — nothing leaves this phone.",
              style: body(12.5, Surfaces.muted(dark))),
          const SizedBox(height: 24),
          ModuleCard(
            child: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => onNext(),
              style: display(20, Surfaces.heading(dark)),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Your name',
                hintStyle: display(20, Surfaces.muted(dark)),
              ),
            ),
          ),
          const Spacer(),
          GoldButton(labelText: 'Continue', onPressed: onNext),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: onNext,
              child: Text("I'd rather skip this",
                  style: body(12.5, Surfaces.muted(dark), weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the user pick which cartoon character greets them on every app
/// open — a small personalization touch that also feeds the mascot's
/// pronoun-free emoji choice later on.
class _AvatarStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _AvatarStep({
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 2, onBack: onBack),
          const SizedBox(height: 22),
          Text('YOUR DAILY GREETER', style: label(Surfaces.eyebrow(dark))),
          const SizedBox(height: 12),
          Text('Who should greet you each time you open the app?',
              style: display(21, Surfaces.heading(dark))),
          const SizedBox(height: 8),
          Text('A friendly little character with a welcome message — your pick.',
              style: body(12.5, Surfaces.muted(dark))),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _AvatarChoiceCard(
                  emoji: '👧',
                  labelText: 'Girl',
                  selected: selected == 'girl',
                  onTap: () => onSelect('girl'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _AvatarChoiceCard(
                  emoji: '🧑',
                  labelText: 'Boy',
                  selected: selected == 'boy',
                  onTap: () => onSelect('boy'),
                ),
              ),
            ],
          ),
          const Spacer(),
          GoldButton(labelText: 'Continue', onPressed: onNext),
        ],
      ),
    );
  }
}

class _AvatarChoiceCard extends StatelessWidget {
  final String emoji;
  final String labelText;
  final bool selected;
  final VoidCallback onTap;
  const _AvatarChoiceCard({
    required this.emoji,
    required this.labelText,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Surfaces.accent(dark)
                : Surfaces.accent(dark).withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Surfaces.accent(dark).withValues(alpha: 0.09)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text(labelText,
                style: body(13.5, Surfaces.heading(dark), weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _QuizStep extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _QuizStep({
    required this.selected,
    required this.onToggle,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 3, onBack: onBack),
          const SizedBox(height: 22),
          Text('WHAT MATTERS MOST RIGHT NOW', style: label(Surfaces.eyebrow(dark))),
          const SizedBox(height: 12),
          Text('What are you here to work on?',
              style: display(23, Surfaces.heading(dark))),
          const SizedBox(height: 8),
          Text('Pick up to two. You can change this any time in Settings.',
              style: body(12.5, Surfaces.muted(dark))),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              children: [
                for (final option in _focusOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PickCard(
                      title: option.$2,
                      subtitle: option.$3,
                      selected: selected.contains(option.$1),
                      onTap: () => onToggle(option.$1),
                    ),
                  ),
              ],
            ),
          ),
          GoldButton(labelText: 'Continue', onPressed: onNext),
        ],
      ),
    );
  }
}

class _TimeStep extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _TimeStep({
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 4, onBack: onBack),
          const SizedBox(height: 22),
          Text('YOUR PACE', style: label(Surfaces.eyebrow(dark))),
          const SizedBox(height: 12),
          Text('How much time can you give this each day?',
              style: display(21, Surfaces.heading(dark))),
          const SizedBox(height: 8),
          Text("There's no wrong answer — this just shapes what we show you first.",
              style: body(12.5, Surfaces.muted(dark))),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(
              children: [
                for (final option in _timeOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PickCard(
                      title: option.$2,
                      subtitle: option.$3,
                      selected: selected == option.$1,
                      onTap: () => onSelect(option.$1),
                    ),
                  ),
              ],
            ),
          ),
          GoldButton(labelText: 'Continue', onPressed: onNext),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _PickCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Surfaces.accent(dark)
                : Surfaces.accent(dark).withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
          color: selected
              ? Surfaces.accent(dark).withValues(alpha: 0.09)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: body(15, Surfaces.heading(dark), weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: body(12, Surfaces.muted(dark))),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    color: Surfaces.accent(dark), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 13, color: Brand.deep),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModuleStep extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _ModuleStep({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 5, onBack: onBack),
          const SizedBox(height: 22),
          Text('Your daily cards', style: display(23, Surfaces.heading(dark))),
          const SizedBox(height: 8),
          Text('Based on your answers. Drag to reorder, switch off what you don\'t want.',
              style: body(12.5, Surfaces.muted(dark))),
          const SizedBox(height: 20),
          const Expanded(child: SingleChildScrollView(child: ModulePickerBody())),
          GoldButton(labelText: 'Continue', onPressed: onNext),
        ],
      ),
    );
  }
}

/// Last onboarding step — signing in with Google is required to finish
/// onboarding and reach the home screen. This also gets data backup for
/// free (see CloudSync): everything entered — habits, priorities, journal,
/// wallet — backs up automatically under the signed-in account, so a new
/// phone or reinstall doesn't lose it. There is no "skip" here on purpose;
/// once signed in, a user can still sign out later from Settings without
/// losing local access, but the app cannot be set up for the first time
/// without an account.
class _SignInStep extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onDone;
  const _SignInStep({required this.onBack, required this.onDone});

  @override
  State<_SignInStep> createState() => _SignInStepState();
}

class _SignInStepState extends State<_SignInStep> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final user = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (user != null) {
      widget.onDone();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't sign in — check your connection and try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(step: 6, onBack: widget.onBack),
          const SizedBox(height: 22),
          Icon(Icons.cloud_sync_outlined, color: Surfaces.accent(dark), size: 34),
          const SizedBox(height: 16),
          Text('Sign in to continue', style: display(23, Surfaces.heading(dark))),
          const SizedBox(height: 8),
          Text(
            "One last step — sign in with Google to finish setting up Prakriyā. "
            'Everything you enter — habits, priorities, journal, wallet — backs up '
            "automatically to your account, so a new phone or reinstall never loses it.",
            style: body(13, Surfaces.muted(dark)).copyWith(height: 1.5),
          ),
          const Spacer(),
          GoldButton(
            labelText: _busy ? 'Signing in…' : 'Sign in with Google',
            onPressed: _busy ? () {} : () => _signIn(),
          ),
        ],
      ),
    );
  }
}
