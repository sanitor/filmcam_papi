import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:exif/exif.dart';
import 'package:path_provider/path_provider.dart';

class CameraMetadata {
  final double aperture;
  final int exposureTime;
  final int iso;
  final double focusDistance;
  final bool isRunning;
  final String sessionType;

  const CameraMetadata({
    required this.aperture,
    required this.exposureTime,
    required this.iso,
    required this.focusDistance,
    required this.isRunning,
    required this.sessionType,
  });

  bool get valid => aperture > 0 && exposureTime > 0 && iso > 0;
  bool get hasFocusDistance => focusDistance > 0;

  static const empty = CameraMetadata(
    aperture: -1,
    exposureTime: -1,
    iso: -1,
    focusDistance: -1,
    isRunning: false,
    sessionType: 'none',
  );

  factory CameraMetadata.fromMap(Map map) => CameraMetadata(
    aperture: (map['aperture'] as num?)?.toDouble() ?? -1,
    exposureTime: (map['exposureTime'] as num?)?.toInt() ?? -1,
    iso: (map['iso'] as num?)?.toInt() ?? -1,
    focusDistance: (map['focusDistance'] as num?)?.toDouble() ?? -1,
    isRunning: (map['isRunning'] as bool?) ?? false,
    sessionType: (map['sessionType'] as String?) ?? 'none',
  );
}

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _streaming = false;
  bool _metadataInitialized = false;

  final _imageController = StreamController<CameraImage>.broadcast();
  final _metadataChannel = const MethodChannel('com.filmcam/camera_metadata');

  Stream<CameraImage> get imageStream => _imageController.stream;
  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  String? _backCameraId;
  String? get backCameraId => _backCameraId;

  Future<void> initialize({
    CameraLensDirection lens = CameraLensDirection.back,
  }) async {
    _cameras = await availableCameras();
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == lens,
      orElse: () => _cameras.first,
    );
    _backCameraId = camera.name;

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
  }

  Future<void> startImageStream() async {
    if (_streaming) return;
    _streaming = true;
    await _controller?.startImageStream(_onImage);
  }

  Future<void> stopImageStream() async {
    if (!_streaming) return;
    _streaming = false;
    await _controller?.stopImageStream();
  }

  void _onImage(CameraImage image) {
    if (!_imageController.isClosed) {
      _imageController.add(image);
    }
  }

  Future<CameraMetadata> getCameraMetadata(String cameraId) async {
    try {
      final result = await _metadataChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getLatest',
      );
      if (result == null) return CameraMetadata.empty;
      return CameraMetadata.fromMap(Map<String, dynamic>.from(result));
    } on MissingPluginException {
      return CameraMetadata.empty;
    }
  }

  Future<double> getStaticAperture(String cameraId) async {
    try {
      final result = await _metadataChannel.invokeMethod<double>(
        'getStaticAperture',
        {'cameraId': cameraId},
      );
      return result ?? -1.0;
    } on MissingPluginException {
      return -1.0;
    }
  }

  Future<bool> initMetadataReader(String cameraId) async {
    if (_metadataInitialized) return true;
    try {
      final result = await _metadataChannel.invokeMethod<bool>('start', {
        'cameraId': cameraId,
      });
      _metadataInitialized = result ?? false;
      return _metadataInitialized;
    } on MissingPluginException {
      return false;
    }
  }

  /// Release CameraX, measure distance via Camera2 AF + LENS_FOCUS_DISTANCE, reinit CameraX.
  Future<double> measureDistance(String cameraId) async {
    await releaseCamera();
    double fd = -1;
    try {
      final result = await _metadataChannel.invokeMethod<double>(
        'measureDistance',
        {'cameraId': cameraId},
      );
      fd = result ?? -1;
    } on MissingPluginException {}
    await reinitCamera();
    _metadataInitialized = false;
    return fd;
  }

  Future<void> lockExposure() async {
    await _controller?.setExposureMode(ExposureMode.locked);
  }

  Future<void> unlockExposure() async {
    await _controller?.setExposureMode(ExposureMode.auto);
  }

  Future<void> setExposurePoint(double x, double y) async {
    await _controller?.setExposurePoint(Offset(x, y));
  }

  Future<void> setFocusPoint(double x, double y) async {
    await _controller?.setFocusPoint(Offset(x, y));
  }

  Future<void> resetExposurePoint() async {
    await _controller?.setExposurePoint(null);
  }

  Future<void> setExposureOffset(double ev) async {
    await _controller?.setExposureOffset(ev);
  }

  Future<void> setFocusMode(FocusMode mode) async {
    await _controller?.setFocusMode(mode);
  }

  /// Release camera hardware: stop stream, dispose controller, close metadata reader.
  /// Does NOT close [_imageController] so the stream can be restarted later.
  Future<void> releaseCamera() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
    _streaming = false;
    try {
      await _metadataChannel.invokeMethod<void>('dispose');
    } catch (_) {}
    _metadataInitialized = false;
  }

  /// Reinitialize camera controller. Call [releaseCamera] first.
  Future<void> reinitCamera() async {
    _cameras = await availableCameras();
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    _backCameraId = camera.name;
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
  }

  Future<void> dispose() async {
    try {
      await _metadataChannel.invokeMethod<void>('dispose');
    } catch (_) {}
    await stopImageStream();
    await _controller?.dispose();
    await _imageController.close();
  }
}
