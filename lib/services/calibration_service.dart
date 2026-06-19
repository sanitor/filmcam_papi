import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calibration_profile.dart';

class CalibrationService {
  static const _keyProfile = 'calibration_profile';

  Future<CalibrationProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyProfile);
    if (raw == null || raw.isEmpty) return CalibrationProfile.defaultProfile;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CalibrationProfile.fromJson(map);
    } catch (_) {
      return CalibrationProfile.defaultProfile;
    }
  }

  Future<void> save(CalibrationProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
  }
}
