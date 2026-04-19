import 'package:flutter/material.dart';
import '../engine/dot_detector.dart';

/// Draws the translucent playhead strip, scan-lines, and luminance gauges.
class PlayheadPainter extends CustomPainter {
  final List<bool> activeZones;
  final List<double> luminanceLevels;
  final double spacing;
  final double offset;
  final double threshold;
  final double playheadYOffset;

  static const List<Color> zoneColors = [
    Color(0xFFFF5252), // zone 0 – red    (A4)
    Color(0xFFFF9800), // zone 1 – orange (G4)
    Color(0xFFFFEB3B), // zone 2 – yellow (E4)
    Color(0xFF4CAF50), // zone 3 – green  (D4)
    Color(0xFF29B6F6), // zone 4 – blue   (C4)
  ];

  static const List<String> noteNames = ['A', 'G', 'E', 'D', 'C'];

  const PlayheadPainter({
    required this.activeZones,
    required this.luminanceLevels,
    required this.spacing,
    required this.offset,
    required this.threshold,
    required this.playheadYOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height * playheadYOffset;

    // ── Horizontal Playhead line ───────────────────────────────────────────
    final stripRect = Rect.fromLTWH(0, cy - 40, size.width, 80);
    canvas.drawRect(
      stripRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..style = PaintingStyle.fill,
    );

    // The sharp scanning line representing the "Comb"
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.8)
        ..strokeWidth = 2.0,
    );

    final zoneCenters = DotDetector.computeZoneCenters(size.width, spacing, offset);
    
    for (int i = 0; i < 5; i++) {
      final x = zoneCenters[i];
      final color = zoneColors[i];
      final isActive = activeZones[i];
      final luminance = luminanceLevels[i];

      // Vertical intersecting scan line for each string (lane)
      canvas.drawLine(
        Offset(x, cy - 60),
        Offset(x, cy + 60),
        Paint()
          ..color = isActive
              ? color.withValues(alpha: 0.8)
              : color.withValues(alpha: 0.2)
          ..strokeWidth = isActive ? 2.0 : 1.0,
      );

      // Luminance Gauge (small horizontal bar)
      const gaugeW = 34.0;
      const gaugeH = 4.0;
      final gaugeRect = Rect.fromCenter(
        center: Offset(x, cy - 42),
        width: gaugeW,
        height: gaugeH,
      );

      // Gauge Background
      canvas.drawRect(gaugeRect, Paint()..color = Colors.white24);

      // Gauge Fill level (width based on luminance drops)
      final fillLevel = (1.0 - luminance).clamp(0.0, 1.0);
      final fillRect = Rect.fromLTWH(
        gaugeRect.left,
        gaugeRect.top,
        gaugeRect.width * fillLevel,
        gaugeH,
      );
      canvas.drawRect(fillRect, Paint()..color = color.withValues(alpha: 0.8));

      // Gauge Threshold line
      final thresholdX = gaugeRect.left + (gaugeRect.width * (1.0 - threshold));
      canvas.drawLine(
        Offset(thresholdX, gaugeRect.top - 2),
        Offset(thresholdX, gaugeRect.bottom + 2),
        Paint()..color = Colors.white..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PlayheadPainter oldDelegate) {
    return true;
  }
}
