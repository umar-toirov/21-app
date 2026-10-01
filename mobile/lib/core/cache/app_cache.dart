import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the last profile and programs the server sent, so the app can
/// open instantly and refresh in the background. Without this, every launch
/// waits on the API, which can take ~1 minute while a free host wakes up.
class AppCache {
  static SharedPreferences? _prefs;

  static const _profileKey = 'cache_profile';
  static const _programsKey = 'cache_programs';
  static const _programsDayKey = 'cache_programs_day';
  static const _onboardedKey = 'cache_onboarded';

  /// Today's date in the app's day (UTC+5, Asia/Tashkent, no DST) — matches
  /// the backend's `app_today()`. Used to tell a cached snapshot of
  /// yesterday's tasks apart from today's, so a stale cache is never shown
  /// as if it were today's (e.g. "all done") before the real fetch lands.
  static String todayTag() {
    final t = DateTime.now().toUtc().add(const Duration(hours: 5));
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

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

  /// False once the cached snapshot was saved on an earlier day: its
  /// "done today" state is then not trustworthy and must be neutralized
  /// before use (see `activeProgramsProvider`).
  static bool get programsAreForToday => _prefs?.getString(_programsDayKey) == todayTag();

  static void savePrograms(Map<String, dynamic> json) {
    // One-off notices (e.g. "you lost points") must not replay from the cache.
    final copy = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
    for (final key in const ['personal', 'group']) {
      final program = copy[key];
      if (program is Map<String, dynamic>) program['penalty_points'] = 0;
    }
    _write(_programsKey, copy);
    try {
      _prefs?.setString(_programsDayKey, todayTag());
    } catch (_) {}
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
