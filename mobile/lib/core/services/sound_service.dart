import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Short reward sounds. Never throws: a missing audio device must not break
/// completing a task.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const _prefKey = 'sounds_enabled';

  bool enabled = true;

  AudioPlayer? _task;
  AudioPlayer? _day;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  /// A quick "ding" for a completed task.
  Future<void> playTask() => _play(isDay: false);

  /// A rising arpeggio for a perfect day.
  Future<void> playDay() => _play(isDay: true);

  Future<void> _play({required bool isDay}) async {
    if (!enabled) return;
    try {
      final player = isDay ? (_day ??= AudioPlayer()) : (_task ??= AudioPlayer());
      await player.stop();
      await player.play(
        AssetSource(isDay ? 'sounds/day_complete.wav' : 'sounds/task_done.wav'),
        volume: 0.8,
      );
    } catch (_) {}
  }
}
