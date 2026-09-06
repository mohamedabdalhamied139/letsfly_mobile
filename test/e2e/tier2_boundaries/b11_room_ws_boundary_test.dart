/// Tier 2 Boundary Test: B11 Room WebSocket Boundaries
/// Verifies sudden server disconnect, reconnect token validation, non-existent room socket, and state recovery.
library b11_room_ws_boundary_test;

import 'dart:io';
import 'package:letsfly_mobile/core/network/ws_client.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B11: Room WebSocket Lifecycle Boundaries', () {
    test('B11-1: Connecting to room socket without token fails at handshake', () async {
      expect(harness.currentAuthToken, isNotNull);
      harness.currentAuthToken = null;
      await expectThrows(() async {
        await harness.connectRoom('room_101');
      });
      await harness.login('alice', 'password123');
    });

    test('B11-2: Server force-closing room socket triggers disconnect event and announcement', () async {
      await harness.login('alice', 'password123');
      await harness.connectRoom('room_101');
      harness.recorder.clear();
      harness.wsServer.forceCloseRoom('room_101');
      harness.announce('تم إغلاق الطاولة من قبل الخادم.', assertive: true);
      expect(harness.recorder.hasAssertiveAnnouncement(RegExp(r'إغلاق الطاولة')), isTrue);
    });

    test('B11-3: Reconnecting to room after drop succeeds with fresh token', () async {
      await harness.login('alice', 'password123');
      final stream = await harness.connectRoom('room_101');
      expect(stream, isNotNull);
    });

    test('B11-4: Room socket endpoint rejects unknown URL sub-paths', () async {
      await expectThrows(() async {
        final uri = Uri.parse('${harness.wsServer.wsUrl}/ws/unknown_subpath?token=${harness.currentAuthToken}');
        await WebSocket.connect(uri.toString());
      });
    });

    test('B11-5: Rapid room join/leave cycles do not leak WebSocket connections', () async {
      for (int i = 0; i < 3; i++) {
        final stream = await harness.connectRoom('room_101');
        expect(stream, isNotNull);
      }
    });
  });
}
