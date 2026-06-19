import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/calibration_service.dart';
import '../engines/meter_engine.dart';
import '../engines/range_engine.dart';
import '../engines/color_temp_engine.dart';
import '../engines/viewfinder_engine.dart';
import '../models/exposure.dart';
import '../models/distance.dart';
import '../models/color_temp.dart';
import '../models/calibration_profile.dart';

enum AppMode { meter, range, colorTemp, viewfinder }

/// A = aperture priority, S = shutter priority, M = manual
enum PriorityMode { a, s, m }

class CameraProvider extends ChangeNotifier {
  final CameraService _camera = CameraService();
  final CalibrationService _calibration = CalibrationService();
  final MeterEngine _meterEngine = MeterEngine();
  final RangeEngine _rangeEngine = RangeEngine();
  final ColorTempEngine _colorTempEngine = ColorTempEngine();
  final ViewfinderEngine _viewfinderEngine = ViewfinderEngine();

  AppMode _mode = AppMode.meter;
  AppMode get mode => _mode;

  ExposureReading? _exposure;
  ExposureReading? get exposure => _exposure;

  DistanceReading _distance = DistanceReading.none;
  DistanceReading get distance => _distance;

  ColorTempReading _colorTemp = ColorTempReading.none;
  ColorTempReading get colorTemp => _colorTemp;

  CalibrationProfile _profile = CalibrationProfile.defaultProfile;
  CalibrationProfile get profile => _profile;

  bool _initialized = false;
  bool get initialized => _initialized;

  bool _hasCamera = false;
  bool get hasCamera => _hasCamera;

  bool _isMeasuring = false;
  bool get isMeasuring => _isMeasuring;

  String? _error;
  String? get error => _error;

  StreamSubscription<CameraImage>? _imageSub;
  Timer? _focusTimer;
  Timer? _metadataTimer;
  Timer? _frameThrottle;

  CameraMetadata _nativeMetadata = CameraMetadata.empty;
  String _cameraId = '0';

  String get nativeSessionType => _nativeMetadata.sessionType;

  double _selectedAperture = 8.0;
  double get selectedAperture => _selectedAperture;
  set selectedAperture(double v) {
    _selectedAperture = v;
    notifyListeners();
  }

  double _selectedShutter = 1.0 / 125.0;
  double get selectedShutter => _selectedShutter;
  set selectedShutter(double v) {
    _selectedShutter = v;
    notifyListeners();
  }

  double _selectedIso = 400.0;
  double get selectedIso => _selectedIso;
  set selectedIso(double v) {
    _selectedIso = v;
    notifyListeners();
  }

  double _focalLength = 50.0;
  double get focalLength => _focalLength;
  set focalLength(double v) {
    _focalLength = v;
    notifyListeners();
  }

  String _filmFormat = '135 (35mm)';
  String get filmFormat => _filmFormat;
  set filmFormat(String v) {
    _filmFormat = v;
    _updateFormat(v);
    notifyListeners();
  }

  PriorityMode _priorityMode = PriorityMode.a;
  PriorityMode get priorityMode => _priorityMode;
  set priorityMode(PriorityMode v) {
    _priorityMode = v;
    notifyListeners();
  }

  double _evCompensation = 0.0;
  double get evCompensation => _evCompensation;
  set evCompensation(double v) {
    _evCompensation = v.clamp(-3.0, 3.0);
    notifyListeners();
  }

  List<double> get apertureStops => [
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
  ];

  List<double> get shutterSpeeds => [
    1 / 8000,
    1 / 4000,
    1 / 2000,
    1 / 1000,
    1 / 500,
    1 / 250,
    1 / 125,
    1 / 60,
    1 / 30,
    1 / 15,
    1 / 8,
    1 / 4,
    1 / 2,
    1,
    2,
    4,
    8,
    15,
    30,
  ];

  void adjustAperture(double delta) {
    final stops = apertureStops;
    var idx = stops.indexWhere((s) => s >= _selectedAperture);
    if (idx < 0) idx = stops.length ~/ 2;
    idx = (idx + delta.round()).clamp(0, stops.length - 1);
    selectedAperture = stops[idx];
  }

  void adjustShutter(double delta) {
    final speeds = shutterSpeeds;
    var idx = speeds.indexWhere((s) => s <= _selectedShutter);
    if (idx < 0) idx = speeds.length ~/ 2;
    idx = (idx + delta.round()).clamp(0, speeds.length - 1);
    selectedShutter = speeds[idx];
  }

