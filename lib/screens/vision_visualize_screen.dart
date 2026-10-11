import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/extras.dart';
import '../services/meditation.dart';
import '../store.dart';
import '../theme.dart';
import '../vision_data.dart';
import 'vision_board_screen.dart' show visionTileColorFilter;

/// Full-screen "visualize" mode: one dream at a time, with its affirmation,
/// advancing on its own. A few quiet minutes of looking at what you want and
/// reading it in the present tense is the whole practice. Optional ambient
/// sound reuses the Meditate sounds.
class VisionVisualizeScreen extends StatefulWidget {
  final List<VisionItem> items;
  const VisionVisualizeScreen({super.key, required this.items});

  @override
  State<VisionVisualizeScreen> createState() => _VisionVisualizeScreenState();
}

class _VisionVisualizeScreenState extends State<VisionVisualizeScreen> {
  static const _dwell = Duration(seconds: 8);

  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;
  bool _playing = true;
  bool _startedMusic = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_startedMusic && !meditation.active) {
      unawaited(meditation.stopMusic());
    }
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_playing || widget.items.length < 2) return;
    _timer = Timer.periodic(_dwell, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % widget.items.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _toggleSound() async {
    if (meditation.musicPlaying) {
      await meditation.stopMusic();
    } else {
      final key = extras.meditationSound;
      if (key == 'none' || key == 'link') {
        await meditation.chooseSound('pad');
      } else {
        await meditation.playMusic();
      }
      _startedMusic = true;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      backgroundColor: Colors.black,
      body: items.isEmpty
          ? const SizedBox.shrink()
          : Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: items.length,
                  onPageChanged: (i) {
                    setState(() => _page = i);
                    _restartTimer();
                  },
                  itemBuilder: (context, i) => _VisualizePage(item: items[i]),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              for (var i = 0; i < items.length; i++)
                                Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                    decoration: BoxDecoration(
                                      color: i <= _page
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: _playing ? 'Pause' : 'Play',
                            onPressed: () {
                              setState(() => _playing = !_playing);
                              _restartTimer();
                            },
                            icon: Icon(
                                _playing
                                    ? Icons.pause_circle_outline
                                    : Icons.play_circle_outline,
                                color: Colors.white,
                                size: 32),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            tooltip: meditation.musicPlaying ? 'Sound off' : 'Sound on',
                            onPressed: _toggleSound,
                            icon: Icon(
                                meditation.musicPlaying
                                    ? Icons.volume_up_outlined
                                    : Icons.volume_off_outlined,
                                color: Colors.white,
                                size: 28),
                          ),
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: () async {
                              final item = items[_page];
                              await store.updateVisionItemDetails(item,
                                  achieved: !item.achieved);
                              if (mounted) setState(() {});
                            },
                            icon: Icon(
                                items[_page].achieved
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: Brand.gold,
                                size: 20),
                            label: Text(
                                items[_page].achieved ? 'Achieved' : 'Mark achieved',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _VisualizePage extends StatelessWidget {
  final VisionItem item;
  const _VisualizePage({required this.item});

  @override
  Widget build(BuildContext context) {
    final area = visionAreaFor(item.area);
    final accent = area?.color ?? Brand.violet;
    final path = item.imagePath;
    final countdown = item.achieved ? '' : visionCountdownLabel(item);
    Widget background;
    if (path != null && File(path).existsSync()) {
      Widget image = Image.file(File(path), fit: BoxFit.cover);
      final filter = visionTileColorFilter(item.filter);
      if (filter != null) image = ColorFiltered(colorFilter: filter, child: image);
      background = SizedBox.expand(child: image);
    } else {
      background = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.85), Brand.deep],
          ),
        ),
        child: const SizedBox.expand(),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.78),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 96),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (area != null || countdown.isNotEmpty || item.achieved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (area != null) _tag(area.label, area.color, Colors.white),
                        if (item.achieved)
                          _tag('Achieved', Brand.gold, Brand.deep)
                        else if (countdown.isNotEmpty)
                          _tag(countdown, Colors.white.withValues(alpha: 0.2), Colors.white),
                      ],
                    ),
                  ),
                if (item.caption.isNotEmpty)
                  Text(item.caption,
                      textAlign: TextAlign.center,
                      style: display(28, Colors.white)),
                if (item.affirmation.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(item.affirmation,
                      textAlign: TextAlign.center,
                      style: body(16, Colors.white.withValues(alpha: 0.92))
                          .copyWith(fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Text(text,
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}
