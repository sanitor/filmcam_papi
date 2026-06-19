class ColorTempReading {
  final double cct;
  final double duv;
  final double confidence;

  const ColorTempReading({
    required this.cct,
    required this.duv,
    required this.confidence,
  });

  String get display => '${cct.round()}K';

  String get category {
    if (cct < 3200) return 'Tungsten';
    if (cct < 4500) return 'Fluorescent';
    if (cct < 5500) return 'Daylight';
    if (cct < 6500) return 'Cloudy';
    return 'Shade';
  }

  static const none = ColorTempReading(cct: 0, duv: 0, confidence: 0);
}
