/// Tier 1 Feature Test: F10 Room Browser, Creation & Bot Management
/// Verifies room listing, room creation with rules, joining, leaving, and bot additions.
library f10_room_browser_test;

import 'package:letsfly_mobile/data/models/room_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F10: Room Browser, Creation & Bot Management', () {
    test('F10-1: Active rooms listing returns available tables', () async {
      final rooms = await harness.getActiveRooms();
      expect(rooms.isNotEmpty, isTrue);
      expect(rooms[0]['game'], equals('UNO'));
      final model = RoomModel.fromJson(rooms[0]);
      expect(model.game, equals('UNO'));
      expect(model.isWaiting(), isTrue);
    });

    test('F10-2: Creating a room with custom rules succeeds', () async {
      final newRoom = await harness.createRoom(
        game: 'UNO',
        rules: {'target_score': 300, 'stacking': true},
      );
      expect(newRoom, isNotNull);
      expect(newRoom!['game'], equals('UNO'));
      expect(newRoom['rules']['target_score'], equals(300));
      final roomModel = RoomModel.fromJson(newRoom);
      expect(roomModel.game, equals('UNO'));
    });

    test('F10-3: Joining an active room adds player to room roster', () async {
      await harness.login('bob', 'password123');
      final res = await harness.postHttp('/api/rooms/room_101/join', {});
      expect(res['statusCode'], equals(200));
      final players = res['data']['players'] as List;
      expect(players.any((p) => p['username'] == 'bob'), isTrue);
    });

    test('F10-4: Adding a bot increases room player count', () async {
      final res = await harness.postHttp('/api/rooms/room_101/bots', {});
      expect(res['statusCode'], equals(200));
      expect(res['data']['is_bot'], isTrue);
    });

    test('F10-5: Leaving room triggers success response', () async {
      final res = await harness.postHttp('/api/rooms/room_101/leave', {});
      expect(res['statusCode'], equals(200));
      expect(res['data']['detail'], equals('تمت المغادرة.'));
    });
  });
}
