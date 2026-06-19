class CalibrationProfile {
  final String deviceModel;
  final double evOffset;
  final double cctOffset;
  final double distOffset;

  const CalibrationProfile({
    required this.deviceModel,
    this.evOffset = 0.0,
    this.cctOffset = 0.0,
    this.distOffset = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'deviceModel': deviceModel,
    'evOffset': evOffset,
    'cctOffset': cctOffset,
    'distOffset': distOffset,
  };

  factory CalibrationProfile.fromJson(Map<String, dynamic> json) =>
      CalibrationProfile(
        deviceModel: json['deviceModel'] as String,
        evOffset: (json['evOffset'] as num).toDouble(),
        cctOffset: (json['cctOffset'] as num).toDouble(),
        distOffset: (json['distOffset'] as num).toDouble(),
      );

  CalibrationProfile copyWith({
    double? evOffset,
    double? cctOffset,
    double? distOffset,
  }) => CalibrationProfile(
    deviceModel: deviceModel,
    evOffset: evOffset ?? this.evOffset,
    cctOffset: cctOffset ?? this.cctOffset,
    distOffset: distOffset ?? this.distOffset,
  );

  static const defaultProfile = CalibrationProfile(deviceModel: 'default');
}
