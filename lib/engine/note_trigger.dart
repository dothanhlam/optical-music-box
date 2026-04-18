import '../audio/audio_manager.dart';

/// State-toggle trigger: fires audio on the rising edge (false to true) and
/// blocks re-triggering until the zone goes clear again (true to false).
class NoteTrigger {
  final AudioManager audioManager;

  // Previous activation state per zone
  final List<bool> _wasActive = List.filled(5, false);

  NoteTrigger({required this.audioManager});

  /// Call every frame with the 5 detection flags.
  /// Returns a List of bool where true means "note was fired THIS frame."
  List<bool> process(List<bool> detected) {
    final fired = List.filled(5, false);

    for (int i = 0; i < 5; i++) {
      final isActive = detected[i];

      if (isActive && !_wasActive[i]) {
        // Rising edge → play note
        audioManager.playNote(i);
        fired[i] = true;
      }
      // Always update previous state
      _wasActive[i] = isActive;
    }

    return fired;
  }
}
