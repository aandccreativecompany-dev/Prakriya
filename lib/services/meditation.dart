import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import 'extras.dart';

class MeditationSound {
  final String key;
  final String label;

  /// Asset path relative to `assets/` (what AssetSource expects), or null.
  final String? asset;
  const MeditationSound(this.key, this.label, this.asset);
}

const List<MeditationSound> kMeditationSounds = [
  MeditationSound('none', 'Silence', null),
  MeditationSound('rain', 'Rain', 'sound/med_rain.wav'),
  MeditationSound('ocean', 'Ocean', 'sound/med_ocean.wav'),
  MeditationSound('wind', 'Soft wind', 'sound/med_wind.wav'),
  MeditationSound('bowl', 'Singing bowl', 'sound/med_bowl.wav'),
  MeditationSound('pad', 'Calm pad', 'sound/med_pad.wav'),
  MeditationSound('om', 'Om drone', 'sound/med_om.wav'),
  MeditationSound('link', 'My own link', null),
];

/// One meditation session plus its background sound, kept outside any screen
/// so a running session survives switching tabs.
class MeditationSession extends ChangeNotifier {
  static const List<int> lengths = [5, 10, 15, 20, 30];

  int minutes = 10;
  int remaining = 10 * 60;
  bool running = false;
  bool paused = false;
  bool musicPlaying = false;
  String? message;

  DateTime? _endsAt;
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
    notifyListeners();
    if (!musicPlaying && extras.meditationSound != 'none') {
      await playMusic();
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
      notifyListeners();
    }
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
    try {
      await _bell.stop();
      await _bell.play(AssetSource('sound/bell.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('Meditation bell failed: $e');
    }
  }

  Future<void> playMusic() async {
    final key = extras.meditationSound;
    try {
      await _music.stop();
      await _music.setReleaseMode(ReleaseMode.loop);
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

  Future<void> chooseSound(String key) async {
    extras.setMeditationPrefs(sound: key);
    if (musicPlaying) {
      if (key == 'none') {
        await stopMusic();
      } else {
        await playMusic();
      }
    }
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    extras.setMeditationPrefs(volume: value);
    try {
      await _music.setVolume(value);
    } catch (_) {}
  }
}

final MeditationSession meditation = MeditationSession();
