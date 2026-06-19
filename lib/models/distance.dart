class DistanceReading {
  final double meters;
  final double confidence;
  final DistanceSource source;

  const DistanceReading({
    required this.meters,
    required this.confidence,
    required this.source,
  });

  String get display => meters < 1.0
      ? '${(meters * 100).round()} cm'
      : '${meters.toStringAsFixed(2)} m';

  static const none = DistanceReading(
    meters: 0,
    confidence: 0,
    source: DistanceSource.none,
  );
}

enum DistanceSource { none, focusLens, arDepth, manual }
