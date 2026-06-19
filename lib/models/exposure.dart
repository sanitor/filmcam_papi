import 'dart:math';

const kMeterCalibrationConstant = 12.5;

class ExposureReading {
  final double ev;
  final double aperture;
  final double shutterSpeed;
  final double iso;

  const ExposureReading({
    required this.ev,
    required this.aperture,
    required this.shutterSpeed,
    required this.iso,
  });

  ExposureReading withAperture(double newAperture) {
    final newShutter = shutterFromEv(ev, newAperture, iso);
    return ExposureReading(
      ev: ev,
      aperture: newAperture,
      shutterSpeed: newShutter,
      iso: iso,
    );
  }

  ExposureReading withShutter(double newShutter) {
    final newAperture = apertureFromEv(ev, newShutter, iso);
    return ExposureReading(
      ev: ev,
      aperture: newAperture,
      shutterSpeed: newShutter,
      iso: iso,
    );
  }

  ExposureReading withIso(double newIso) {
    return ExposureReading(
      ev: ev,
      aperture: aperture,
      shutterSpeed: shutterFromEv(ev, aperture, newIso),
      iso: newIso,
    );
  }

  @override
  String toString() =>
      'EV ${ev.toStringAsFixed(1)}  f/${aperture.toStringAsFixed(1)}  ${_fmtShutter(shutterSpeed)}s  ISO ${iso.round()}';

  String _fmtShutter(double s) {
    if (s >= 1) return s.toStringAsFixed(1);
    return '1/${(1 / s).round()}';
  }
}

/// Scene EV (luminance) from exposure parameters.
///
/// sceneEV = log2(N² / t) - log2(ISO / 100)
/// Higher ISO → same N,t is for a darker scene → lower EV.
double evFromParams(double aperture, double shutter, double iso) {
  return log(aperture * aperture / shutter) / ln2 - log(iso / 100.0) / ln2;
}

/// Aperture needed to expose correctly at [ev] scene luminance.
///
/// N² / t = 2^ev · ISO / 100
/// N² = 2^ev · ISO · t / 100
/// Higher ISO → narrower aperture (higher f-number).
double apertureFromEv(double ev, double shutter, double iso) {
  return sqrt(pow(2.0, ev) * iso * shutter / 100);
}

/// Shutter time needed to expose correctly at [ev] scene luminance.
///
/// t = N² · 100 / (ISO · 2^ev)
/// Higher ISO → faster shutter (shorter t).
double shutterFromEv(double ev, double aperture, double iso) {
  return aperture * aperture * 100 / (iso * pow(2.0, ev));
}
