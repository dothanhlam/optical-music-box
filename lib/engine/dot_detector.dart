import 'dart:math' as math;
import 'package:camera/camera.dart';

class DetectionResult {
  final List<bool> detected;
  final List<double> luminance; // 0.0 (dark) to 1.0 (light)
  DetectionResult(this.detected, this.luminance);
}

/// Samples the YUV420 Y-plane (luminance) for 5 vertical zones.
/// Supports dynamic spacing and positioning to align with physical strips.
class DotDetector {
  static const int _sampleRegionPx = 24; 

  /// Returns the center pixel for each of the 5 zones along an axis of [length].
  /// [spacing] 0.1 to 1.0 (how much of the axis to occupy)
  /// [offset] -1.0 to 1.0 (shift from center)
  static List<double> computeZoneCenters(double length, double spacing, double offset) {
    final totalContentLength = length * spacing;
    final centerRelative = (length / 2) + ((length / 2) * offset);
    final startVal = centerRelative - (totalContentLength / 2);
    final step = totalContentLength / 5;
    
    return List.generate(5, (i) {
      return (startVal + step * i + step / 2).clamp(0.0, length);
    });
  }

  DetectionResult detect(
    CameraImage image, {
    required double spacing,
    required double offset,
    required double threshold,
    required int sensorOrientation,
    required double playheadFraction,
  }) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final yBytes = yPlane.bytes;
    final rowStride = yPlane.bytesPerRow;

    final detected = <bool>[];
    final luminanceLevels = <double>[];

    // Mobile sensors are typically landscape (width > height).
    // Portrait UI X-axis corresponds to the sensor's short dimension.
    // Portrait UI Y-axis corresponds to the sensor's long dimension.
    bool appliesRotation = width > height;
    final longAxis = appliesRotation ? width : height;
    final shortAxis = appliesRotation ? height : width;

    // Centers span across the UI X-axis (short axis of the sensor)
    final centers = computeZoneCenters(shortAxis.toDouble(), spacing, offset);
    
    // Playhead is anchored along the UI Y-axis (long axis of the sensor)
    final longAxisCenter = (longAxis * playheadFraction).round();

    final half = _sampleRegionPx ~/ 2;

    for (int zone = 0; zone < 5; zone++) {
      // Rotate 90 CW: X-axis on UI maps to inverted row in sensor.
      int checkZone = zone;
      if (appliesRotation && sensorOrientation == 90) {
        checkZone = 4 - zone;
      }

      final shortAxisZoneCenter = centers[checkZone].round();

      final longStart = math.max(0, longAxisCenter - half);
      final longEnd = math.min(longAxis - 1, longAxisCenter + half);
      final shortStart = math.max(0, shortAxisZoneCenter - half);
      final shortEnd = math.min(shortAxis - 1, shortAxisZoneCenter + half);

      final int yStart, yEnd, xStart, xEnd;
      if (appliesRotation) {
        xStart = longStart; // col
        xEnd = longEnd;
        yStart = shortStart; // row
        yEnd = shortEnd;
      } else {
        yStart = longStart;
        yEnd = longEnd;
        xStart = shortStart;
        xEnd = shortEnd;
      }

      int sum = 0;
      int count = 0;

      for (int row = yStart; row <= yEnd; row++) {
        for (int col = xStart; col <= xEnd; col++) {
          final idx = row * rowStride + col;
          if (idx < yBytes.length) {
            sum += yBytes[idx] & 0xFF;
            count++;
          }
        }
      }

      final avgLuminanceValue = count > 0 ? sum / count : 255.0;
      final normalizedLuminance = avgLuminanceValue / 255.0;
      
      luminanceLevels.add(normalizedLuminance);
      detected.add(normalizedLuminance < threshold);
    }

    return DetectionResult(detected, luminanceLevels);
  }
}
