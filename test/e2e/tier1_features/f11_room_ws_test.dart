/// Tier 1 Feature Test: F11 Room WebSocket Lifecycle
/// Verifies /ws/room/{id} connection, initial snapshot, player roster, and state sync.
library f11_room_ws_test;

import 'dart:async';
import 'dart:convert';
import 'package:letsfly_mobile/core/network/ws_client.dart';
import 'package:letsfly_mobile/data/models/room_model.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F11: Room WebSocket Lifecycle (/ws/room/{id})', () {
    test('F11-1: Connects to room WebSocket channel with active token', () async {
      await harness.login('alice', 'password123');
      final stream = await harness.connectRoom('room_101');
      expect(stream, isNotNull);
    });

    test('F11-2: Receives room_snapshot immediately upon room connection', () async {
      final completer = Completer<Map<String, dynamic>>();
      final stream = await harness.connectRoom('room_101');
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'room_snapshot') {
          completer.complete(data['room'] as Map<String, dynamic>);
        }
      });

      final room = await completer.future.timeout(Duration(seconds: 2));
      final roomModel = RoomModel.fromJson(room);
      expect(roomModel.roomId, equals('room_101'));
      expect(roomModel.game, equals('UNO'));
      await sub.cancel();
    });

    test('F11-3: Room snapshot includes active players roster', () async {
      final completer = Completer<List<dynamic>>();
      final stream = await harness.connectRoom('room_101');
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'room_snapshot') {
          completer.complete(data['room']['players'] as List<dynamic>);
        }
      });

      final players = await completer.future.timeout(Duration(seconds: 2));
      expect(players.length, greaterThanOrEqualTo(1));
      await sub.cancel();
    });

    test('F11-4: Broadcasted room event is received by connected clients', () async {
      final completer = Completer<String>();
      final stream = await harness.connectRoom('room_101');
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'custom_room_event') {
          completer.complete(data['msg'] as String);
        }
      });

      harness.wsServer.broadcastToRoom('room_101', {
        'type': 'custom_room_event',
        'msg': 'round_started',
      });

      final msg = await completer.future.timeout(Duration(seconds: 2));
      expect(msg, equals('round_started'));
      await sub.cancel();
    });

    test('F11-5: Unauthorized token is rejected on room connection', () async {
      harness.currentAuthToken = 'unauthorized_token';
      await expectThrows(() async {
        await harness.connectRoom('room_101');
      });
      // Restore valid token
      await harness.login('alice', 'password123');
    });
  });
}