  /// Measured EV from the meter engine (with calibration offset).
  double get _effectiveEv => (_exposure?.ev ?? 0) + _profile.evOffset;

  /// In A mode: shutter is computed from aperture + (meter EV + EC).
  double get computedShutter {
    if (_priorityMode != PriorityMode.a || _exposure == null)
      return _selectedShutter;
    return shutterFromEv(
      _effectiveEv - _evCompensation,
      _selectedAperture,
      _selectedIso,
    ).clamp(1 / 8000, 30);
  }

  /// In S mode: aperture is computed from shutter + (meter EV + EC).
  double get computedAperture {
    if (_priorityMode != PriorityMode.s || _exposure == null)
      return _selectedAperture;
    return apertureFromEv(
      _effectiveEv - _evCompensation,
      _selectedShutter,
      _selectedIso,
    ).clamp(1.0, 22.0);
  }

  /// In M mode: deviation between meter EV and current settings.
  double get exposureDeviation {
    if (_exposure == null) return 0.0;
    final setEv = evFromParams(
      _selectedAperture,
      _selectedShutter,
      _selectedIso,
    );
    return _effectiveEv - setEv;
  }

  MeterPattern _meterPattern = MeterPattern.average;
  MeterPattern get meterPattern => _meterPattern;
  set meterPattern(MeterPattern v) {
    _meterPattern = v;
    notifyListeners();
  }

  double _spotX = 0.5;
  double get spotX => _spotX;
  double _spotY = 0.5;
  double get spotY => _spotY;

  CameraController? get cameraController => _camera.controller;

