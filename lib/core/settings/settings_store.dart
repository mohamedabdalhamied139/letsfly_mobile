import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent mobile representation of the Windows settings_store schema.
class SettingsStore {
  static const _language = 'settings.general.language';
  static const _autoLogin = 'settings.general.auto_login';
  static const _keepCredentials = 'settings.general.keep_credentials';
  static const _voiceAutoJoin = 'settings.audio.voice_auto_join';
  static const _speaker = 'settings.audio.speaker';
  static const _muteAllSounds = 'settings.audio.mute_all';
  static const _master = 'settings.audio.master_volume';
  static const _effects = 'settings.audio.volumes.effects';
  static const _game = 'settings.audio.volumes.game';
  static const _speechMute = 'settings.speech.mute_all';
  static const _pmPolicy = 'settings.privacy.pm_policy';
  static const _invitePolicy = 'settings.privacy.invite_policy';
  static const _joinPolicy = 'settings.privacy.join_policy';
  static const _gamePrefsPrefix = 'settings.games.';

  final SharedPreferences prefs;
  SettingsStore(this.prefs);

  String get language => prefs.getString(_language) ?? 'system';
  bool get autoLogin => prefs.getBool(_autoLogin) ?? true;
  bool get keepCredentials => prefs.getBool(_keepCredentials) ?? true;
  bool get voiceAutoJoin => prefs.getBool(_voiceAutoJoin) ?? false;
  String get speaker => prefs.getString(_speaker) ?? 'default';
  bool get muteAllSounds => prefs.getBool(_muteAllSounds) ?? false;
  double get masterVolume => prefs.getDouble(_master) ?? 1.0;
  double get effectsVolume => prefs.getDouble(_effects) ?? 1.0;
  double get gameVolume => prefs.getDouble(_game) ?? 1.0;
  bool get speechMute => prefs.getBool(_speechMute) ?? false;
  String get pmPolicy => prefs.getString(_pmPolicy) ?? 'everyone';
  String get invitePolicy => prefs.getString(_invitePolicy) ?? 'everyone';
  String get joinPolicy => prefs.getString(_joinPolicy) ?? 'everyone';

  String speechMode(String category) => prefs.getString('settings.speech.modes.$category') ?? _defaultSpeechMode(category);
  String _defaultSpeechMode(String category) => switch (category) {
    'friends' => 'speech',
    'invitations' => 'speech_and_sound',
    'table_chat' => 'speech',
    'private_messages' => 'speech_and_sound',
    'game_events' => 'speech_and_sound',
    _ => 'speech_and_sound',
  };
  Future<void> setSpeechMode(String category, String value) => prefs.setString('settings.speech.modes.$category', value);

  Future<void> setLanguage(String value) => prefs.setString(_language, value);
  Future<void> setAutoLogin(bool value) => prefs.setBool(_autoLogin, value);
  Future<void> setKeepCredentials(bool value) => prefs.setBool(_keepCredentials, value);
  Future<void> setVoiceAutoJoin(bool value) => prefs.setBool(_voiceAutoJoin, value);
  Future<void> setSpeaker(String value) => prefs.setString(_speaker, value);
  Future<void> setMuteAllSounds(bool value) => prefs.setBool(_muteAllSounds, value);
  Future<void> setMasterVolume(double value) => prefs.setDouble(_master, value.clamp(0.0, 1.0));
  Future<void> setEffectsVolume(double value) => prefs.setDouble(_effects, value.clamp(0.0, 1.0));
  Future<void> setGameVolume(double value) => prefs.setDouble(_game, value.clamp(0.0, 1.0));
  Future<void> setSpeechMute(bool value) => prefs.setBool(_speechMute, value);
  Future<void> setPmPolicy(String value) => prefs.setString(_pmPolicy, value);
  Future<void> setInvitePolicy(String value) => prefs.setString(_invitePolicy, value);
  Future<void> setJoinPolicy(String value) => prefs.setString(_joinPolicy, value);

  Map<String, dynamic> gamePreferences(String game) {
    final raw = prefs.getString('$_gamePrefsPrefix${game.toUpperCase()}');
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } catch (_) { return const {}; }
  }

  Future<void> setGamePreferences(String game, int targetScore, Map<String, dynamic> rules) =>
      prefs.setString('$_gamePrefsPrefix${game.toUpperCase()}', jsonEncode({'target_score': targetScore, 'rules': rules}));
}
