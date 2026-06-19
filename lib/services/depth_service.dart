import 'package:flutter/services.dart';

class DepthService {
  final _channel = const MethodChannel('com.filmcam/arcore_depth');

  Future<bool> get isSupported async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<double?> measureDepth() async {
    try {
      final result = await _channel.invokeMethod<double>('measure');
      return result;
    } on MissingPluginException {
      return null;
    }
  }
}
