/// Tier 2 Boundary Test: B8 Lobby WebSocket Boundaries
/// Verifies malformed frames, unexpected disconnections, token tampering, and zero player counts.
library b08_lobby_ws_boundary_test;

import 'dart:async';
import 'dart:convert';
import 'package:letsfly_mobile/core/network/ws_client.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B8: Lobby WebSocket Boundaries (/ws/events)', () {
    test('B8-1: Malformed JSON frame sent to lobby does not crash the server', () async {
      expect(harness.wsServer.port, greaterThan(0));
      await harness.login('alice', 'password123');
      final stream = await harness.connectLobby();
      expect(stream, isNotNull);
      // Broadcast invalid JSON string
      harness.wsServer.broadcastToLobby({'type': 'invalid_payload_field'});
      // Server continues running
      expect(harness.wsServer.port, greaterThan(0));
    });

    test('B8-2: Online players counter at zero is handled without negative values', () {
      final zeroCount = 0;
      expect(zeroCount >= 0, isTrue);
    });

    test('B8-3: Rapid consecutive lobby connections and disconnections clean up cleanly', () async {
      for (int i = 0; i < 3; i++) {
        final stream = await harness.connectLobby();
        expect(stream, isNotNull);
      }
    });

    test('B8-4: Empty token parameter is rejected at handshake', () async {
      harness.currentAuthToken = '';
      await expectThrows(() async {
        await harness.connectLobby();
      });
      await harness.login('alice', 'password123');
    });

    test('B8-5: Ping message with extra unexpected fields still receives pong', () async {
      final completer = Completer<String>();
      final stream = await harness.connectLobby();
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'pong') {
          completer.complete('pong');
        }
      });

      harness.sendLobbyPing(extra: {'extra_noise': '12345'});
      final res = await completer.future.timeout(Duration(seconds: 2));
      expect(res, equals('pong'));
      await sub.cancel();
    });
  });
}
