import 'dart:math';

const kMeterCalibrationConstant = 12.5;

const kStandardISO = 100.0;

const kApertureStops = [
  1.0,
  1.1,
  1.2,
  1.4,
  1.6,
  1.8,
  2.0,
  2.2,
  2.5,
  2.8,
  3.2,
  3.5,
  4.0,
  4.5,
  5.0,
  5.6,
  6.3,
  7.1,
  8.0,
  9.0,
  10.0,
  11.0,
  13.0,
  14.0,
  16.0,
  18.0,
  20.0,
  22.0,
  25.0,
  32.0,
];

const kShutterSpeeds = [
  1.0 / 8000,
  1.0 / 4000,
  1.0 / 2000,
  1.0 / 1000,
  1.0 / 500,
  1.0 / 250,
  1.0 / 125,
  1.0 / 60,
  1.0 / 30,
  1.0 / 15,
  1.0 / 8,
  1.0 / 4,
  1.0 / 2,
  1.0,
  2.0,
  4.0,
  8.0,
  15.0,
  30.0,
];

const kISOVALUES = [25, 50, 100, 200, 400, 800, 1600, 3200, 6400, 12800, 25600];

const kFilmFormats = {
  '135 (35mm)': {'width': 36.0, 'height': 24.0, 'name': '135'},
  '120 (6×4.5)': {'width': 56.0, 'height': 41.5, 'name': '645'},
  '120 (6×6)': {'width': 56.0, 'height': 56.0, 'name': '66'},
  '120 (6×7)': {'width': 56.0, 'height': 67.0, 'name': '67'},
  '120 (6×9)': {'width': 56.0, 'height': 84.0, 'name': '69'},
  '4×5" LF': {'width': 101.6, 'height': 127.0, 'name': '45'},
};

double evFromParams(double aperture, double shutterSpeed, double iso) {
  return log(aperture * aperture / shutterSpeed) / ln2 +
      log(iso / kStandardISO) / ln2;
}

double apertureFromEv(double ev, double shutterSpeed, double iso) {
  final effectiveEv = ev - log(iso / kStandardISO) / ln2;
  return sqrt(pow(2.0, effectiveEv) * shutterSpeed);
}

double shutterFromEv(double ev, double aperture, double iso) {
  final effectiveEv = ev - log(iso / kStandardISO) / ln2;
  return aperture * aperture / pow(2.0, effectiveEv);
}

double clampDouble(double value, double min, double max) {
  return value < min ? min : (value > max ? max : value);
}
