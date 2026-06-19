import '../models/distance.dart';

class RangeEngine {
  double _offset = 0.0;

  void setCalibrationOffset(double offset) {
    _offset = offset;
  }

  DistanceReading fromFocusDistance(double diopters) {
    if (diopters <= 0) return DistanceReading.none;
    final meters = (1.0 / diopters) + _offset;
    return DistanceReading(
      meters: meters,
      confidence: diopters > 0.1 ? 0.7 : 0.3,
      source: DistanceSource.focusLens,
    );
  }

  DistanceReading fromArDepth(double meters) {
    return DistanceReading(
      meters: meters + _offset,
      confidence: 0.9,
      source: DistanceSource.arDepth,
    );
  }

  @Deprecated('Use fromArDepth')
  DistanceReading fromLidarDepth(double meters) => fromArDepth(meters);

  DistanceReading fromExifDistance(double meters) {
    return DistanceReading(
      meters: meters + _offset,
      confidence: 0.6,
      source: DistanceSource.manual,
    );
  }

  DistanceReading fromManual(double meters) {
    return DistanceReading(
      meters: meters,
      confidence: 0.5,
      source: DistanceSource.manual,
    );
  }

  static double depthOfFieldNear(
    double distance,
    double focalLengthMm,
    double aperture,
    double cocMm,
  ) {
    final h = hyperfocal(focalLengthMm, aperture, cocMm);
    if (h <= 0) return distance;
    return (h * distance) / (h + distance);
  }

  static double depthOfFieldFar(
    double distance,
    double focalLengthMm,
    double aperture,
    double cocMm,
  ) {
    final h = hyperfocal(focalLengthMm, aperture, cocMm);
    if (h <= 0) return double.infinity;
    if (distance >= h) return double.infinity;
    return (h * distance) / (h - distance);
  }

  static double hyperfocal(
    double focalLengthMm,
    double aperture,
    double cocMm,
  ) {
    return (focalLengthMm / 1000.0) *
        (focalLengthMm / 1000.0) /
        (aperture * cocMm);
  }
}
