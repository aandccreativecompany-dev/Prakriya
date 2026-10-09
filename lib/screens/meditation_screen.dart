import 'package:flutter/material.dart';

import '../services/extras.dart';
import '../services/meditation.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A meditation tab: a breathing orb, a session timer and background sounds.
/// The session itself lives in [meditation], so it keeps running when you
/// switch to another tab.
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: extras.musicUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: Surfaces.pageBackground(dark),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[meditation, extras]),
            builder: (context, _) {
              final today = extras.meditationMinutesOn(DateTime.now());
              final streak = extras.meditationStreak;
              final selected = extras.meditationSound;
              return Column(
                children: [
                  ScreenHeader(
                    icon: Icons.self_improvement,
                    title: 'Meditate',
                    subtitle: today == 0
                        ? 'A few quiet minutes, with or without sound.'
                        : '$today min today${streak > 1 ? ' · $streak-day streak' : ''}',
                    showBackButton: false,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        Center(
                          child: _BreathingOrb(
                            active: meditation.running,
                            paused: meditation.paused,
                            clock: meditation.clock,
                            dark: dark,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: meditation.progress,
                            minHeight: 6,
                            backgroundColor:
                                Surfaces.accent(dark).withValues(alpha: 0.14),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Surfaces.accent(dark)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final m in MeditationSession.lengths)
                              ChoiceChip(
                                label: Text('$m min'),
                                selected: meditation.minutes == m,
                                onSelected: meditation.active
                                    ? null
                                    : (_) => meditation.pickLength(m),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: meditation.running
                                    ? meditation.pause
                                    : meditation.start,
                                child: Text(meditation.running
                                    ? 'Pause'
                                    : (meditation.paused ? 'Resume' : 'Begin')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: meditation.active ? meditation.reset : null,
                                child: const Text('End session'),
                              ),
                            ),
                          ],
                        ),
                        if (meditation.message != null) ...[
                          const SizedBox(height: 12),
                          Text(meditation.message!,
                              style: body(13, Surfaces.accentText(dark),
                                  weight: FontWeight.w600)),
                        ],
                        const SizedBox(height: 22),
                        Text('SOUND', style: label(Surfaces.muted(dark))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final s in kMeditationSounds)
                              ChoiceChip(
                                label: Text(s.label),
                                selected: selected == s.key,
                                onSelected: (_) => meditation.chooseSound(s.key),
                              ),
                          ],
                        ),
                        if (selected == 'link') ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _urlController,
                            keyboardType: TextInputType.url,
                            autocorrect: false,
                            onChanged: (v) => extras.setMeditationPrefs(url: v),
                            style: body(13.5, Surfaces.bodyText(dark)),
                            decoration: InputDecoration(
                              hintText: 'Paste a direct audio link (https://...)',
                              hintStyle: body(13, Surfaces.muted(dark)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Works with direct links to mp3, wav or similar audio files.',
                              style: body(11, Surfaces.muted(dark))),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.volume_down, size: 20, color: Surfaces.muted(dark)),
                            Expanded(
                              child: Slider(
                                value: extras.meditationVolume,
                                onChanged: meditation.setVolume,
                              ),
                            ),
                            Icon(Icons.volume_up, size: 20, color: Surfaces.muted(dark)),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: selected == 'none' ? null : meditation.toggleMusic,
                            icon: Icon(
                                meditation.musicPlaying ? Icons.stop : Icons.play_arrow,
                                size: 20),
                            label: Text(meditation.musicPlaying
                                ? 'Stop sound'
                                : 'Play sound only'),
                          ),
                        ),
                        const SizedBox(height: 22),
                        ModuleCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                    value: '$today', unit: 'min today', dark: dark),
                              ),
                              Expanded(
                                child: _Stat(
                                    value: '$streak', unit: 'day streak', dark: dark),
                              ),
                              Expanded(
                                child: _Stat(
                                    value: '${extras.totalMeditationMinutes}',
                                    unit: 'min total',
                                    dark: dark),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                            'Tip: breathe in as the circle grows and out as it shrinks. When your mind wanders, gently come back to the breath. That return is the practice.',
                            style: body(12.5, Surfaces.muted(dark))),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String unit;
  final bool dark;
  const _Stat({required this.value, required this.unit, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: display(20, Surfaces.heading(dark))),
        const SizedBox(height: 2),
        Text(unit,
            textAlign: TextAlign.center,
            style: body(11, Surfaces.muted(dark))),
      ],
    );
  }
}

class _BreathingOrb extends StatefulWidget {
  final bool active;
  final bool paused;
  final String clock;
  final bool dark;
  const _BreathingOrb({
    required this.active,
    required this.paused,
    required this.clock,
    required this.dark,
  });

  @override
  State<_BreathingOrb> createState() => _BreathingOrbState();
}

class _BreathingOrbState extends State<_BreathingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BreathingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Surfaces.accent(widget.dark);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final eased = Curves.easeInOut.transform(_controller.value);
        final scale = 0.74 + 0.26 * eased;
        String hint;
        if (!widget.active) {
          hint = widget.paused ? 'Paused' : 'Ready when you are';
        } else {
          hint = _controller.status == AnimationStatus.reverse
              ? 'Breathe out'
              : 'Breathe in';
        }
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: 0.35),
                        accent.withValues(alpha: 0.10),
                      ],
                    ),
                    border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.clock,
                      style: display(34, Surfaces.heading(widget.dark))),
                  const SizedBox(height: 4),
                  Text(hint,
                      style: body(13, Surfaces.muted(widget.dark),
                          weight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
