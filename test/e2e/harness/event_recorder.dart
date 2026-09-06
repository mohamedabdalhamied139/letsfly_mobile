/// Event Recorder for Let's Fly E2E Testing
/// Captures audio cues, accessibility announcements, network frames, and UI state events.
library letsfly_event_recorder;

class SoundPlaybackEvent {
  final String cueName;
  final DateTime timestamp;
  final double volume;

  SoundPlaybackEvent(this.cueName, {this.volume = 1.0}) : timestamp = DateTime.now();
}

class AccessibilityAnnouncementEvent {
  final String message;
  final bool assertive;
  final DateTime timestamp;

  AccessibilityAnnouncementEvent(this.message, {this.assertive = false}) : timestamp = DateTime.now();
}

class NetworkFrameEvent {
  final String direction; // 'sent' or 'received'
  final String channel; // 'http', 'ws_lobby', 'ws_room'
  final dynamic payload;
  final DateTime timestamp;

  NetworkFrameEvent(this.direction, this.channel, this.payload) : timestamp = DateTime.now();
}

class EventRecorder {
  final List<SoundPlaybackEvent> audioEvents = [];
  final List<AccessibilityAnnouncementEvent> announcementEvents = [];
  final List<NetworkFrameEvent> networkEvents = [];
  final List<String> screenNavigationEvents = [];

  final List<String> gestureEvents = [];

  void recordAudio(String cueName, {double volume = 1.0}) {
    audioEvents.add(SoundPlaybackEvent(cueName, volume: volume));
  }

  void recordAnnouncement(String message, {bool assertive = false}) {
    announcementEvents.add(AccessibilityAnnouncementEvent(message, assertive: assertive));
  }

  void recordNetwork(String direction, String channel, dynamic payload) {
    networkEvents.add(NetworkFrameEvent(direction, channel, payload));
  }

  void recordNavigation(String route) {
    screenNavigationEvents.add(route);
  }

  void recordGesture(String gesture) {
    gestureEvents.add(gesture);
  }

  bool hasRecordedGesture(String gesture) {
    return gestureEvents.contains(gesture);
  }

  bool hasPlayedAudio(String cueName) {
    return audioEvents.any((e) => e.cueName == cueName);
  }

  int countAudioPlays(String cueName) {
    return audioEvents.where((e) => e.cueName == cueName).length;
  }

  bool hasAnnounced(Pattern messagePattern) {
    return announcementEvents.any((e) => messagePattern.allMatches(e.message).isNotEmpty);
  }

  bool hasAssertiveAnnouncement(Pattern messagePattern) {
    return announcementEvents.any((e) => e.assertive && messagePattern.allMatches(e.message).isNotEmpty);
  }

  void clear() {
    audioEvents.clear();
    announcementEvents.clear();
    networkEvents.clear();
    screenNavigationEvents.clear();
    gestureEvents.clear();
  }
}
