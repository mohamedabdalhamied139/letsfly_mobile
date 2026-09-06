import 'package:flutter/foundation.dart';
import '../accessibility/accessibility_announcer.dart';
import '../audio/table_audio_service.dart';
import '../settings/settings_store.dart';

/// Exact Windows notification decision model for mobile.
class NotificationPolicy {
  final SettingsStore settings;
  final AccessibilityAnnouncer announcer;
  final TableAudioService audio;
  const NotificationPolicy({required this.settings, required this.announcer, required this.audio});

  Future<void> handle({required String category, String text = '', String cue = '', bool interrupt = false}) async {
    final mode = settings.speechMode(category);
    if (!settings.speechMute && (mode == 'speech' || mode == 'speech_and_sound') && text.trim().isNotEmpty) {
      announcer.announce(text, priority: interrupt ? AnnouncePriority.assertive : AnnouncePriority.polite);
    }
    if ((mode == 'sound_only' || mode == 'speech_and_sound') && cue.isNotEmpty && !settings.muteAllSounds) {
      try { await audio.playCue(cue); } catch (e) { debugPrint('[NotificationPolicy] sound failed: $e'); }
    }
  }
}
