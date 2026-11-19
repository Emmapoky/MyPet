import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Small touches that make the app feel alive: a light buzz on taps and
/// short chimes when a clip starts, stops or a result is saved.
/// Everything here is best effort and silent if the phone does not support it.
class Feel {
  static AudioPlayer? _player;
  static bool sounds = true;

  static AudioPlayer get _p => _player ??= AudioPlayer()
    ..setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());

  static Future<void> _play(String file) async {
    if (!sounds) return;
    try {
      await _p.play(AssetSource('sounds/$file'), volume: 0.6);
    } catch (_) {}
  }

  static void _buzz(Future<void> Function() f) {
    f().catchError((_) {});
  }

  /// Tabs, chips, toggles.
  static void tap() => _buzz(HapticFeedback.selectionClick);

  /// Main buttons such as Log now or Save.
  static void press() => _buzz(HapticFeedback.lightImpact);

  static Future<void> recordStart() async {
    _buzz(HapticFeedback.mediumImpact);
    _play('record_start.wav'); // not awaited: the caller waits a moment, then starts
  }

  static Future<void> recordStop() async {
    _buzz(HapticFeedback.heavyImpact);
    await _play('record_stop.wav');
  }

  static Future<void> saved() async {
    _buzz(HapticFeedback.mediumImpact);
    await _play('saved.wav');
  }
}
