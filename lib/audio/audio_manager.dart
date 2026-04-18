import 'package:audioplayers/audioplayers.dart';

/// Wraps audioplayers: pre-loads 5 pentatonic notes and provides playNote(i).
/// Uses one [AudioPlayer] per zone so notes can overlap without cutting each other off.
class AudioManager {
  // One player per zone for polyphony
  late final List<AudioPlayer> _players;
  bool _ready = false;

  // Asset paths in descending pitch order (zone 0 = top = highest note)
  static const List<String> _assets = [
    'sounds/note_a4.wav', // zone 0 — top string (A4 highest)
    'sounds/note_g4.wav', // zone 1
    'sounds/note_e4.wav', // zone 2 — middle
    'sounds/note_d4.wav', // zone 3
    'sounds/note_c4.wav', // zone 4 — bottom string (C4 lowest)
  ];

  Future<void> init() async {
    _players = List.generate(5, (_) => AudioPlayer());

    // Set low-latency release mode for all players
    for (int i = 0; i < 5; i++) {
      await _players[i].setReleaseMode(ReleaseMode.stop);
      await _players[i].setVolume(1.0);
    }

    _ready = true;
  }

  void playNote(int zoneIndex) {
    if (!_ready) return;
    if (zoneIndex < 0 || zoneIndex >= 5) return;
    // Fire and forget — don't await to avoid blocking the camera stream
    _players[zoneIndex].play(AssetSource(_assets[zoneIndex]));
  }

  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
  }
}
