import 'dart:math';
import 'package:camera/camera.dart';
import '../models/color_temp.dart';

class ColorTempEngine {
  double _offset = 0.0;

  void setCalibrationOffset(double offset) {
    _offset = offset;
  }

  ColorTempReading processFrame(CameraImage image) {
    try {
      double rAvg, gAvg, bAvg;

      if (image.planes.length >= 2) {
        final rgb = _yuvToRgb(image);
        rAvg = rgb.$1;
        gAvg = rgb.$2;
        bAvg = rgb.$3;
      } else {
        final rgb = _bgraToRgb(image);
        rAvg = rgb.$1;
        gAvg = rgb.$2;
        bAvg = rgb.$3;
      }

      final sum = rAvg + gAvg + bAvg;
      if (sum <= 0) return ColorTempReading.none;

      final r = rAvg / sum;
      final g = gAvg / sum;
      final b = bAvg / sum;

      final x = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
      final y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
      final z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;

      final xyzSum = x + y + z;
      if (xyzSum <= 0) return ColorTempReading.none;

      final cx = x / xyzSum;
      final cy = y / xyzSum;

      final n = (cx - 0.3320) / (0.1858 - cy);
      final cct = 449.0 * n * n * n + 3525.0 * n * n + 6823.3 * n + 5520.33;
      final duv = _computeDuv(cx, cy);

      return ColorTempReading(cct: cct + _offset, duv: duv, confidence: 0.5);
    } catch (_) {
      return ColorTempReading.none;
    }
  }

  (double, double, double) _yuvToRgb(CameraImage image) {
    final yPlane = image.planes[0];
    final uvPlane = image.planes[1];
    final w = image.width;
    final h = image.height;

    var rSum = 0.0, gSum = 0.0, bSum = 0.0;
    var count = 0;
    final step = 4;

    for (var y = 0; y < h; y += step) {
      for (var x = 0; x < w; x += step) {
        final yi = y * yPlane.bytesPerRow + x;
        final yVal = yPlane.bytes[yi].toDouble();

        final uvIndex = (y ~/ 2) * uvPlane.bytesPerRow + (x ~/ 2) * 2;
        final u = uvPlane.bytes[uvIndex].toDouble() - 128.0;
        final v = uvPlane.bytes[uvIndex + 1].toDouble() - 128.0;

        final r = (yVal + 1.402 * v).clamp(0, 255);
        final g = (yVal - 0.344 * u - 0.714 * v).clamp(0, 255);
        final b = (yVal + 1.772 * u).clamp(0, 255);

        rSum += r;
        gSum += g;
        bSum += b;
        count++;
      }
    }

    if (count == 0) return (0, 0, 0);
    return (rSum / count, gSum / count, bSum / count);
  }

  (double, double, double) _bgraToRgb(CameraImage image) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final total = image.width * image.height;

    var rSum = 0.0, gSum = 0.0, bSum = 0.0;
    var count = 0;
    final step = 16;

    for (var i = 0; i < total; i += step) {
      final offset = i * 4;
      if (offset + 3 >= bytes.length) break;
      rSum += bytes[offset + 2].toDouble();
      gSum += bytes[offset + 1].toDouble();
      bSum += bytes[offset].toDouble();
      count++;
    }

    if (count == 0) return (0, 0, 0);
    return (rSum / count, gSum / count, bSum / count);
  }

  double _computeDuv(double x, double y) {
    final lfpX = 0.31271;
    final lfpY = 0.32902;
    return sqrt((x - lfpX) * (x - lfpX) + (y - lfpY) * (y - lfpY));
  }
}
