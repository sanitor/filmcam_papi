import 'dart:math';
import 'dart:ui';

class FrameLine {
  final double x1, y1, x2, y2;

  const FrameLine(this.x1, this.y1, this.x2, this.y2);
}

class ViewfinderEngine {
  double sensorWidth;
  double sensorHeight;

  ViewfinderEngine({this.sensorWidth = 36.0, this.sensorHeight = 24.0});

  void setFormat(double width, double height) {
    sensorWidth = width;
    sensorHeight = height;
  }

  List<FrameLine> computeFrameLines({
    required double focalLengthMm,
    required double viewportWidth,
    required double viewportHeight,
    double? previewCropFactor,
  }) {
    final lines = <FrameLine>[];
    final fl = focalLengthMm <= 0 ? 50.0 : focalLengthMm;

    final diag = sqrt(sensorWidth * sensorWidth + sensorHeight * sensorHeight);
    final cropFactor = 43.27 / diag;
    final effectiveFl = fl * cropFactor;

    final frameW = viewportWidth * (effectiveFl / 50.0);
    final frameH = viewportHeight * (effectiveFl / 50.0);

    if (frameW <= 0 || frameH <= 0) return lines;

    final padX = (viewportWidth - frameW) / 2;
    final padY = (viewportHeight - frameH) / 2;

    final x1 = padX;
    final y1 = padY;
    final x2 = padX + frameW;
    final y2 = padY + frameH;

    lines.add(FrameLine(x1, y1, x2, y1));
    lines.add(FrameLine(x2, y1, x2, y2));
    lines.add(FrameLine(x2, y2, x1, y2));
    lines.add(FrameLine(x1, y2, x1, y1));

    return lines;
  }

  List<FrameLine> computeGridLines(
    double w,
    double h, {
    int cols = 3,
    int rows = 3,
  }) {
    final lines = <FrameLine>[];
    for (var i = 1; i < cols; i++) {
      final x = w * i / cols;
      lines.add(FrameLine(x, 0, x, h));
    }
    for (var i = 1; i < rows; i++) {
      final y = h * i / rows;
      lines.add(FrameLine(0, y, w, y));
    }
    return lines;
  }

  Offset parallaxOffset({
    required double distanceMeters,
    required double baselineMm,
    required double focalLengthMm,
    required double sensorWidthMm,
  }) {
    if (distanceMeters <= 0) return Offset.zero;
    final baselineM = baselineMm / 1000.0;
    final flM = focalLengthMm / 1000.0;
    final shift = baselineM * flM / distanceMeters;
    final pxPerMm = sensorWidth / sensorWidthMm;
    return Offset(shift * pxPerMm, 0);
  }

  double depthOfFieldNear(double distance, double flMm, double aperture) {
    if (distance <= 0) return 0;
    final coc = _circleOfConfusion();
    final h = _hyperfocal(flMm, aperture, coc);
    if (h <= 0) return distance;
    return (h * distance) / (h + distance);
  }

  double depthOfFieldFar(double distance, double flMm, double aperture) {
    if (distance <= 0) return double.infinity;
    final coc = _circleOfConfusion();
    final h = _hyperfocal(flMm, aperture, coc);
    if (h <= 0 || distance >= h) return double.infinity;
    return (h * distance) / (h - distance);
  }

  double hyperfocalDistance(double flMm, double aperture) {
    final coc = _circleOfConfusion();
    return _hyperfocal(flMm, aperture, coc);
  }

  double _circleOfConfusion() {
    final diag = sqrt(sensorWidth * sensorWidth + sensorHeight * sensorHeight);
    return diag / 1500.0;
  }

  double _hyperfocal(double flMm, double aperture, double cocMm) {
    final flM = flMm / 1000.0;
    return flM * flM / (aperture * cocMm);
  }
}
