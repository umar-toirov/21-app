import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last profile and programs the server sent, so the app can
/// open instantly and refresh in the background. Without this, every launch
/// waits on the API, which can take ~1 minute while a free host wakes up.
class AppCache {
  static SharedPreferences? _prefs;

  static const _profileKey = 'cache_profile';
  static const _programsKey = 'cache_programs';
  static const _onboardedKey = 'cache_onboarded';

  /// Call once from main() before runApp.
  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static Map<String, dynamic>? _read(String key) {
    try {
      final raw = _prefs?.getString(key);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static void _write(String key, Map<String, dynamic> value) {
    try {
      _prefs?.setString(key, jsonEncode(value));
    } catch (_) {}
  }

  /// Last known profile JSON, or null if it belongs to a different user.
  static Map<String, dynamic>? profileFor(String? userId) {
    final data = _read(_profileKey);
    if (data == null || userId == null || data['id'] != userId) return null;
    return data;
  }

  static void saveProfile(Map<String, dynamic> json) {
    _write(_profileKey, json);
    final step = json['onboarding_step'];
    _prefs?.setBool(_onboardedKey, step is int && step >= 6);
  }

  /// True once this device has seen a fully onboarded profile.
  static bool get onboarded => _prefs?.getBool(_onboardedKey) ?? false;

  static Map<String, dynamic>? get programs => _read(_programsKey);

  static void savePrograms(Map<String, dynamic> json) {
    // One-off notices (e.g. "you lost points") must not replay from the cache.
    final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    for (final key in const ['personal', 'group']) {
      final program = copy[key];
      if (program is Map<String, dynamic>) program['penalty_points'] = 0;
    }
    _write(_programsKey, copy);
  }

  // ---- one-time explanations ("How it works", groups intro) ----
  static bool flag(String name) => _prefs?.getBool('flag_$name') ?? false;

  static void setFlag(String name, [bool value = true]) {
    try {
      _prefs?.setBool('flag_$name', value);
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      await _prefs?.remove(_profileKey);
      await _prefs?.remove(_programsKey);
      await _prefs?.remove(_onboardedKey);
    } catch (_) {}
  }
}
