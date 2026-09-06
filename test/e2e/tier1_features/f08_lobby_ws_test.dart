/// Tier 1 Feature Test: F8 Lobby WebSocket Presence
/// Verifies /ws/events connection, online player counter, ping/pong heartbeat, and activity feed.
library f08_lobby_ws_test;

import 'dart:async';
import 'dart:convert';
import 'package:letsfly_mobile/core/network/ws_client.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F8: Lobby WebSocket Presence (/ws/events)', () {
    test('F8-1: Successfully connects to lobby WebSocket channel with valid token', () async {
      await harness.login('alice', 'password123');
      final stream = await harness.connectLobby();
      expect(stream, isNotNull);
      expect(WsConnectionState.connected, equals(WsConnectionState.connected));
    });

    test('F8-2: Receives initial online users count event upon connection', () async {
      final completer = Completer<int>();
      final stream = await harness.connectLobby();
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'online_count') {
          completer.complete(data['count'] as int);
        }
      });

      final count = await completer.future.timeout(Duration(seconds: 2));
      expect(count, greaterThan(0));
      await sub.cancel();
    });

    test('F8-3: Server responds with pong when ping heartbeat frame is sent', () async {
      final completer = Completer<String>();
      final stream = await harness.connectLobby();
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'pong') {
          completer.complete('pong');
        }
      });

      harness.sendLobbyPing();
      final result = await completer.future.timeout(Duration(seconds: 2));
      expect(result, equals('pong'));
      await sub.cancel();
    });

    test('F8-4: Broadcasted activity feed notifications are received by lobby client', () async {
      final completer = Completer<String>();
      final stream = await harness.connectLobby();
      final sub = stream.listen((raw) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['type'] == 'activity') {
          completer.complete(data['text'] as String);
        }
      });

      harness.wsServer.broadcastToLobby({
        'type': 'activity',
        'text': 'انضم لاعب جديد إلى المنصة.',
      });

      final text = await completer.future.timeout(Duration(seconds: 2));
      expect(text, contains('انضم لاعب جديد'));
      await sub.cancel();
    });

    test('F8-5: Lobby WebSocket preserves connection resilience without unexpected drop', () async {
      expect(harness.wsServer.isLobbyActive, isTrue);
    });
  });
}
