import 'dart:math' as math;
import 'package:camera/camera.dart';

/// Samples the YUV420 Y-plane (luminance) for 5 equally-spaced vertical
/// zones centred on the playhead strip. Returns a List[bool] where
/// true == "dark dot detected in that zone."
class DotDetector {
  // ── Tuning ────────────────────────────────────────────────────────────────
  static const int _luminanceThreshold = 85; // 0-255; below = black dot
  static const int _sampleRegionPx = 24; // square region side (px)
  static const double _playheadFraction = 0.5; // 0-1 horizontal position

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the Y-centre pixel for each of the 5 zones given the screen/
  /// image height.  Used by the UI to position circles at the same spots.
  static List<double> computeZoneCenters(double height) {
    final band = height / 5;
    return List.generate(5, (i) => band * i + band / 2);
  }

  /// Analyse one [CameraImage] and return 5 bool flags.
  List<bool> detect(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final rowStride = yPlane.bytesPerRow;

    // Horizontal centre of the playhead in image coordinates
    final centreX = (width * _playheadFraction).round();
    final half = _sampleRegionPx ~/ 2;

    final results = <bool>[];

    for (int zone = 0; zone < 5; zone++) {
      // Vertical centre of this zone in image coordinates
      final centreY = ((height / 5) * zone + (height / 5) / 2).round();

      int sum = 0;
      int count = 0;

      final yStart = math.max(0, centreY - half);
      final yEnd = math.min(height - 1, centreY + half);
      final xStart = math.max(0, centreX - half);
      final xEnd = math.min(width - 1, centreX + half);

      for (int row = yStart; row <= yEnd; row++) {
        for (int col = xStart; col <= xEnd; col++) {
          final idx = row * rowStride + col;
          if (idx < yBytes.length) {
            sum += yBytes[idx] & 0xFF;
            count++;
          }
        }
      }

      final avgLuminance = count > 0 ? sum ~/ count : 255;
      results.add(avgLuminance < _luminanceThreshold);
    }

    return results;
  }
}
