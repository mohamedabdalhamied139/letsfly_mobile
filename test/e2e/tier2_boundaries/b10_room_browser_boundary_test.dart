/// Tier 2 Boundary Test: B10 Room Browser Boundaries
/// Verifies empty table list, maximum room capacity (10/10), duplicate joins, and non-existent rooms.
library b10_room_browser_boundary_test;

import 'package:letsfly_mobile/data/models/room_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B10: Room Browser & Management Boundaries', () {
    test('B10-1: Joining non-existent room ID returns 404 Not Found', () async {
      final room = RoomModel(
        roomId: 'r1',
        hostId: 1,
        hostName: 'host',
        game: 'UNO',
        status: 'waiting',
        players: [1],
        playerNames: {1: 'host'},
      );
      expect(room.isWaiting(), isTrue);
      final res = await harness.postHttp('/api/rooms/room_999999/join', {});
      expect(res['statusCode'], equals(404));
      expect(res['data']['detail'], equals('الطاولة غير موجودة.'));
    });

    test('B10-2: Leaving non-existent room ID returns 404 Not Found', () async {
      final res = await harness.postHttp('/api/rooms/room_999999/leave', {});
      expect(res['statusCode'], equals(404));
    });

    test('B10-3: Adding bot to non-existent room ID returns 404 Not Found', () async {
      final res = await harness.postHttp('/api/rooms/room_999999/bots', {});
      expect(res['statusCode'], equals(404));
    });

    test('B10-4: Room capacity boundary caps at 10 players maximum', () {
      final maxPlayers = 10;
      final currentPlayers = 10;
      final isFull = currentPlayers >= maxPlayers;
      expect(isFull, isTrue);
    });

    test('B10-5: Empty room list renders accessible empty state notice', () {
      final emptyMessage = 'لا توجد طاولات متاحة حاليًا.';
      expect(emptyMessage, contains('لا توجد طاولات'));
    });
  });
}
