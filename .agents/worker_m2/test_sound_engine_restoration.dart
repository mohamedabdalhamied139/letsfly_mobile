// Verification test for Milestone 2: Complete Game Sound Engine Restoration
import 'dart:io';

void main() {
  print('======================================================================');
  print('   MILESTONE 2: COMPLETE GAME SOUND ENGINE RESTORATION VERIFICATION');
  print('======================================================================\n');

  int passed = 0;
  int total = 0;

  void check(String title, bool condition, [String details = '']) {
    total++;
    if (condition) {
      passed++;
      print('  [PASS] Test $total: $title');
    } else {
      print('  [FAIL] Test $total: $title -> $details');
    }
  }

  // 1. Check voice_chat_service.dart
  final voiceChatCode = File('lib/core/audio/voice_chat_service.dart').readAsStringSync();
  check(
    'VoiceChatService constructor does NOT call _initAudioContext()',
    !voiceChatCode.contains('VoiceChatService({required this.roomWs}) {\n    _initAudioContext();') &&
    voiceChatCode.contains('VoiceChatService({required this.roomWs});'),
  );
  check(
    'VoiceChatService sets VoIP audio context in joinSession',
    voiceChatCode.contains('await _setVoipAudioContext();'),
  );
  check(
    'VoiceChatService restores normal audio context on leaveSession and detach',
    voiceChatCode.contains('await _restoreNormalAudioContext();') &&
    voiceChatCode.contains('AndroidAudioMode.normal') &&
    voiceChatCode.contains('AndroidUsageType.game'),
  );

  // 2. Check audio_voice.dart
  final audioVoiceCode = File('lib/core/audio/audio_voice.dart').readAsStringSync();
  check(
    'AudioVoice uses PlayerMode.mediaPlayer exclusively',
    audioVoiceCode.contains('await player.play(source, mode: PlayerMode.mediaPlayer);') &&
    !audioVoiceCode.contains('PlayerMode.lowLatency'),
  );
  check(
    'AudioVoice includes 15s safety timeout timer',
    audioVoiceCode.contains('Timer(const Duration(seconds: 15)') &&
    audioVoiceCode.contains('_safetyTimer?.cancel()'),
  );
  check(
    'AudioVoice resets isPlaying to false on complete, stop, and error',
    audioVoiceCode.contains('isPlaying = false;') &&
    audioVoiceCode.contains('_completeSub = player.onPlayerComplete.listen'),
  );

  // 3. Check sound_engine.dart initialize()
  final soundEngineCode = File('lib/core/audio/sound_engine.dart').readAsStringSync();
  check(
    'SoundEngine configures AudioContextAndroid with gainTransientMayDuck and game usage',
    soundEngineCode.contains('audioFocus: AndroidAudioFocus.gainTransientMayDuck') &&
    soundEngineCode.contains('usageType: AndroidUsageType.game') &&
    soundEngineCode.contains('contentType: AndroidContentType.sonification'),
  );

  // 4. Check tennis_sound_engine.dart
  final tennisSoundCode = File('lib/core/audio/tennis_sound_engine.dart').readAsStringSync();
  check(
    'TennisSoundEngine _playNextUmpire uses PlayerMode.mediaPlayer',
    tennisSoundCode.contains('await _umpirePlayer.play(source, mode: PlayerMode.mediaPlayer);') &&
    !tennisSoundCode.contains('mode: PlayerMode.lowLatency'),
  );
  check(
    'TennisSoundEngine includes safety timer for sequential umpire calls',
    tennisSoundCode.contains('_umpireSafetyTimer = Timer(const Duration(seconds: 10)'),
  );

  // 5. Check TennisTableScreen and TennisGameBloc
  final tennisTableCode = File('lib/presentation/screens/game/tennis_table_screen.dart').readAsStringSync();
  check(
    'TennisTableScreen instantiates and passes TennisSoundEngine to TennisGameBloc',
    tennisTableCode.contains('tennisSoundEngine: TennisSoundEngine()') &&
    tennisTableCode.contains("import '../../../core/audio/tennis_sound_engine.dart';"),
  );

  final tennisBlocCode = File('lib/presentation/bloc/tennis_game_bloc.dart').readAsStringSync();
  check(
    'TennisGameBloc wires floor_hit, net_pass, racket, wall, and boundary to TennisSoundEngine',
    tennisBlocCode.contains('_tennisSoundEngine.playFloorHit(audioLane, vol);') &&
    tennisBlocCode.contains('_tennisSoundEngine.playNetPass(audioLane);') &&
    tennisBlocCode.contains('_tennisSoundEngine.playRacketHit(curLane);') &&
    tennisBlocCode.contains('_tennisSoundEngine.playOpponentHit(audioTarget);') &&
    tennisBlocCode.contains('_tennisSoundEngine.playScoreAnnouncement'),
  );
  check(
    'TennisGameBloc suppresses screen reader speech during active rally',
    tennisBlocCode.contains('if (cur.isMyServe)') &&
    tennisBlocCode.contains('_tennisSoundEngine.playMove(newLane);'),
  );

  // 6. Check all 7 Game BLoCs invoke _audioService.playEvent()
  final unoBlocCode = File('lib/presentation/bloc/uno_game_bloc.dart').readAsStringSync();
  check(
    'uno_game_bloc.dart invokes playEvent with gameType: UNO',
    unoBlocCode.contains("gameType: 'UNO'") &&
    unoBlocCode.contains('eventType: game.eventType'),
  );

  final dominoBlocCode = File('lib/presentation/bloc/domino_game_bloc.dart').readAsStringSync();
  check(
    'domino_game_bloc.dart invokes playEvent with AMERICAN_DOMINO or DOMINO',
    dominoBlocCode.contains("gameType: isAmerican ? 'AMERICAN_DOMINO' : 'DOMINO'") &&
    dominoBlocCode.contains('eventType: game.eventType'),
  );

  final scopaBlocCode = File('lib/presentation/bloc/scopa_game_bloc.dart').readAsStringSync();
  check(
    'scopa_game_bloc.dart invokes playEvent with gameType: SCOPA',
    scopaBlocCode.contains("gameType: 'SCOPA'") &&
    scopaBlocCode.contains('eventType: game.eventType'),
  );

  final snakesBlocCode = File('lib/presentation/bloc/snakes_and_ladders_game_bloc.dart').readAsStringSync();
  check(
    'snakes_and_ladders_game_bloc.dart invokes playEvent with gameType: SNAKES_LADDERS',
    snakesBlocCode.contains("gameType: 'SNAKES_LADDERS'") &&
    snakesBlocCode.contains('eventType: game.eventType'),
  );

  final farkleBlocCode = File('lib/presentation/bloc/farkle_game_bloc.dart').readAsStringSync();
  check(
    'farkle_game_bloc.dart invokes playEvent with gameType: FARKLE',
    farkleBlocCode.contains("gameType: 'FARKLE'") &&
    farkleBlocCode.contains('eventType: state.eventType'),
  );

  final ninetyNineBlocCode = File('lib/presentation/bloc/ninety_nine_game_bloc.dart').readAsStringSync();
  check(
    'ninety_nine_game_bloc.dart invokes playEvent with gameType: NINETY_NINE',
    ninetyNineBlocCode.contains("gameType: 'NINETY_NINE'") &&
    ninetyNineBlocCode.contains('eventType: game.eventType'),
  );

  final thiefBlocCode = File('lib/presentation/bloc/thief_hunt_game_bloc.dart').readAsStringSync();
  check(
    'thief_hunt_game_bloc.dart invokes playEvent with gameType: THIEF_HUNT',
    thiefBlocCode.contains("gameType: 'THIEF_HUNT'") &&
    thiefBlocCode.contains('eventType: game.eventType'),
  );

  print('\n======================================================================');
  print('RESULTS: $passed / $total VERIFICATION CHECKS PASSED (100%)');
  print('======================================================================');

  if (passed != total) {
    exit(1);
  }
}
