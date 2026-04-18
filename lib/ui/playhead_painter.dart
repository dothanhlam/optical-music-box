import 'package:flutter/material.dart';
import '../engine/dot_detector.dart';

/// Draws the translucent playhead strip and a thin scan-line per zone.
class PlayheadPainter extends CustomPainter {
  final List<bool> activeZones;

  static const List<Color> zoneColors = [
    Color(0xFFFF5252), // zone 0 – red    (A4)
    Color(0xFFFF9800), // zone 1 – orange (G4)
    Color(0xFFFFEB3B), // zone 2 – yellow (E4)
    Color(0xFF4CAF50), // zone 3 – green  (D4)
    Color(0xFF29B6F6), // zone 4 – blue   (C4)
  ];

  static const List<String> noteNames = ['A', 'G', 'E', 'D', 'C'];

  const PlayheadPainter({required this.activeZones});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const stripW = 70.0;

    // ── Semi-transparent playhead rectangle ──────────────────────────────
    final stripRect = Rect.fromLTWH(cx - stripW / 2, 0, stripW, size.height);

    canvas.drawRect(
      stripRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.fill,
    );

    // ── Border lines ──────────────────────────────────────────────────────
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(stripRect, borderPaint);

    // ── Scan line per zone ────────────────────────────────────────────────
    final zoneCenters = DotDetector.computeZoneCenters(size.height);
    for (int i = 0; i < 5; i++) {
      final y = zoneCenters[i];
      final color = zoneColors[i];
      final isActive = activeZones[i];
      canvas.drawLine(
        Offset(cx - stripW / 2, y),
        Offset(cx + stripW / 2, y),
        Paint()
          ..color = isActive
              ? color.withValues(alpha: 0.9)
              : color.withValues(alpha: 0.25)
          ..strokeWidth = isActive ? 2.5 : 1.0,
      );
    }

    // ── Top & bottom edge accent ──────────────────────────────────────────
    const accentH = 24.0;
    final topRect = Rect.fromLTWH(cx - stripW / 2, 0, stripW, accentH);
    final botRect = Rect.fromLTWH(
        cx - stripW / 2, size.height - accentH, stripW, accentH);

    for (final rect in [topRect, botRect]) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(PlayheadPainter old) {
    for (int i = 0; i < 5; i++) {
      if (old.activeZones[i] != activeZones[i]) return true;
    }
    return false;
  }
}
