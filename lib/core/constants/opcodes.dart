/// OpCodes and protocol message types for Let's Fly WebSocket and Game APIs.
class OpCodes {
  OpCodes._();

  // WebSocket Message Types
  static const String ping = 'ping';
  static const String pong = 'pong';
  static const String roomSnapshot = 'room_snapshot';
  static const String activityEvent = 'activity_event';
  static const String chatMessage = 'chat_message';
  static const String chat = 'chat';
  static const String roomUpdate = 'room_update';
  static const String gameState = 'game_state';

  // Room Lifecycle Events
  static const String playerJoined = 'player_joined';
  static const String playerLeft = 'player_left';
  static const String playerKicked = 'player_kicked';
  static const String playerBanned = 'player_banned';
  static const String hostChanged = 'host_changed';
  static const String gameStarted = 'game_started';
  static const String gameStopped = 'game_stopped';

  // UNO Game Actions (Client -> Server)
  static const String playCard = 'play_card';
  static const String drawCard = 'draw_card';
  static const String passTurn = 'pass_turn';
  static const String callUno = 'call_uno';
  static const String catchUno = 'catch_uno';
  static const String challengeBluff = 'challenge_bluff';
  static const String slapBuzzer = 'slap_buzzer';
  static const String chooseColor = 'choose_color';

  // UNO Game Events (Server -> Client)
  static const String eventGameStarted = 'GAME_STARTED';
  static const String eventRoundStart = 'ROUND_START';
  static const String eventRoundStarted = 'ROUND_STARTED';
  static const String eventCardDrawn = 'CARD_DRAWN';
  static const String eventCardDrawnAndPassed = 'CARD_DRAWN_AND_PASSED';
  static const String eventDrawPenalty = 'DRAW_PENALTY';
  static const String eventCardPlayed = 'CARD_PLAYED';
  static const String eventSpecialCardPlayed = 'SPECIAL_CARD_PLAYED';
  static const String eventBuzzerStarted = 'BUZZER_STARTED';
  static const String eventBuzzerPenalty = 'BUZZER_PENALTY';
  static const String eventBluffCaught = 'BLUFF_CAUGHT';
  static const String eventBluffFalse = 'BLUFF_FALSE';
  static const String eventUnoCalled = 'UNO_CALLED';
  static const String eventUnoCaught = 'UNO_CAUGHT';
  static const String eventRoundEnd = 'ROUND_END';
  static const String eventRoundFinished = 'ROUND_FINISHED';
  static const String eventRoundWon = 'ROUND_WON';
  static const String eventMatchWon = 'MATCH_WON';
  static const String eventMatchFinished = 'MATCH_FINISHED';
  static const String eventGameStopped = 'GAME_STOPPED';
}