  void setSpotPoint(double x, double y) {
    _spotX = x.clamp(0, 1);
    _spotY = y.clamp(0, 1);
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      _profile = await _calibration.load();
      _applyProfile();

      await _camera.initialize();
      _hasCamera = true;

      // Get camera ID from the first available camera
      try {
        final cameras = await availableCameras();
        final back = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        _cameraId = back.name;
      } catch (_) {}

      // Try to init native Camera2 metadata reader (may fail if CameraX has camera)
      final metaOk = await _camera.initMetadataReader(_cameraId);
      if (!metaOk) {
        // Fallback: get static aperture from characteristics
        final staticAp = await _camera.getStaticAperture(_cameraId);
        if (staticAp > 0) _meterEngine.setFallbackAperture(staticAp);
      }

      await _camera.setFocusMode(FocusMode.auto);
      await _camera.startImageStream();
      _imageSub = _camera.imageStream.listen(_onFrame);

      _startMetadataTimer();

      _initialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _initialized = true;
      notifyListeners();
    }
  }

  void _onFrame(CameraImage image) {
    if (_frameThrottle?.isActive ?? false) return;
    _frameThrottle = Timer(const Duration(milliseconds: 300), () {});

    switch (_mode) {
      case AppMode.meter:
        _processMeterFrame(image);
      case AppMode.colorTemp:
        _processColorTempFrame(image);
      case AppMode.range:
      case AppMode.viewfinder:
        break;
    }
  }

  void _processMeterFrame(CameraImage image) {
    final reading = _meterEngine.processFrameWithLuma(
      image,
      spotX: _spotX,
      spotY: _spotY,
      pattern: _meterPattern,
      nativeAperture: _nativeMetadata.aperture > 0
          ? _nativeMetadata.aperture
          : null,
      nativeExposureTime: _nativeMetadata.exposureTime > 0
          ? _nativeMetadata.exposureTime
          : null,
      nativeIso: _nativeMetadata.iso > 0
          ? _nativeMetadata.iso.toDouble()
          : null,
    );
    if (reading != null) {
      _exposure = reading;
      notifyListeners();
    }
  }

  void _processColorTempFrame(CameraImage image) {
    final reading = _colorTempEngine.processFrame(image);
    if (reading.cct > 0) {
      _colorTemp = reading;
      notifyListeners();
    }
  }

  void setMode(AppMode mode) {
    _mode = mode;
    notifyListeners();
  }

  void _applyProfile() {
    _meterEngine.setCalibrationOffset(_profile.evOffset);
    _rangeEngine.setCalibrationOffset(_profile.distOffset);
    _colorTempEngine.setCalibrationOffset(_profile.cctOffset);
  }

  Future<void> setEvOffset(double offset) async {
    _profile = _profile.copyWith(evOffset: offset);
    _applyProfile();
    await _calibration.save(_profile);
    notifyListeners();
  }

  Future<void> setCctOffset(double offset) async {
    _profile = _profile.copyWith(cctOffset: offset);
    _applyProfile();
    await _calibration.save(_profile);
    notifyListeners();
  }

  Future<void> setDistOffset(double offset) async {
    _profile = _profile.copyWith(distOffset: offset);
    _applyProfile();
    await _calibration.save(_profile);
    notifyListeners();
  }

  void _updateFormat(String formatKey) {
    final formats = <String, (double, double)>{
      '135 (35mm)': (36.0, 24.0),
      '120 (6x4.5)': (56.0, 41.5),
      '120 (6x6)': (56.0, 56.0),
      '120 (6x7)': (56.0, 67.0),
      '120 (6x9)': (56.0, 84.0),
      '4x5" LF': (101.6, 127.0),
    };
    final dims = formats[formatKey] ?? (36.0, 24.0);
    _viewfinderEngine.setFormat(dims.$1, dims.$2);
  }

  List<FrameLine> getFrameLines(double w, double h) {
    return _viewfinderEngine.computeFrameLines(
      focalLengthMm: _focalLength,
      viewportWidth: w,
      viewportHeight: h,
    );
  }

  List<FrameLine> getGridLines(double w, double h) {
    return _viewfinderEngine.computeGridLines(w, h);
  }

  Offset getParallaxOffset(double w, double h) {
    if (_distance.meters <= 0) return Offset.zero;
    return _viewfinderEngine.parallaxOffset(
      distanceMeters: _distance.meters,
      baselineMm: 69.25,
      focalLengthMm: _focalLength,
      sensorWidthMm: 36.0,
    );
  }

  double dofNear(double distance) {
    return _viewfinderEngine.depthOfFieldNear(
      distance,
      _focalLength,
      _selectedAperture,
    );
  }

  double dofFar(double distance) {
    return _viewfinderEngine.depthOfFieldFar(
      distance,
      _focalLength,
      _selectedAperture,
    );
  }

  Future<void> refreshDistance() async {
    final meta = await _camera.getCameraMetadata(_cameraId);
    if (meta.hasFocusDistance && meta.sessionType != 'static_fallback') {
      _distance = _rangeEngine.fromFocusDistance(meta.focusDistance);
      notifyListeners();
    }
  }

  /// Tap to measure: trigger CameraX AF → briefly switch to Camera2 → wait for AF lock → read distance.
  Future<void> measureDistance() async {
    if (_isMeasuring) return;
    _isMeasuring = true;
    notifyListeners();

    try {
      _metadataTimer?.cancel();

      // Let CameraX do its AF first so the lens is moving in the right direction
      await _camera.setFocusMode(FocusMode.auto);
      await _camera.setFocusPoint(0.5, 0.5);
      await Future.delayed(const Duration(milliseconds: 400));

      // Release CameraX, open Camera2 with AF until lock, read LENS_FOCUS_DISTANCE, reinit CameraX
      final fd = await _camera.measureDistance(_cameraId);
      if (fd > 0) {
        _distance = _rangeEngine.fromFocusDistance(fd);
        notifyListeners();
      }
    } finally {
      // Restart CameraX
      try {
        _cameraId = _camera.backCameraId ?? _cameraId;
        await _camera.startImageStream();
        _imageSub = _camera.imageStream.listen(_onFrame);
        final metaOk = await _camera.initMetadataReader(_cameraId);
        if (!metaOk) {
          final staticAp = await _camera.getStaticAperture(_cameraId);
          if (staticAp > 0) _meterEngine.setFallbackAperture(staticAp);
        }
        await _camera.setFocusMode(FocusMode.auto);
        _startMetadataTimer();
      } catch (e) {
        _error = e.toString();
      }

      _isMeasuring = false;
      notifyListeners();
    }
  }

  void _startMetadataTimer() {
    _metadataTimer?.cancel();
    _metadataTimer = Timer.periodic(const Duration(milliseconds: 200), (
      _,
    ) async {
      final meta = await _camera.getCameraMetadata(_cameraId);
      _nativeMetadata = meta;
    });
  }

  @override
  void dispose() {
    _imageSub?.cancel();
    _focusTimer?.cancel();
    _metadataTimer?.cancel();
    _frameThrottle?.cancel();
    _camera.dispose();
    super.dispose();
  }
}
