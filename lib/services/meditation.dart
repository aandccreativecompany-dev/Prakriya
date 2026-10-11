import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:flutter/services.dart' show HapticFeedback;

import 'extras.dart';

class MeditationSound {
  final String key;
  final String label;

  /// Asset path relative to `assets/` (what AssetSource expects), or null.
  final String? asset;

  /// Group shown in the picker: Nature, Tones, Sleep & focus, or Custom.
  final String category;
  final IconData icon;
  const MeditationSound(this.key, this.label, this.asset, this.category, this.icon);
}

const List<MeditationSound> kMeditationSounds = [
  MeditationSound('none', 'Silence', null, 'Custom', Icons.volume_off_outlined),
  MeditationSound('rain', 'Rain', 'sound/med_rain.wav', 'Nature', Icons.grain),
  MeditationSound('storm', 'Thunderstorm', 'sound/med_storm.wav', 'Nature', Icons.thunderstorm_outlined),
  MeditationSound('ocean', 'Ocean', 'sound/med_ocean.wav', 'Nature', Icons.waves),
  MeditationSound('stream', 'Stream', 'sound/med_stream.wav', 'Nature', Icons.water),
  MeditationSound('forest', 'Forest night', 'sound/med_forest.wav', 'Nature', Icons.forest_outlined),
  MeditationSound('birds', 'Birdsong', 'sound/med_birds.wav', 'Nature', Icons.flutter_dash),
  MeditationSound('wind', 'Soft wind', 'sound/med_wind.wav', 'Nature', Icons.air),
  MeditationSound('fire', 'Fireplace', 'sound/med_fire.wav', 'Nature', Icons.local_fire_department_outlined),
  MeditationSound('drops', 'Water drops', 'sound/med_drops.wav', 'Nature', Icons.water_drop_outlined),
  MeditationSound('bowl', 'Singing bowl', 'sound/med_bowl.wav', 'Tones', Icons.circle_outlined),
  MeditationSound('temple', 'Temple bells', 'sound/med_temple.wav', 'Tones', Icons.notifications_none),
  MeditationSound('chimes', 'Wind chimes', 'sound/med_chimes.wav', 'Tones', Icons.music_note_outlined),
  MeditationSound('om', 'Om drone', 'sound/med_om.wav', 'Tones', Icons.self_improvement),
  MeditationSound('pad', 'Calm pad', 'sound/med_pad.wav', 'Tones', Icons.piano_outlined),
  MeditationSound('sleep', 'Deep sleep', 'sound/med_sleep.wav', 'Sleep & focus', Icons.bedtime_outlined),
  MeditationSound('theta', 'Theta waves', 'sound/med_theta.wav', 'Sleep & focus', Icons.headphones_outlined),
  MeditationSound('brown', 'Brown noise', 'sound/med_brown.wav', 'Sleep & focus', Icons.graphic_eq),
  MeditationSound('link', 'My own link', null, 'Custom', Icons.link),
];

const List<String> kMeditationCategories = [
  'Nature',
  'Tones',
  'Sleep & focus',
  'Custom',
];

/// A guided breathing rhythm. Phases run in order and loop; the orb grows on
/// "in", stays on "hold" and shrinks on "out".
class BreathPhase {
  final String label;
  final int seconds;
  final bool grow;
  final bool shrink;
  const BreathPhase(this.label, this.seconds, {this.grow = false, this.shrink = false});
}

class BreathPattern {
  final String key;
  final String name;
  final String blurb;
  final List<BreathPhase> phases;
  const BreathPattern(this.key, this.name, this.blurb, this.phases);
  int get cycleSeconds => phases.fold<int>(0, (sum, p) => sum + p.seconds);
}

const List<BreathPattern> kBreathPatterns = [
  BreathPattern('calm', 'Calm 4 · 6', 'Longer out-breath to settle the body', [
    BreathPhase('Breathe in', 4, grow: true),
    BreathPhase('Breathe out', 6, shrink: true),
  ]),
  BreathPattern('even', 'Even 5 · 5', 'Simple and steady', [
    BreathPhase('Breathe in', 5, grow: true),
    BreathPhase('Breathe out', 5, shrink: true),
  ]),
  BreathPattern('box', 'Box 4 · 4 · 4 · 4', 'Focus and composure', [
    BreathPhase('Breathe in', 4, grow: true),
    BreathPhase('Hold', 4),
    BreathPhase('Breathe out', 4, shrink: true),
    BreathPhase('Hold', 4),
  ]),
  BreathPattern('478', 'Sleep 4 · 7 · 8', 'Wind down before bed', [
    BreathPhase('Breathe in', 4, grow: true),
    BreathPhase('Hold', 7),
    BreathPhase('Breathe out', 8, shrink: true),
  ]),
];

BreathPattern breathPatternFor(String key) {
  for (final p in kBreathPatterns) {
    if (p.key == key) return p;
  }
  return kBreathPatterns.first;
}

/// One meditation session plus its background sound, kept outside any screen
/// so a running session survives switching tabs.
class MeditationSession extends ChangeNotifier {
  static const List<int> lengths = [5, 10, 15, 20, 30, 45, 60];

  int minutes = 10;
  int remaining = 10 * 60;
  bool running = false;
  bool paused = false;
  bool musicPlaying = false;
  String? message;

  DateTime? _endsAt;
  int _lastChimeBlock = 0;
  bool _fading = false;
  Timer? _timer;
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _bell = AudioPlayer();

