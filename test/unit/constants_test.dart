import 'package:flutter_test/flutter_test.dart';
import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import 'package:letsfly_mobile/core/constants/opcodes.dart';
import 'package:letsfly_mobile/core/constants/api_endpoints.dart';
import 'package:letsfly_mobile/core/constants/app_colors.dart';

void main() {
  group('SoundCues Constants', () {
    test('contains all canonical table lifecycle cues', () {
      expect(SoundCues.playerJoined, equals('PLAYER_JOINED'));
      expect(SoundCues.playerLeft, equals('PLAYER_LEFT'));
      expect(SoundCues.tableJoin, equals('TABLE_JOIN'));
      expect(SoundCues.tableLeave, equals('TABLE_LEAVE'));
      expect(SoundCues.turnStart, equals('TURN_START'));
      expect(SoundCues.roundStart, equals('ROUND_START'));
      expect(SoundCues.roundEnd, equals('ROUND_END'));
      expect(SoundCues.matchWin, equals('MATCH_WIN'));
      expect(SoundCues.matchLoss, equals('MATCH_LOSS'));
      expect(SoundCues.invalidAction, equals('INVALID_ACTION'));
      expect(SoundCues.gameStopped, equals('GAME_STOPPED'));
      expect(SoundCues.win, equals('WIN'));
    });

    test('contains all UNO game cues', () {
      expect(SoundCues.cardDraw, equals('CARD_DRAW'));
      expect(SoundCues.cardDrawTwo, equals('CARD_DRAW_TWO'));
      expect(SoundCues.cardWildColor, equals('CARD_WILD_COLOR'));
      expect(SoundCues.cardWildDrawFour, equals('CARD_WILD_DRAW_FOUR'));
      expect(SoundCues.cardSkip, equals('CARD_SKIP'));
      expect(SoundCues.cardReverse, equals('CARD_REVERSE'));
      expect(SoundCues.unoDeal, equals('UNO_DEAL'));
      expect(SoundCues.unoPlace, equals('UNO_PLACE'));
      expect(SoundCues.unoPlaceSpecial, equals('UNO_PLACE_SPECIAL'));
      expect(SoundCues.unoCalled, equals('UNO_CALLED'));
      expect(SoundCues.unoPenalty, equals('UNO_PENALTY'));
      expect(SoundCues.bluffChallenge, equals('BLUFF_CHALLENGE'));
      expect(SoundCues.wildColorPrompt, equals('WILD_COLOR_PROMPT'));
      expect(SoundCues.unoShuffle, equals('UNO_SHUFFLE'));
    });

    test('all set has complete unique count', () {
      expect(SoundCues.all.length, greaterThanOrEqualTo(24));
    });
  });

  group('OpCodes Constants', () {
    test('WebSocket protocol opcodes match server specification', () {
      expect(OpCodes.ping, equals('ping'));
      expect(OpCodes.pong, equals('pong'));
      expect(OpCodes.roomSnapshot, equals('room_snapshot'));
      expect(OpCodes.chatMessage, equals('chat_message'));
      expect(OpCodes.activityEvent, equals('activity_event'));
    });

    test('UNO actions and events match server specification', () {
      expect(OpCodes.playCard, equals('play_card'));
      expect(OpCodes.drawCard, equals('draw_card'));
      expect(OpCodes.callUno, equals('call_uno'));
      expect(OpCodes.catchUno, equals('catch_uno'));
      expect(OpCodes.challengeBluff, equals('challenge_bluff'));

      expect(OpCodes.eventGameStarted, equals('GAME_STARTED'));
      expect(OpCodes.eventCardPlayed, equals('CARD_PLAYED'));
      expect(OpCodes.eventCardDrawn, equals('CARD_DRAWN'));
      expect(OpCodes.eventDrawPenalty, equals('DRAW_PENALTY'));
      expect(OpCodes.eventUnoCalled, equals('UNO_CALLED'));
      expect(OpCodes.eventUnoCaught, equals('UNO_CAUGHT'));
    });
  });

  group('ApiEndpoints Constants', () {
    test('REST route paths format properly', () {
      expect(ApiEndpoints.login, equals('/api/auth/login'));
      expect(ApiEndpoints.register, equals('/api/auth/register'));
      expect(ApiEndpoints.me, equals('/api/auth/me'));
      expect(ApiEndpoints.rooms, equals('/api/rooms'));
      expect(ApiEndpoints.room('room_123'), equals('/api/rooms/room_123'));
      expect(ApiEndpoints.joinRoom('room_123'), equals('/api/rooms/room_123/join'));
      expect(ApiEndpoints.leaveRoom('room_123'), equals('/api/rooms/room_123/leave'));
    });

    test('WebSocket paths format properly', () {
      expect(ApiEndpoints.wsEvents, equals('/ws/events'));
      expect(ApiEndpoints.wsRoom('room_456'), equals('/ws/room/room_456'));
    });
  });

  group('AppColors Constants', () {
    test('high contrast colors are configured', () {
      expect(AppColors.primary, isNotNull);
      expect(AppColors.background, isNotNull);
      expect(AppColors.unoRed, isNotNull);
      expect(AppColors.unoYellow, isNotNull);
      expect(AppColors.unoGreen, isNotNull);
      expect(AppColors.unoBlue, isNotNull);
      expect(AppColors.unoWild, isNotNull);
    });
  });
}
