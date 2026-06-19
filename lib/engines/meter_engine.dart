import 'dart:math';
import 'package:camera/camera.dart';
import '../models/exposure.dart';

class MeterEngine {
  double _evOffset = 0.0;
  double _fallbackAperture = 1.8;

  void setCalibrationOffset(double offset) {
    _evOffset = offset;
  }

  void setFallbackAperture(double aperture) {
    if (aperture > 0) _fallbackAperture = aperture;
  }

  ExposureReading? processFrame(
    CameraImage image, {
    double? nativeAperture,
    int? nativeExposureTime,
    double? nativeIso,
  }) {
    final aperture = image.lensAperture ?? nativeAperture;
    final exposureTime = image.sensorExposureTime ?? nativeExposureTime;
    final sensitivity = image.sensorSensitivity ?? nativeIso;

    if (aperture == null || exposureTime == null || sensitivity == null) {
      return _estimateFromLuma(image);
    }

    final shutterSeconds = exposureTime / 1e9;
    if (shutterSeconds <= 0) return null;

    final rawEv = evFromParams(aperture, shutterSeconds, sensitivity);
    final ev = rawEv + _evOffset;

    return ExposureReading(
      ev: ev,
      aperture: aperture,
      shutterSpeed: shutterSeconds,
      iso: sensitivity,
    );
  }

  ExposureReading? _estimateFromLuma(CameraImage image) {
    try {
      final luma = _extractLuma(image);
      if (luma == null) return null;

      var avgLuma = 0.0;
      for (final v in luma) {
        avgLuma += v;
      }
      avgLuma /= luma.length;

      if (avgLuma <= 0) return null;

      final ev = _lumaToEv(avgLuma) + _evOffset;
      final safeEv = ev.clamp(-6.0, 18.0);

      return ExposureReading(
        ev: safeEv,
        aperture: _fallbackAperture,
        shutterSpeed: 1.0 / 60,
        iso: 400,
      );
    } catch (_) {
      return null;
    }
  }

  double _lumaToEv(double luma) {
    const refLuma = 128.0;
    final ratio = luma / refLuma;
    return log(ratio) / ln2 * 2.0 + 10.0;
  }

  ExposureReading? processFrameWithLuma(
    CameraImage image, {
    double spotX = 0.5,
    double spotY = 0.5,
    double spotSize = 0.1,
    MeterPattern pattern = MeterPattern.average,
    double? nativeAperture,
    int? nativeExposureTime,
    double? nativeIso,
  }) {
    final base = processFrame(
      image,
      nativeAperture: nativeAperture,
      nativeExposureTime: nativeExposureTime,
      nativeIso: nativeIso,
    );
    if (base == null) return null;

    final luma = _extractLuma(image);
    if (luma == null) return base;

    final lumaFactor = _computeLumaFactor(
      luma,
      image,
      spotX,
      spotY,
      spotSize,
      pattern,
    );
    final adjustedEv = base.ev + log(lumaFactor) / ln2;
    return ExposureReading(
      ev: adjustedEv,
      aperture: base.aperture,
      shutterSpeed: base.shutterSpeed,
      iso: base.iso,
    );
  }

  List<double>? _extractLuma(CameraImage image) {
    try {
      if (image.planes.length >= 2) return _extractYuvLuma(image);
      return _extractBgraLuma(image);
    } catch (_) {
      return null;
    }
  }

  List<double> _extractYuvLuma(CameraImage image, {int step = 4}) {
    final yPlane = image.planes[0];
    final bytes = yPlane.bytes;
    final bytesPerRow = yPlane.bytesPerRow;
    final w = image.width;
    final h = image.height;

    final cols = (w + step - 1) ~/ step;
    final rows = (h + step - 1) ~/ step;
    final result = List<double>.generate(rows * cols, (i) {
      final row = (i ~/ cols) * step;
      final col = (i % cols) * step;
      return bytes[row * bytesPerRow + col].toDouble();
    }, growable: false);
    return result;
  }

  List<double> _extractBgraLuma(CameraImage image) {
    final plane = image.planes[0];
    final bytes = plane.bytes;
    final result = List<double>.generate(image.height * image.width, (i) {
      final offset = i * 4;
      final b = bytes[offset].toDouble();
      final g = bytes[offset + 1].toDouble();
      final r = bytes[offset + 2].toDouble();
      return 0.299 * r + 0.587 * g + 0.114 * b;
    }, growable: false);
    return result;
  }

  double _computeLumaFactor(
    List<double> luma,
    CameraImage image,
    double spotX,
    double spotY,
    double spotSize,
    MeterPattern pattern, {
    int step = 4,
  }) {
    // Downsampled dimensions
    final dw = (image.width + step - 1) ~/ step;
    final dh = (image.height + step - 1) ~/ step;
    final cx = (spotX * image.width).round() ~/ step;
    final cy = (spotY * image.height).round() ~/ step;
    final half = ((spotSize * image.width).round() ~/ step).clamp(1, dw);

    double avgLuma;
    if (pattern == MeterPattern.spot) {
      avgLuma = _spotAverage(luma, dw, cx, cy, half);
    } else if (pattern == MeterPattern.centerWeighted) {
      avgLuma = _centerWeightedAverage(luma, dw, dh, step: 1);
    } else {
      avgLuma = _fullAverage(luma);
    }

    const referenceLuma = 128.0;
    if (avgLuma <= 0) return 1.0;
    return avgLuma / referenceLuma;
  }

  double _fullAverage(List<double> luma) {
    var sum = 0.0;
    for (final v in luma) {
      sum += v;
    }
    return sum / luma.length;
  }

  double _centerWeightedAverage(
    List<double> luma,
    int w,
    int h, {
    int step = 4,
  }) {
    final cx = w ~/ 2;
    final cy = h ~/ 2;
    var weightedSum = 0.0;
    var weightTotal = 0.0;
    final sigma = w < h ? w / 3.0 : h / 3.0;

    for (var y = 0; y < h; y += step) {
      for (var x = 0; x < w; x += step) {
        final dist = sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
        final weight = exp(-dist * dist / (2 * sigma * sigma));
        weightedSum += luma[y * w + x] * weight;
        weightTotal += weight;
      }
    }
    return weightedSum / weightTotal;
  }

  double _spotAverage(List<double> luma, int w, int cx, int cy, int half) {
    var sum = 0.0;
    var count = 0;
    final yStart = (cy - half).clamp(0, luma.length ~/ w - 1);
    final yEnd = (cy + half).clamp(0, luma.length ~/ w - 1);
    final xStart = (cx - half).clamp(0, w - 1);
    final xEnd = (cx + half).clamp(0, w - 1);

    for (var y = yStart; y <= yEnd; y++) {
      for (var x = xStart; x <= xEnd; x++) {
        sum += luma[y * w + x];
        count++;
      }
    }
    return count > 0 ? sum / count : 0;
  }
}

enum MeterPattern { average, centerWeighted, spot }