  bool get active => running || paused;

  String get clock {
    final m = (remaining ~/ 60).toString().padLeft(2, '0');
    final s = (remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get progress {
    final total = minutes * 60;
    if (total <= 0) return 0;
    return (1 - remaining / total).clamp(0.0, 1.0).toDouble();
  }

  void pickLength(int value) {
    if (active) return;
    minutes = value;
    remaining = value * 60;
    notifyListeners();
  }

  Future<void> start() async {
    if (running) return;
    HapticFeedback.mediumImpact();
    message = null;
    _endsAt = DateTime.now().add(Duration(seconds: remaining));
    running = true;
    paused = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _fading = false;
    _lastChimeBlock = _elapsedBlock();
    notifyListeners();
    if (extras.meditationStartBell && remaining == minutes * 60) {
      unawaited(_ring(0.7));
    }
    if (!musicPlaying && extras.meditationSound != 'none') {
      await playMusic();
    }
  }

  /// Which interval-chime block we are in (0 when chimes are off).
  int _elapsedBlock() {
    final every = extras.meditationInterval;
    if (every <= 0) return 0;
    final elapsed = minutes * 60 - remaining;
    return elapsed ~/ (every * 60);
  }

  Future<void> _ring(double volume) async {
    try {
      await _bell.stop();
      await _bell.play(AssetSource('sound/bell.wav'), volume: volume);
    } catch (e) {
      debugPrint('Meditation bell failed: $e');
    }
  }

  void pause() {
    if (!running) return;
    _timer?.cancel();
    _timer = null;
    final end = _endsAt;
    if (end != null) {
      remaining = end.difference(DateTime.now()).inSeconds.clamp(1, minutes * 60).toInt();
    }
    _endsAt = null;
    running = false;
    paused = true;
    notifyListeners();
  }

  Future<void> reset() async {
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    running = false;
    paused = false;
    remaining = minutes * 60;
    notifyListeners();
    await stopMusic();
  }

  void _tick() {
    final end = _endsAt;
    if (end == null) return;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    if (ms <= 0) {
      unawaited(_finish());
    } else {
      remaining = (ms / 1000).ceil();
      // Interval chime: a soft bell every N minutes.
      final block = _elapsedBlock();
      if (block > _lastChimeBlock && remaining > 3) {
        _lastChimeBlock = block;
        unawaited(_ring(0.5));
      } else if (block > _lastChimeBlock) {
        _lastChimeBlock = block;
      }
      // Gentle fade-out of the background sound over the last 8 seconds.
      if (musicPlaying && remaining <= 8 && extras.meditationSound != 'none') {
        _fading = true;
        unawaited(_setPlayerVolume(extras.meditationVolume * (remaining / 8.0)));
      }
      notifyListeners();
    }
  }

  Future<void> _setPlayerVolume(double value) async {
    try {
      await _music.setVolume(value.clamp(0.0, 1.0).toDouble());
    } catch (_) {}
  }

  Future<void> _finish() async {
    _timer?.cancel();
    _timer = null;
    _endsAt = null;
    running = false;
    paused = false;
    final done = minutes;
    remaining = minutes * 60;
    extras.addMeditationMinutes(done);
    message = 'Session complete: $done minutes. Well done.';
    notifyListeners();
    HapticFeedback.heavyImpact();
    await stopMusic();
    await _ring(1.0);
  }

  Future<void> playMusic() async {
    final key = extras.meditationSound;
    try {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
      _fading = false;
      final volume = extras.meditationVolume;
      if (key == 'link') {
        final url = extras.musicUrl.trim();
        if (!(url.startsWith('http://') || url.startsWith('https://'))) {
          message = 'Paste a full link that starts with https:// first.';
          musicPlaying = false;
          notifyListeners();
          return;
        }
        await _music.play(UrlSource(url), volume: volume);
      } else {
        MeditationSound? sound;
        for (final s in kMeditationSounds) {
          if (s.key == key) sound = s;
        }
        final asset = sound?.asset;
        if (asset == null) {
          musicPlaying = false;
          notifyListeners();
          return;
        }
        await _music.play(AssetSource(asset), volume: volume);
      }
      musicPlaying = true;
      message = null;
    } catch (e) {
      debugPrint('Meditation music failed: $e');
      musicPlaying = false;
      message = 'Could not play that sound. Check the link and your connection.';
    }
    notifyListeners();
  }

  Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (e) {
      debugPrint('Meditation stop failed: $e');
    }
    musicPlaying = false;
    notifyListeners();
  }

  Future<void> toggleMusic() async {
    if (musicPlaying) {
      await stopMusic();
    } else {
      await playMusic();
    }
  }

  /// Picks a sound. If the sound is already playing, or a session is running,
  /// it switches immediately; otherwise it auditions the sound so you can hear
  /// what you picked.
  Future<void> chooseSound(String key) async {
    extras.setMeditationPrefs(sound: key);
    if (key == 'none') {
      await stopMusic();
    } else if (key == 'link') {
      if (extras.musicUrl.trim().isNotEmpty) {
        await playMusic();
      } else if (musicPlaying) {
        await stopMusic();
      }
    } else {
      await playMusic();
    }
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    extras.setMeditationPrefs(volume: value);
    if (!_fading) await _setPlayerVolume(value);
  }
}

final MeditationSession meditation = MeditationSession();
